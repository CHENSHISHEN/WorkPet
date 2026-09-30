import EventKit
import Foundation

@MainActor
final class CalendarAdapter: NotificationAdapter {
    let name = "Calendar"

    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    private var emitHandler: ((WorkNotification) -> Void)?
    private var hasEventAccess = false
    private var hasReminderAccess = false

    func start(emit: @escaping (WorkNotification) -> Void) {
        self.emitHandler = emit
        requestAccessAndFetch()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchTodayAgenda()
            }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func requestAccessAndFetch() {
        guard let emit = emitHandler else { return }

        if #available(macOS 14.0, *) {
            Task { @MainActor in
                do {
                    hasEventAccess = try await eventStore.requestFullAccessToEvents()
                    hasReminderAccess = try await eventStore.requestFullAccessToReminders()

                    if hasEventAccess || hasReminderAccess {
                        fetchTodayAgenda()
                    }

                    if !hasEventAccess {
                        emit(
                            WorkNotification(
                                source: .calendar,
                                title: "日历权限未授予",
                                body: "请在 系统设置 > 隐私与安全性 > 日历 中允许 WorkPet 访问。",
                                metadata: ["permissionStatus": "denied"]
                            )
                        )
                    }

                    if !hasReminderAccess {
                        emit(
                            WorkNotification(
                                source: .calendar,
                                title: "提醒事项权限未授予",
                                body: "请在 系统设置 > 隐私与安全性 > 提醒事项 中允许 WorkPet 访问。",
                                metadata: ["permissionStatus": "remindersDenied"]
                            )
                        )
                    }
                } catch {
                    emit(
                        WorkNotification(
                            source: .calendar,
                            title: "日历访问出错",
                            body: "无法访问日历: \(error.localizedDescription)",
                            metadata: ["permissionStatus": "error"]
                        )
                    )
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                Task { @MainActor in
                    guard let self, let emit = self.emitHandler else { return }
                    self.hasEventAccess = granted

                    self.eventStore.requestAccess(to: .reminder) { reminderGranted, reminderError in
                        Task { @MainActor in
                            self.hasReminderAccess = reminderGranted

                            if self.hasEventAccess || self.hasReminderAccess {
                                self.fetchTodayAgenda()
                            }

                            if let error {
                                emit(self.accessErrorNotification(title: "日历访问出错", error: error))
                            } else if !self.hasEventAccess {
                                emit(self.accessDeniedNotification(kind: "日历", metadata: "denied"))
                            }

                            if let reminderError {
                                emit(self.accessErrorNotification(title: "提醒事项访问出错", error: reminderError))
                            } else if !self.hasReminderAccess {
                                emit(self.accessDeniedNotification(kind: "提醒事项", metadata: "remindersDenied"))
                            }
                        }
                    }
                }
            }
        }
    }

    private func fetchTodayAgenda() {
        guard let emit = emitHandler else { return }

        let cal = Calendar.current
        let now = Date()
        guard let startOfToday = cal.startOfDay(for: now) as Date?,
              let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday) else {
            return
        }

        let events = hasEventAccess ? todayEvents(start: startOfToday, end: startOfTomorrow) : []
        fetchTodayReminders(start: startOfToday, end: startOfTomorrow) { [weak self] reminders in
            guard let self else { return }
            emit(self.agendaNotification(events: events, reminders: reminders, now: now))
        }
    }

    private func todayEvents(start: Date, end: Date) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }

    private func fetchTodayReminders(
        start: Date,
        end: Date,
        completion: @escaping ([EKReminder]) -> Void
    ) {
        guard hasReminderAccess else {
            completion([])
            return
        }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: start,
            ending: end,
            calendars: nil
        )

        eventStore.fetchReminders(matching: predicate) { reminders in
            Task { @MainActor in
                let sorted = (reminders ?? []).sorted { lhs, rhs in
                    self.reminderDate(lhs) ?? .distantFuture < self.reminderDate(rhs) ?? .distantFuture
                }
                completion(sorted)
            }
        }
    }

    private func agendaNotification(events: [EKEvent], reminders: [EKReminder], now: Date) -> WorkNotification {
        let total = events.count + reminders.count

        guard total > 0 else {
            return WorkNotification(
                source: .calendar,
                title: "今日安排：暂无事项",
                body: "今天没有日历事件和到期提醒，可以专注于手头的工作。",
                metadata: [
                    "eventCount": "0",
                    "reminderCount": "0",
                    "type": "dailySummary"
                ]
            )
        }

        let eventLines = events.prefix(6).map { formatEvent($0, now: now) }
        let reminderLines = reminders.prefix(max(0, 8 - eventLines.count)).map { formatReminder($0) }
        let shownCount = eventLines.count + reminderLines.count
        let more = total > shownCount ? ["还有 \(total - shownCount) 项未展示"] : []
        let body = (eventLines + reminderLines + more).joined(separator: "\n")

        return WorkNotification(
            source: .calendar,
            title: "今日安排：\(events.count) 个日程 · \(reminders.count) 个提醒",
            body: body,
            metadata: [
                "eventCount": "\(events.count)",
                "reminderCount": "\(reminders.count)",
                "type": "dailySummary"
            ]
        )
    }

    private func formatEvent(_ event: EKEvent, now: Date) -> String {
        let timeText: String
        if event.isAllDay {
            timeText = "全天"
        } else {
            timeText = "\(timeFormatter.string(from: event.startDate))-\(timeFormatter.string(from: event.endDate))"
        }

        let status = !event.isAllDay && event.startDate <= now && event.endDate >= now ? "进行中 " : ""
        let title = clean(event.title, fallback: "无标题日程")
        let calendar = event.calendar?.title ?? "未命名日历"
        let location = clean(event.location, fallback: "")
        let notes = clean(event.notes, fallback: "")

        var line = "\(status)\(timeText) \(title)\n  日历：\(calendar)"
        if !location.isEmpty {
            line += "｜地点：\(location)"
        }
        if !notes.isEmpty {
            line += "｜备注：\(String(notes.prefix(40)))"
        }
        return line
    }

    private func formatReminder(_ reminder: EKReminder) -> String {
        let date = reminderDate(reminder)
        let timeText = date.map { timeFormatter.string(from: $0) } ?? "今日"
        let title = clean(reminder.title, fallback: "无标题提醒")
        let calendar = reminder.calendar?.title ?? "未命名清单"
        let priority = priorityText(reminder.priority)
        let notes = clean(reminder.notes, fallback: "")

        var line = "\(timeText) 提醒：\(title)\n  清单：\(calendar)"
        if !priority.isEmpty {
            line += "｜优先级：\(priority)"
        }
        if !notes.isEmpty {
            line += "｜备注：\(String(notes.prefix(40)))"
        }
        return line
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private func reminderDate(_ reminder: EKReminder) -> Date? {
        guard let components = reminder.dueDateComponents else {
            return nil
        }
        return Calendar.current.date(from: components)
    }

    private func priorityText(_ priority: Int) -> String {
        switch priority {
        case 1...4:
            return "高"
        case 5:
            return "中"
        case 6...9:
            return "低"
        default:
            return ""
        }
    }

    private func clean(_ value: String?, fallback: String) -> String {
        let cleaned = value?
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            ?? ""
        return cleaned.isEmpty ? fallback : cleaned
    }

    private func accessDeniedNotification(kind: String, metadata: String) -> WorkNotification {
        WorkNotification(
            source: .calendar,
            title: "\(kind)权限未授予",
            body: "请在 系统设置 > 隐私与安全性 > \(kind) 中允许 WorkPet 访问。",
            metadata: ["permissionStatus": metadata]
        )
    }

    private func accessErrorNotification(title: String, error: Error) -> WorkNotification {
        WorkNotification(
            source: .calendar,
            title: title,
            body: "无法访问: \(error.localizedDescription)",
            metadata: ["permissionStatus": "error"]
        )
    }
}

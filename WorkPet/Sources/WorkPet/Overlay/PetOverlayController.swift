import AppKit

@MainActor
final class PetOverlayController: PetViewDelegate {
    private let window: NSWindow
    private let petView: PetView
    private var resetTimer: Timer?
    private var mousePassthroughTimer: Timer?
    private var isDNDEnabled = false

    /// 通知回调（给外部 Hub 用来判断是否投递）
    var onDNDChanged: ((Bool) -> Void)?

    init() {
        let frame = NSRect(origin: .zero, size: PetLayoutMetrics.windowSize)
        self.petView = PetView(frame: frame)
        self.window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        petView.delegate = self
        configureWindow()
    }

    func show() {
        positionNearBottomRight()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        startMousePassthroughTracking()
    }

    func handle(_ routed: RoutedNotification) {
        // 免打扰模式下静默普通通知
        if isDNDEnabled && routed.level == .normal {
            return
        }

        let state = PetState.from(routed)
        guard routed.level != .silent else {
            petView.update(state: state)
            refreshMousePassthrough()
            return
        }

        petView.update(state: state)
        refreshMousePassthrough()
        window.orderFrontRegardless()
        scheduleIdleReset(for: routed.level)
    }

    // MARK: - PetViewDelegate

    func petViewDidRequestCalendar() {
        // 由外部通过重新触发 CalendarAdapter 来处理
        NotificationCenter.default.post(name: .workPetRefreshCalendar, object: nil)
    }

    func petViewDidRequestToggleDND() {
        isDNDEnabled.toggle()
        onDNDChanged?(isDNDEnabled)

        if isDNDEnabled {
            petView.update(state: PetState(mood: .sleepy, action: .sleeping, message: "免打扰模式已开启"))
        } else {
            petView.update(state: PetState(mood: .happy, action: .waving, message: "免打扰模式已关闭"))
        }
        refreshMousePassthrough()
        resetToIdleAfter(3)
    }

    func petViewDidRequestNotificationDiagnostics() {
        let summary = NotificationDiagnostics.run()
        petView.update(
            state: PetState(
                mood: .focused,
                action: .waving,
                message: "通知诊断\n\(summary)"
            )
        )
        refreshMousePassthrough()
        resetToIdleAfter(12)
    }

    func petViewIsDNDEnabled() -> Bool {
        isDNDEnabled
    }

    func petViewDidRequestInteraction(_ interaction: PetInteraction) {
        // 预留给未来的统计/养成系统
    }

    // MARK: - Private

    private func configureWindow() {
        window.contentView = petView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        window.isMovableByWindowBackground = false
        window.title = "WorkPet"
        window.ignoresMouseEvents = true
    }

    private func positionNearBottomRight() {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            window.center()
            return
        }

        let margin: CGFloat = 16
        let origin = NSPoint(
            x: screenFrame.maxX - window.frame.width - margin,
            y: screenFrame.minY + margin
        )
        window.setFrameOrigin(origin)
    }

    private func scheduleIdleReset(for level: NotificationLevel) {
        resetTimer?.invalidate()
        let interval: TimeInterval = level == .strong ? 12 : 8
        resetTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.petView.update(state: .idle)
                self.refreshMousePassthrough()
            }
        }
    }

    private func resetToIdleAfter(_ seconds: Double) {
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.petView.update(state: .idle)
                self.refreshMousePassthrough()
            }
        }
    }

    private func startMousePassthroughTracking() {
        guard mousePassthroughTimer == nil else {
            refreshMousePassthrough()
            return
        }

        mousePassthroughTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMousePassthrough()
            }
        }
        refreshMousePassthrough()
    }

    private func refreshMousePassthrough() {
        let screenPoint = NSEvent.mouseLocation
        guard window.frame.contains(screenPoint) else {
            window.ignoresMouseEvents = true
            return
        }

        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let shouldAcceptMouse = petView.containsInteractivePoint(windowPoint)
        window.ignoresMouseEvents = !shouldAcceptMouse
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let workPetRefreshCalendar = Notification.Name("dev.workpet.refreshCalendar")
}

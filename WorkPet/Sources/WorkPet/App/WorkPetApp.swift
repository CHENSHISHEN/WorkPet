import AppKit

@MainActor
final class WorkPetApp: NSObject, NSApplicationDelegate {
    private var overlayController: PetOverlayController?
    private var notificationHub: NotificationHub?
    private var adapters: [NotificationAdapter] = []
    private var calendarObserver: NSObjectProtocol?

    nonisolated override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rules = SourceRulesLoader.load()
        let ruleEngine = SourceRuleEngine(configuration: rules)
        let hub = NotificationHub(ruleEngine: ruleEngine)
        let overlay = PetOverlayController()

        hub.subscribe { routed in
            overlay.handle(routed)
        }

        self.notificationHub = hub
        self.overlayController = overlay
        self.adapters = [
            PermissionDiagnosticsAdapter(),
            SystemNotificationAdapter(),
            MenuBarUnreadAdapter(),
            CalendarAdapter(),
            DataGripAdapter()
        ]

        configureMenu()
        overlay.show()
        startAdapters()

        // 监听日历刷新请求
        calendarObserver = NotificationCenter.default.addObserver(
            forName: .workPetRefreshCalendar,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCalendar()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = calendarObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func startAdapters() {
        guard let hub = notificationHub else { return }

        for adapter in adapters {
            adapter.start { notification in
                hub.ingest(notification)
            }
        }
    }

    private func refreshCalendar() {
        guard let hub = notificationHub else { return }
        // 重新触发 CalendarAdapter
        for adapter in adapters {
            if let calAdapter = adapter as? CalendarAdapter {
                calAdapter.start { notification in
                    hub.ingest(notification)
                }
            }
        }
    }

    private func configureMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(
            NSMenuItem(
                title: "Show WorkPet",
                action: #selector(showWorkPet),
                keyEquivalent: "s"
            )
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: "Quit WorkPet",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }

    @objc private func showWorkPet() {
        overlayController?.show()
    }
}

import Foundation

@MainActor
final class DataGripAdapter: NotificationAdapter {
    let name = "DataGrip"

    /// 监听目录：DataGrip 任务完成后写入此目录的 .done 文件会触发通知
    /// 默认路径: ~/Library/Application Support/WorkPet/datagrip-tasks/
    private let watchPath: String
    private var fileSource: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "dev.workpet.datagrip", qos: .utility)

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.watchPath = "\(home)/Library/Application Support/WorkPet/datagrip-tasks"
    }

    func start(emit: @escaping (WorkNotification) -> Void) {
        ensureWatchDirectory()
        startFileWatch(emit: emit)

        emit(
            WorkNotification(
                source: .datagrip,
                title: "DataGrip 监听已启动",
                body: "将任务输出文件放到 \(watchPath) 即可触发通知。写入格式: 任意 .txt 文件，第一行为标题。",
                metadata: ["adapter": "DataGrip", "watchPath": watchPath]
            )
        )
    }

    func stop() {
        fileSource?.cancel()
        fileSource = nil
    }

    // MARK: - Setup

    private func ensureWatchDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: watchPath) {
            try? fm.createDirectory(atPath: watchPath, withIntermediateDirectories: true)
        }
    }

    // MARK: - File Watch

    private func startFileWatch(emit: @escaping (WorkNotification) -> Void) {
        let fd = open(watchPath, O_EVTONLY)
        guard fd != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            // 延迟 0.5 秒，等文件写入完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.processPendingFiles(emit: emit)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        self.fileSource = source
        source.resume()
    }

    // MARK: - Process

    private func processPendingFiles(emit: @escaping (WorkNotification) -> Void) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: watchPath) else { return }

        let pending = files.filter { $0.hasSuffix(".txt") || $0.hasSuffix(".done") }

        for filename in pending {
            let filePath = (watchPath as NSString).appendingPathComponent(filename)
            defer {
                // 处理完后删除文件
                try? fm.removeItem(atPath: filePath)
            }

            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let title = lines.first ?? "DataGrip 任务完成"
            let body = lines.count > 1 ? lines.dropFirst().joined(separator: "\n") : "任务已执行完毕。"

            emit(
                WorkNotification(
                    source: .datagrip,
                    title: title,
                    body: String(body.prefix(300)),
                    metadata: [
                        "adapter": "DataGrip",
                        "filename": filename,
                        "type": "taskComplete"
                    ]
                )
            )
        }
    }
}

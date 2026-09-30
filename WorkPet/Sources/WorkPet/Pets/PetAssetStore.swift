import Foundation

final class PetAssetStore {
    static let shared = PetAssetStore()

    private(set) var packs: [PetAssetPack] = []

    private init() {
        reload()
    }

    func reload() {
        var loaded: [PetAssetPack] = []

        for root in packRoots() {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for entry in entries {
                guard isDirectory(entry), let pack = PetAssetPack(directoryURL: entry) else {
                    continue
                }
                loaded.append(pack)
            }
        }

        self.packs = loaded.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func pack(id: String) -> PetAssetPack? {
        packs.first { $0.id == id }
    }

    private func packRoots() -> [URL] {
        var roots: [URL] = []

        if let bundled = Bundle.module.url(forResource: "PetPacks", withExtension: nil) {
            roots.append(bundled)
        }

        roots.append(userPacksDirectory())
        return roots
    }

    private func userPacksDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let url = appSupport.appendingPathComponent("WorkPet/pets", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}


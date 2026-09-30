import AppKit
import Foundation

struct PetPackManifest: Codable {
    let id: String
    let name: String
    let version: String
    let author: String?
    let size: PetPackSize?
    let states: [String: PetPackState]
}

struct PetPackSize: Codable {
    let width: CGFloat
    let height: CGFloat
}

struct PetPackState: Codable {
    let image: String?
    let frames: [String]?
    let frameDuration: TimeInterval?
    let sequence: [PetPackSequenceItem]?
}

struct PetPackSequenceItem: Codable {
    let state: String
    let repeatCount: Int
    let clipDuration: TimeInterval?
    let transitionDuration: TimeInterval?
}

struct PetAssetFrame {
    let image: NSImage
    let duration: TimeInterval
    let transitionDuration: TimeInterval?

    init(image: NSImage, duration: TimeInterval, transitionDuration: TimeInterval? = nil) {
        self.image = image
        self.duration = duration
        self.transitionDuration = transitionDuration
    }
}

enum PetPlaybackTransition {
    static func duration(
        advancingFrom currentIndex: Int?,
        in frames: [PetAssetFrame]
    ) -> TimeInterval? {
        guard let currentIndex, !frames.isEmpty, frames.indices.contains(currentIndex) else {
            return nil
        }
        let nextIndex = (currentIndex + 1) % frames.count
        return frames[nextIndex].transitionDuration
    }
}

struct PetAssetPack: Identifiable {
    let id: String
    let name: String
    let manifest: PetPackManifest
    let directoryURL: URL

    var preferredSize: CGSize {
        if let size = manifest.size {
            return CGSize(width: size.width, height: size.height)
        }
        return CGSize(width: 148, height: 148)
    }

    init?(directoryURL: URL) {
        let manifestURL = directoryURL.appendingPathComponent("pet.json")

        guard
            let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(PetPackManifest.self, from: data)
        else {
            return nil
        }

        self.id = manifest.id
        self.name = manifest.name
        self.manifest = manifest
        self.directoryURL = directoryURL
    }

    func frames(for state: PetState) -> [PetAssetFrame] {
        let keys = stateKeys(for: state)

        for key in keys {
            guard let manifestState = manifest.states[key] else {
                continue
            }

            if let sequence = manifestState.sequence, !sequence.isEmpty {
                let frames = frames(for: sequence)
                if !frames.isEmpty {
                    return frames
                }
            }

            let frames = frames(for: manifestState)
            if !frames.isEmpty {
                return frames
            }
        }

        return []
    }

    private func frames(for sequence: [PetPackSequenceItem]) -> [PetAssetFrame] {
        var result: [PetAssetFrame] = []

        for item in sequence {
            guard item.repeatCount > 0 else {
                continue
            }
            if let clipDuration = item.clipDuration, clipDuration <= 0 {
                continue
            }
            guard let manifestState = manifest.states[item.state], manifestState.sequence == nil else {
                continue
            }

            var clipFrames = frames(for: manifestState)
            guard !clipFrames.isEmpty else {
                continue
            }

            if let clipDuration = item.clipDuration {
                let frameDuration = clipDuration / TimeInterval(clipFrames.count)
                clipFrames = clipFrames.map {
                    PetAssetFrame(image: $0.image, duration: frameDuration)
                }
            }

            let transitionDuration = item.transitionDuration.flatMap { $0 > 0 ? $0 : nil }
            for repetition in 0..<item.repeatCount {
                for (index, frame) in clipFrames.enumerated() {
                    let entersSequenceItem = repetition == 0 && index == 0
                    result.append(
                        PetAssetFrame(
                            image: frame.image,
                            duration: frame.duration,
                            transitionDuration: entersSequenceItem ? transitionDuration : nil
                        )
                    )
                }
            }
        }

        return result
    }

    private func frames(for state: PetPackState) -> [PetAssetFrame] {
        let duration = max(state.frameDuration ?? 0.18, 0.05)

        if let frameNames = state.frames, !frameNames.isEmpty {
            let frames = frameNames.compactMap { image(named: $0) }.map {
                PetAssetFrame(image: $0, duration: duration)
            }

            if !frames.isEmpty {
                return frames
            }
        }

        if let imageName = state.image, let image = image(named: imageName) {
            return [PetAssetFrame(image: image, duration: duration)]
        }

        return []
    }

    private func image(named name: String) -> NSImage? {
        let url = directoryURL.appendingPathComponent(name)
        return NSImage(contentsOf: url)
    }

    private func stateKeys(for state: PetState) -> [String] {
        [
            state.visualState.rawValue,
            state.action.rawValue,
            state.mood.rawValue,
            "idle",
            "default"
        ]
    }
}

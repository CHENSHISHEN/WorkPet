import AppKit
import Foundation
import Testing
@testable import WorkPet

@Test func sourceRuleEngineUsesConfiguredSourceLevel() {
    let engine = SourceRuleEngine(
        defaultLevel: .normal,
        sourceLevels: [
            NotificationSource.datagrip.bundleIdentifier: .strong
        ]
    )

    #expect(engine.level(for: .datagrip) == .strong)
    #expect(engine.level(for: .demo) == .normal)
}

@Test func petStateReflectsNotificationLevel() {
    let notification = WorkNotification(
        source: .calendar,
        title: "Standup",
        body: "Daily sync"
    )

    let strong = RoutedNotification(notification: notification, level: .strong)
    let normal = RoutedNotification(notification: notification, level: .normal)
    let silent = RoutedNotification(notification: notification, level: .silent)

    #expect(PetState.from(strong).action == .bouncing)
    #expect(PetState.from(normal).action == .waving)
    #expect(PetState.from(silent).action == .resting)
    #expect(PetState.from(silent).message == nil)
    #expect(PetState.from(strong).visualState == .standing)
}

@Test func petStateUsesSourceSpecificVisualState() {
    let cases: [(NotificationSource, PetVisualState)] = [
        (.datagrip, .datagrip),
        (.feishu, .feishu),
        (.wechat, .wechat),
        (.calendar, .standing),
        (.workpet, .standing),
        (.demo, .standing)
    ]

    for (source, expected) in cases {
        let notification = WorkNotification(source: source, title: "Test", body: "Body")
        let routed = RoutedNotification(notification: notification, level: .normal)
        #expect(PetState.from(routed).visualState == expected)
    }
}

@Test func petStateNormalizesWechatAndFeishuBundleIdentifiersForVisualState() {
    let cases: [(String, PetVisualState)] = [
        ("com.tencent.xinWeChat64", .wechat),
        ("com.tencent.flue.WeChatAppEx", .wechat),
        ("com.electron.lark", .feishu),
        ("com.electron.lark-notifier", .feishu)
    ]

    for (bundleIdentifier, expected) in cases {
        let source = NotificationSource(bundleIdentifier: bundleIdentifier, displayName: "Alias")
        let notification = WorkNotification(source: source, title: "Test", body: "Body")
        let routed = RoutedNotification(notification: notification, level: .strong)
        let state = PetState.from(routed)

        #expect(state.visualState == expected)
        #expect(state.action == .bouncing)
    }
}

@Test func directlyConstructedPetStateDefaultsToStandingVisual() {
    let state = PetState(mood: .happy, action: .wiggling, message: "Interaction")

    #expect(state.visualState == .standing)
    #expect(PetState.idle.visualState == .idle)
}

@Test func wangLinLayoutUsesApprovedLargerSizeWithoutChangingOtherPacks() {
    #expect(PetLayoutMetrics.windowSize == CGSize(width: 280, height: 282))
    #expect(PetLayoutMetrics.maximumVisualSize(packID: "wang-lin", hasMessage: false) == 160)
    #expect(PetLayoutMetrics.maximumVisualSize(packID: "wang-lin", hasMessage: true) == 160)
    #expect(PetLayoutMetrics.maximumVisualSize(packID: "orange-cat", hasMessage: false) == 118)
    #expect(PetLayoutMetrics.maximumVisualSize(packID: "orange-cat", hasMessage: true) == 104)
}

@Test func wangLinMessageLayoutKeepsApprovedSpacingAtEveryBubbleHeight() {
    let packID = "wang-lin"
    let petSize = PetLayoutMetrics.maximumVisualSize(packID: packID, hasMessage: true)
    let petBottom = PetLayoutMetrics.petBottomInset(packID: packID)
    let petTop = petBottom + petSize

    #expect(petBottom == 0)
    #expect(PetLayoutMetrics.messageBubbleMaximumHeight(packID: packID) == 108)
    #expect(PetLayoutMetrics.petBubbleSpacing(packID: packID) == 6)

    for bubbleHeight: CGFloat in [48, 108] {
        let bubbleBottom = PetLayoutMetrics.messageBubbleOriginY(
            packID: packID,
            bubbleHeight: bubbleHeight,
            boundsHeight: PetLayoutMetrics.windowSize.height
        )
        let availablePetHeight = PetLayoutMetrics.availablePetHeight(
            packID: packID,
            topLimit: bubbleBottom
        )

        #expect(bubbleBottom - petTop == 6)
        #expect(
            bubbleBottom + bubbleHeight
                <= PetLayoutMetrics.windowSize.height - PetLayoutMetrics.messageBubbleTopInset
        )
        #expect(availablePetHeight >= petSize)
    }
}

@Test func wangLinMessageTextFitsInsideMaximumBubbleHeight() {
    let packID = "wang-lin"
    let maximumContentHeight =
        PetLayoutMetrics.messageTitleMaximumHeight(packID: packID)
        + PetLayoutMetrics.messageBodySpacing
        + PetLayoutMetrics.messageBodyMaximumHeight(packID: packID)
        + PetLayoutMetrics.messageBubbleVerticalInset * 2

    #expect(maximumContentHeight <= PetLayoutMetrics.messageBubbleMaximumHeight(packID: packID))
}

@Test func orangeCatLayoutKeepsExistingBottomInsetAndTopAnchoredBubble() {
    let packID = "orange-cat"
    let petBottom = PetLayoutMetrics.petBottomInset(packID: packID)
    let petSize = PetLayoutMetrics.maximumVisualSize(packID: packID, hasMessage: true)
    let petTop = petBottom + petSize
    let cases: [(height: CGFloat, bottom: CGFloat, gap: CGFloat, availableHeight: CGFloat)] = [
        (48, 226, 106, 200),
        (112, 162, 42, 136)
    ]

    #expect(petBottom == 16)
    #expect(petTop == 120)
    #expect(PetLayoutMetrics.messageBubbleMaximumHeight(packID: packID) == 112)
    #expect(PetLayoutMetrics.petBubbleSpacing(packID: packID) == 10)

    for item in cases {
        let bubbleBottom = PetLayoutMetrics.messageBubbleOriginY(
            packID: packID,
            bubbleHeight: item.height,
            boundsHeight: PetLayoutMetrics.windowSize.height
        )

        #expect(bubbleBottom == item.bottom)
        #expect(bubbleBottom - petTop == item.gap)
        #expect(bubbleBottom - petTop >= PetLayoutMetrics.petBubbleSpacing(packID: packID))
        #expect(
            PetLayoutMetrics.availablePetHeight(packID: packID, topLimit: bubbleBottom)
                == item.availableHeight
        )
    }
}

@Test func wangLinPackLoadsAllVisualStatesFromBundledResources() throws {
    let packsRoot = try #require(Bundle.module.url(forResource: "PetPacks", withExtension: nil))
    let pack = try #require(PetAssetPack(directoryURL: packsRoot.appendingPathComponent("wang-lin")))
    let cases: [(PetVisualState, Int)] = [
        (.standing, 61),
        (.datagrip, 88),
        (.feishu, 76),
        (.wechat, 88)
    ]

    #expect(pack.id == "wang-lin")

    for (visualState, expectedCount) in cases {
        let state = PetState(
            mood: .idle,
            action: .resting,
            message: nil,
            visualState: visualState
        )
        #expect(pack.frames(for: state).count == expectedCount)
    }
}

@Test func wangLinIdleSequenceRotatesEachActionForOneMinute() throws {
    let packsRoot = try #require(Bundle.module.url(forResource: "PetPacks", withExtension: nil))
    let pack = try #require(PetAssetPack(directoryURL: packsRoot.appendingPathComponent("wang-lin")))
    let idleFrames = pack.frames(for: .idle)
    let standingDuration = 5.0 / 61.0
    let cuddleDuration = 5.0 / 76.0
    let lifeDeathBurstDuration = 5.0 / 121.0

    #expect(idleFrames.count == 3_096)
    #expect(abs(idleFrames.reduce(0) { $0 + $1.duration } - 180) < 0.000_001)
    #expect(idleFrames.prefix(732).allSatisfy { abs($0.duration - standingDuration) < 0.000_001 })
    #expect(idleFrames.dropFirst(732).prefix(912).allSatisfy { abs($0.duration - cuddleDuration) < 0.000_001 })
    #expect(idleFrames.dropFirst(1_644).allSatisfy { abs($0.duration - lifeDeathBurstDuration) < 0.000_001 })
    #expect(idleFrames.allSatisfy { $0.transitionDuration == nil })

    #expect(PetPlaybackTransition.duration(advancingFrom: nil, in: idleFrames) == nil)
    #expect(PetPlaybackTransition.duration(advancingFrom: 60, in: idleFrames) == nil)
    #expect(PetPlaybackTransition.duration(advancingFrom: 731, in: idleFrames) == nil)
    #expect(PetPlaybackTransition.duration(advancingFrom: 1_643, in: idleFrames) == nil)
    #expect(PetPlaybackTransition.duration(advancingFrom: 3_095, in: idleFrames) == nil)

    let standingFrames = pack.frames(
        for: PetState(mood: .idle, action: .resting, message: nil, visualState: .standing)
    )
    #expect(standingFrames.count == 61)
    #expect(standingFrames.allSatisfy { abs($0.duration - (1.0 / 15.0)) < 0.000_001 })
}

@Test func idleVisualStateKeepsOrangeCatIdleCompatible() throws {
    let packsRoot = try #require(Bundle.module.url(forResource: "PetPacks", withExtension: nil))
    let pack = try #require(PetAssetPack(directoryURL: packsRoot.appendingPathComponent("orange-cat")))

    #expect(pack.frames(for: .idle).count == 2)
}

@Test func petPackSequenceSkipsInvalidItemsAndKeepsValidClips() throws {
    let fixture = try temporaryPetPack(statesJSON: """
        {
          "idle": {
            "sequence": [
              { "state": "standing", "repeatCount": 2, "clipDuration": 1.0 },
              { "state": "standing", "repeatCount": 0, "clipDuration": 1.0 },
              { "state": "standing", "repeatCount": 2, "clipDuration": 0 },
              { "state": "missing", "repeatCount": 2, "clipDuration": 1.0 },
              { "state": "empty", "repeatCount": 2, "clipDuration": 1.0 }
            ]
          },
          "standing": { "frames": ["valid.webp"], "frameDuration": 0.2 },
          "empty": { "frames": ["missing.webp"], "frameDuration": 0.2 },
          "default": { "image": "valid.webp" }
        }
        """)
    defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

    let frames = fixture.pack.frames(for: .idle)
    #expect(frames.count == 2)
    #expect(frames.allSatisfy { abs($0.duration - 1) < 0.000_001 })
    #expect(frames.allSatisfy { $0.transitionDuration == nil })
}

@Test func petPackSequenceIgnoresNonPositiveTransitionDuration() throws {
    let fixture = try temporaryPetPack(statesJSON: """
        {
          "idle": {
            "sequence": [
              { "state": "standing", "repeatCount": 1, "clipDuration": 1.0, "transitionDuration": 0 },
              { "state": "standing", "repeatCount": 1, "clipDuration": 1.0, "transitionDuration": -0.8 }
            ]
          },
          "standing": { "frames": ["valid.webp"], "frameDuration": 0.2 },
          "default": { "image": "valid.webp" }
        }
        """)
    defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

    let frames = fixture.pack.frames(for: .idle)
    #expect(frames.count == 2)
    #expect(frames.allSatisfy { $0.transitionDuration == nil })
}

@Test func petCrossfadeStateUsesDeterministicProgressAndCanReset() {
    var crossfade = PetCrossfadeState()

    #expect(crossfade.progress(at: 10) == 1)
    crossfade.begin(duration: 0.8, at: 10)
    #expect(crossfade.isActive)
    #expect(crossfade.progress(at: 10) == 0)
    #expect(abs(crossfade.progress(at: 10.4) - 0.5) < 0.000_001)
    #expect(crossfade.progress(at: 10.8) == 1)

    crossfade.reset()
    #expect(!crossfade.isActive)
    #expect(crossfade.progress(at: 10.4) == 1)
}

@Test func petPackSequenceFallsBackWhenEveryItemIsInvalid() throws {
    let fixture = try temporaryPetPack(statesJSON: """
        {
          "idle": {
            "sequence": [
              { "state": "missing", "repeatCount": 2, "clipDuration": 1.0 },
              { "state": "empty", "repeatCount": 2, "clipDuration": 1.0 }
            ]
          },
          "empty": { "frames": ["missing.webp"], "frameDuration": 0.2 },
          "breathing": { "frames": ["valid.webp"], "frameDuration": 0.2 },
          "default": { "image": "valid.webp" }
        }
        """)
    defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

    let frames = fixture.pack.frames(for: .idle)
    #expect(frames.count == 1)
    #expect(abs(frames[0].duration - 0.2) < 0.000_001)
}

@MainActor
@Test func petViewStateUpdatesRestartPlaybackAtFirstFrame() async throws {
    let view = PetView(frame: NSRect(origin: .zero, size: PetLayoutMetrics.windowSize))
    try await Task.sleep(for: .milliseconds(200))
    #expect(view.currentFrameIndex > 0)

    let notificationState = PetState(
        mood: .excited,
        action: .bouncing,
        message: "DataGrip\nDone",
        visualState: .datagrip
    )
    view.beginCrossfade(from: NSImage(size: NSSize(width: 1, height: 1)), duration: 0.8, at: 10)
    #expect(view.isCrossfading)
    view.update(state: notificationState)
    #expect(view.currentFrameIndex == 0)
    #expect(!view.isCrossfading)

    try await Task.sleep(for: .milliseconds(150))
    #expect(view.currentFrameIndex > 0)
    view.update(state: .idle)
    #expect(view.currentFrameIndex == 0)
}

@Test func petStatePrefersMessageSenderInBubbleTitle() {
    let notification = WorkNotification(
        source: .wechat,
        title: "WeChat",
        body: "今晚同步一下",
        metadata: ["sender": "陈世深"]
    )

    let state = PetState.from(RoutedNotification(notification: notification, level: .normal))

    #expect(state.message == "陈世深\n今晚同步一下")
}

@Test func petStateDoesNotRepeatSenderWhenTitleMatches() {
    let notification = WorkNotification(
        source: .wechat,
        title: "陈世深",
        body: "收到",
        metadata: ["sender": "陈世深"]
    )

    let state = PetState.from(RoutedNotification(notification: notification, level: .strong))

    #expect(state.message == "WeChat: 陈世深\n收到")
}

@Test func petStateDoesNotTreatCalendarTimeAsSender() {
    let notification = WorkNotification(
        source: .calendar,
        title: "今日安排：1 个日程 · 0 个提醒",
        body: "09:00-10:00 测试\n  日历：工作"
    )

    let routed = RoutedNotification(notification: notification, level: .strong)
    let message = PetState.from(routed).message ?? ""

    #expect(message.contains("Calendar: 今日安排"))
    #expect(message.contains("09:00-10:00 测试"))
}

@Test func petStateExtractsSenderFromWechatBodyPrefix() {
    let notification = WorkNotification(
        source: .wechat,
        title: "WeChat",
        body: "陈世深：今晚同步一下"
    )

    let state = PetState.from(RoutedNotification(notification: notification, level: .normal))

    #expect(state.message == "陈世深\n今晚同步一下")
}

@Test func messageRuleEngineUsesCategoryDefaults() {
    let engine = SourceRuleEngine(
        defaultLevel: .normal,
        messageApps: [
            messageAppRule(
                categories: [
                    .direct: .normal,
                    .group: .silent
                ]
            )
        ]
    )

    let groupNotification = WorkNotification(
        source: .wechat,
        title: "项目群",
        body: "今晚同步一下",
        metadata: ["messageCategory": "group"]
    )

    #expect(engine.level(for: groupNotification) == .silent)
}

@Test func messageRuleEngineLetsWhitelistRaiseLevel() {
    let engine = SourceRuleEngine(
        defaultLevel: .normal,
        messageApps: [
            messageAppRule(
                categories: [.group: .silent],
                whitelist: [
                    MessageMatchRule(
                        category: nil,
                        senderContains: ["生产故障群"],
                        titleContains: nil,
                        bodyContains: nil,
                        contains: nil,
                        level: .strong
                    )
                ]
            )
        ]
    )

    let notification = WorkNotification(
        source: .wechat,
        title: "生产故障群",
        body: "需要处理",
        metadata: ["messageCategory": "group", "sender": "生产故障群"]
    )

    #expect(engine.level(for: notification) == .strong)
}

@Test func messageRuleEngineBlacklistWinsOverWhitelist() {
    let engine = SourceRuleEngine(
        defaultLevel: .normal,
        messageApps: [
            messageAppRule(
                categories: [.direct: .normal],
                whitelist: [
                    MessageMatchRule(
                        category: nil,
                        senderContains: nil,
                        titleContains: nil,
                        bodyContains: nil,
                        contains: ["紧急"],
                        level: .strong
                    )
                ],
                blacklist: [
                    MessageMatchRule(
                        category: nil,
                        senderContains: nil,
                        titleContains: nil,
                        bodyContains: nil,
                        contains: ["广告"],
                        level: .silent
                    )
                ]
            )
        ]
    )

    let notification = WorkNotification(
        source: .wechat,
        title: "广告服务号",
        body: "紧急优惠券",
        metadata: ["messageCategory": "direct"]
    )

    #expect(engine.level(for: notification) == .silent)
}

private func messageAppRule(
    categories: [MessageCategory: NotificationLevel],
    whitelist: [MessageMatchRule] = [],
    blacklist: [MessageMatchRule] = []
) -> MessageAppRule {
    MessageAppRule(
        id: "wechat",
        displayName: "微信",
        bundleIdentifiers: [NotificationSource.wechat.bundleIdentifier],
        defaultLevel: .silent,
        categories: categories,
        whitelist: whitelist,
        blacklist: blacklist
    )
}

private func temporaryPetPack(statesJSON: String) throws -> (pack: PetAssetPack, directoryURL: URL) {
    let fileManager = FileManager.default
    let directoryURL = fileManager.temporaryDirectory
        .appendingPathComponent("workpet-sequence-tests-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let packsRoot = try #require(Bundle.module.url(forResource: "PetPacks", withExtension: nil))
    let sourceFrame = packsRoot
        .appendingPathComponent("wang-lin/frames/standing/0001.webp")
    try fileManager.copyItem(at: sourceFrame, to: directoryURL.appendingPathComponent("valid.webp"))

    let manifest = """
        {
          "id": "sequence-fixture",
          "name": "Sequence Fixture",
          "version": "0.1.0",
          "states": \(statesJSON)
        }
        """
    try Data(manifest.utf8).write(to: directoryURL.appendingPathComponent("pet.json"))

    return (try #require(PetAssetPack(directoryURL: directoryURL)), directoryURL)
}

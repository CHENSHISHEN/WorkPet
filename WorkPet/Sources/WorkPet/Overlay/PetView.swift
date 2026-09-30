import AppKit

enum PetLayoutMetrics {
    static let windowSize = CGSize(width: 280, height: 282)
    static let messageBubbleTopInset: CGFloat = 8
    static let messageBubbleVerticalInset: CGFloat = 9
    static let messageBodySpacing: CGFloat = 4

    static func petBottomInset(packID: String?) -> CGFloat {
        packID == "wang-lin" ? 0 : 16
    }

    static func maximumVisualSize(packID: String?, hasMessage: Bool) -> CGFloat {
        if packID == "wang-lin" {
            return 160
        }
        return hasMessage ? 104 : 118
    }

    static func petBubbleSpacing(packID: String?) -> CGFloat {
        packID == "wang-lin" ? 6 : 10
    }

    static func messageBubbleMaximumHeight(packID: String?) -> CGFloat {
        packID == "wang-lin" ? 108 : 112
    }

    static func messageTitleMaximumHeight(packID: String?) -> CGFloat {
        packID == "wang-lin" ? 32 : 42
    }

    static func messageBodyMaximumHeight(packID: String?) -> CGFloat {
        packID == "wang-lin" ? 54 : 58
    }

    static func availablePetHeight(packID: String?, topLimit: CGFloat) -> CGFloat {
        max(
            topLimit - petBottomInset(packID: packID) - petBubbleSpacing(packID: packID),
            72
        )
    }

    static func messageBubbleOriginY(
        packID: String?,
        bubbleHeight: CGFloat,
        boundsHeight: CGFloat
    ) -> CGFloat {
        if packID == "wang-lin" {
            return petBottomInset(packID: packID)
                + maximumVisualSize(packID: packID, hasMessage: true)
                + petBubbleSpacing(packID: packID)
        }
        return boundsHeight - bubbleHeight - messageBubbleTopInset
    }
}

struct PetCrossfadeState {
    private(set) var startedAt: TimeInterval?
    private(set) var duration: TimeInterval = 0

    var isActive: Bool {
        startedAt != nil && duration > 0
    }

    mutating func begin(duration: TimeInterval, at time: TimeInterval) {
        guard duration > 0 else {
            reset()
            return
        }
        startedAt = time
        self.duration = duration
    }

    func progress(at time: TimeInterval) -> CGFloat {
        guard let startedAt, duration > 0 else {
            return 1
        }
        return min(max(CGFloat((time - startedAt) / duration), 0), 1)
    }

    mutating func reset() {
        startedAt = nil
        duration = 0
    }
}

private struct BubbleContent {
    let title: String
    let body: String
    let titleAttributes: [NSAttributedString.Key: Any]
    let bodyAttributes: [NSAttributedString.Key: Any]
}

// MARK: - 宠物交互协议

@MainActor
protocol PetViewDelegate: AnyObject {
    func petViewDidRequestCalendar()
    func petViewDidRequestToggleDND()
    func petViewDidRequestNotificationDiagnostics()
    func petViewDidRequestInteraction(_ interaction: PetInteraction)
    func petViewIsDNDEnabled() -> Bool
}

enum PetInteraction {
    case pet
    case feed
    case poke
    case tease
}

// MARK: - 图片资源包宠物视图

@MainActor
final class PetView: NSView {
    weak var delegate: PetViewDelegate?

    private let assetStore = PetAssetStore.shared
    private var state: PetState = .idle
    private var selectedPack: PetAssetPack?
    private var currentFrames: [PetAssetFrame] = []
    private(set) var currentFrameIndex = 0
    private var frameTimer: Timer?
    private var transitionImage: NSImage?
    private var crossfadeState = PetCrossfadeState()
    private var isPressed = false

    var isCrossfading: Bool {
        crossfadeState.isActive
    }

    private var currentImage: NSImage? {
        guard !currentFrames.isEmpty else {
            return nil
        }
        return currentFrames[min(currentFrameIndex, currentFrames.count - 1)].image
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2

        selectedPack = assetStore.pack(id: "wang-lin") ?? assetStore.packs.first
        update(state: .idle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        frameTimer?.invalidate()
    }

    override var isFlipped: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.01 else {
            return nil
        }

        if containsInteractivePoint(point) {
            return self
        }

        return nil
    }

    func containsInteractivePoint(_ point: NSPoint) -> Bool {
        interactiveRect().contains(point) || bubbleRectIfNeeded()?.contains(point) == true
    }

    func update(state: PetState) {
        self.state = state
        loadFrames(for: state)
        runActionAnimation(state.action)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true

        drawBubbleIfNeeded()

        if let currentImage {
            draw(currentImage: currentImage)
        } else {
            drawFallbackPet()
        }
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        update(state: PetState(mood: .love, action: .squishing, message: nil))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self] in
            self?.isPressed = false
            self?.update(state: .idle)
        }

        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let petMenu = NSMenu()

        assetStore.reload()
        for pack in assetStore.packs {
            let item = NSMenuItem(title: pack.name, action: #selector(selectPetPack(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pack.id
            item.state = selectedPack?.id == pack.id ? .on : .off
            petMenu.addItem(item)
        }

        if petMenu.items.isEmpty {
            let empty = NSMenuItem(title: "未找到宠物资源包", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            petMenu.addItem(empty)
        }

        let petItem = NSMenuItem(title: "选择宠物", action: nil, keyEquivalent: "")
        petItem.submenu = petMenu
        menu.addItem(petItem)

        let interactMenu = NSMenu()
        interactMenu.addItem(NSMenuItem(title: "摸摸", action: #selector(interactPet), keyEquivalent: ""))
        interactMenu.addItem(NSMenuItem(title: "喂食", action: #selector(interactFeed), keyEquivalent: ""))
        interactMenu.addItem(NSMenuItem(title: "戳戳", action: #selector(interactPoke), keyEquivalent: ""))
        interactMenu.addItem(NSMenuItem(title: "逗弄", action: #selector(interactTease), keyEquivalent: ""))

        let interactItem = NSMenuItem(title: "互动", action: nil, keyEquivalent: "")
        interactItem.submenu = interactMenu
        menu.addItem(interactItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "今日待办", action: #selector(showCalendar), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "诊断通知", action: #selector(runNotificationDiagnostics), keyEquivalent: ""))

        let dndTitle = (delegate?.petViewIsDNDEnabled() ?? false) ? "关闭免打扰" : "开启免打扰"
        menu.addItem(NSMenuItem(title: dndTitle, action: #selector(toggleDND), keyEquivalent: "d"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "关于 WorkPet", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    // MARK: - Menu Actions

    @objc private func selectPetPack(_ sender: NSMenuItem) {
        guard
            let id = sender.representedObject as? String,
            let pack = assetStore.pack(id: id)
        else {
            return
        }

        selectedPack = pack
        update(state: PetState(mood: .happy, action: .bouncing, message: "\(pack.name)已上线"))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.update(state: .idle)
        }
    }

    @objc private func interactPet() {
        triggerInteraction(.pet, mood: .love, action: .wiggling, message: "呼噜噜~", resetAfter: 2.5)
    }

    @objc private func interactFeed() {
        triggerInteraction(.feed, mood: .happy, action: .bouncing, message: "好吃！", resetAfter: 2.5)
    }

    @objc private func interactPoke() {
        triggerInteraction(.poke, mood: .startled, action: .squishing, message: "喵！", resetAfter: 1.8)
    }

    @objc private func interactTease() {
        triggerInteraction(.tease, mood: .curious, action: .wiggling, message: "喵呜~", resetAfter: 2.5)
    }

    @objc private func showCalendar() {
        delegate?.petViewDidRequestCalendar()
    }

    @objc private func runNotificationDiagnostics() {
        delegate?.petViewDidRequestNotificationDiagnostics()
    }

    @objc private func toggleDND() {
        delegate?.petViewDidRequestToggleDND()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WorkPet v0.1.0"
        alert.informativeText = "图片资源包驱动的工作通知电子宠物\n\n拖拽移动 | 左键互动 | 右键选择宠物"
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func triggerInteraction(
        _ interaction: PetInteraction,
        mood: PetMood,
        action: PetAction,
        message: String,
        resetAfter seconds: Double
    ) {
        update(state: PetState(mood: mood, action: action, message: message))
        delegate?.petViewDidRequestInteraction(interaction)

        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.update(state: .idle)
        }
    }

    // MARK: - Frames

    private func loadFrames(for state: PetState) {
        frameTimer?.invalidate()
        frameTimer = nil
        resetCrossfade()
        currentFrameIndex = 0
        currentFrames = selectedPack?.frames(for: state) ?? []

        guard currentFrames.count > 1 else {
            return
        }

        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        guard currentFrames.count > 1 else {
            return
        }

        let duration = currentFrames[currentFrameIndex].duration
        frameTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.currentFrames.isEmpty else {
                    return
                }
                let previousImage = self.currentImage
                let transitionDuration = PetPlaybackTransition.duration(
                    advancingFrom: self.currentFrameIndex,
                    in: self.currentFrames
                )
                self.currentFrameIndex = (self.currentFrameIndex + 1) % self.currentFrames.count
                if let transitionDuration, let previousImage {
                    self.beginCrossfade(from: previousImage, duration: transitionDuration)
                }
                self.needsDisplay = true
                self.scheduleNextFrame()
            }
        }
    }

    func beginCrossfade(
        from image: NSImage,
        duration: TimeInterval,
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        transitionImage = image
        crossfadeState.begin(duration: duration, at: time)
    }

    private func resetCrossfade() {
        transitionImage = nil
        crossfadeState.reset()
    }

    private func draw(currentImage: NSImage) {
        let rect = petImageRect()
        let baseFraction: CGFloat = isPressed ? 0.92 : 1
        let progress = crossfadeState.progress(at: ProcessInfo.processInfo.systemUptime)

        guard let transitionImage, progress < 1 else {
            if crossfadeState.isActive {
                resetCrossfade()
            }
            currentImage.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: baseFraction
            )
            return
        }

        transitionImage.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: baseFraction * (1 - progress)
        )
        currentImage.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: baseFraction * progress
        )
    }

    // MARK: - Drawing

    private func petImageRect() -> CGRect {
        let preferred = selectedPack?.preferredSize ?? CGSize(width: 148, height: 148)
        let topLimit = bubbleRectIfNeeded()?.minY ?? bounds.maxY - 10
        let available = CGRect(
            x: 24,
            y: PetLayoutMetrics.petBottomInset(packID: selectedPack?.id),
            width: max(bounds.width - 48, 80),
            height: PetLayoutMetrics.availablePetHeight(
                packID: selectedPack?.id,
                topLimit: topLimit
            )
        )
        let maxVisualSize = PetLayoutMetrics.maximumVisualSize(
            packID: selectedPack?.id,
            hasMessage: state.message != nil
        )
        let scale = min(
            available.width / preferred.width,
            available.height / preferred.height,
            maxVisualSize / max(preferred.width, preferred.height)
        )
        let width = preferred.width * scale
        let height = preferred.height * scale

        return CGRect(
            x: bounds.midX - width / 2,
            y: available.minY,
            width: width,
            height: height
        )
    }

    private func interactiveRect() -> CGRect {
        petImageRect().insetBy(dx: 6, dy: 4)
    }

    private func bubbleRectIfNeeded() -> CGRect? {
        guard let message = state.message, !message.isEmpty else {
            return nil
        }

        let content = bubbleContent(from: message)
        let maxTextWidth = bounds.width - 44
        let titleHeight = measuredHeight(
            content.title,
            width: maxTextWidth,
            attributes: content.titleAttributes,
            maxHeight: PetLayoutMetrics.messageTitleMaximumHeight(packID: selectedPack?.id)
        )
        let bodyHeight = content.body.isEmpty ? 0 : measuredHeight(
            content.body,
            width: maxTextWidth,
            attributes: content.bodyAttributes,
            maxHeight: PetLayoutMetrics.messageBodyMaximumHeight(packID: selectedPack?.id)
        )
        let bodySpacing: CGFloat = content.body.isEmpty ? 0 : PetLayoutMetrics.messageBodySpacing
        let bubbleWidth = min(max(bounds.width - 28, 220), bounds.width - 16)
        let bubbleHeight = min(
            max(
                ceil(titleHeight + bodyHeight + bodySpacing)
                    + PetLayoutMetrics.messageBubbleVerticalInset * 2,
                48
            ),
            PetLayoutMetrics.messageBubbleMaximumHeight(packID: selectedPack?.id)
        )

        return CGRect(
            x: bounds.midX - bubbleWidth / 2,
            y: PetLayoutMetrics.messageBubbleOriginY(
                packID: selectedPack?.id,
                bubbleHeight: bubbleHeight,
                boundsHeight: bounds.height
            ),
            width: bubbleWidth,
            height: bubbleHeight
        )
    }

    private func drawBubbleIfNeeded() {
        guard let message = state.message, !message.isEmpty else {
            return
        }

        let content = bubbleContent(from: message)
        guard let bubbleRect = bubbleRectIfNeeded() else {
            return
        }

        let maxTextWidth = bounds.width - 44
        let titleHeight = measuredHeight(
            content.title,
            width: maxTextWidth,
            attributes: content.titleAttributes,
            maxHeight: PetLayoutMetrics.messageTitleMaximumHeight(packID: selectedPack?.id)
        )
        let bodyHeight = content.body.isEmpty ? 0 : measuredHeight(
            content.body,
            width: maxTextWidth,
            attributes: content.bodyAttributes,
            maxHeight: PetLayoutMetrics.messageBodyMaximumHeight(packID: selectedPack?.id)
        )
        let bodySpacing: CGFloat = content.body.isEmpty ? 0 : PetLayoutMetrics.messageBodySpacing

        NSShadow.with(color: .black.withAlphaComponent(0.16), blur: 10, offset: CGSize(width: 0, height: -2)) {
            NSColor.controlBackgroundColor.withAlphaComponent(0.97).setFill()
            NSBezierPath(roundedRect: bubbleRect, xRadius: 15, yRadius: 15).fill()
        }

        NSColor.separatorColor.withAlphaComponent(0.42).setStroke()
        let outline = NSBezierPath(roundedRect: bubbleRect, xRadius: 15, yRadius: 15)
        outline.lineWidth = 1
        outline.stroke()

        let textRect = bubbleRect.insetBy(dx: 14, dy: PetLayoutMetrics.messageBubbleVerticalInset)
        let titleRect = CGRect(
            x: textRect.minX,
            y: textRect.maxY - titleHeight,
            width: textRect.width,
            height: titleHeight
        )
        content.title.draw(with: titleRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: content.titleAttributes)

        if !content.body.isEmpty {
            let bodyRect = CGRect(
                x: textRect.minX,
                y: titleRect.minY - bodySpacing - bodyHeight,
                width: textRect.width,
                height: bodyHeight
            )
            content.body.draw(with: bodyRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: content.bodyAttributes)
        }
    }

    private func bubbleContent(from message: String) -> BubbleContent {
        let lines = message
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let title = lines.first ?? message
        let body = lines.dropFirst().joined(separator: " ")
        let displayBody = body.count > 320 ? String(body.prefix(320)) + "..." : body

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .left
        titleParagraph.lineBreakMode = .byWordWrapping
        titleParagraph.lineSpacing = 1

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.alignment = .left
        bodyParagraph.lineBreakMode = .byWordWrapping
        bodyParagraph.lineSpacing = 2

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: titleParagraph
        ]

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: bodyParagraph
        ]

        return BubbleContent(
            title: title,
            body: displayBody,
            titleAttributes: titleAttributes,
            bodyAttributes: bodyAttributes
        )
    }

    private func measuredHeight(
        _ text: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any],
        maxHeight: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty else {
            return 0
        }

        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        return min(ceil(rect.height), maxHeight)
    }

    private func drawFallbackPet() {
        let rect = petImageRect()
        NSColor.systemOrange.setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: 18, dy: 18)).fill()

        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.midX - 28, y: rect.midY + 8, width: 18, height: 22)).fill()
        NSBezierPath(ovalIn: CGRect(x: rect.midX + 10, y: rect.midY + 8, width: 18, height: 22)).fill()

        NSColor.black.setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.midX - 22, y: rect.midY + 14, width: 8, height: 10)).fill()
        NSBezierPath(ovalIn: CGRect(x: rect.midX + 16, y: rect.midY + 14, width: 8, height: 10)).fill()
    }

    // MARK: - Animation

    private func runActionAnimation(_ action: PetAction) {
        layer?.removeAnimation(forKey: "petAction")

        guard selectedPack?.id != "wang-lin" else {
            return
        }

        switch action {
        case .breathing:
            addBreathingAnimation()
        case .bouncing:
            addKeyframeAnimation(keyPath: "transform.translation.y", values: [0, 10, 0, 7, 0], duration: 0.7, repeatCount: 2)
        case .waving, .wiggling:
            addKeyframeAnimation(keyPath: "transform.rotation.z", values: [0, -0.045, 0.045, -0.03, 0], duration: 0.55, repeatCount: 2)
        case .spinning:
            addKeyframeAnimation(keyPath: "transform.rotation.z", values: [0, CGFloat.pi * 2], duration: 0.55, repeatCount: 1)
        case .squishing:
            addKeyframeAnimation(keyPath: "transform.scale", values: [1, 0.93, 1.04, 1], duration: 0.28, repeatCount: 1)
        case .sleeping:
            addBreathingAnimation(duration: 3.2, scale: 1.015)
        case .resting, .hiding:
            break
        }
    }

    private func addBreathingAnimation(duration: CFTimeInterval = 2.4, scale: CGFloat = 1.018) {
        let animation = CABasicAnimation(keyPath: "transform.scale.y")
        animation.fromValue = 1
        animation.toValue = scale
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(animation, forKey: "petAction")
    }

    private func addKeyframeAnimation(keyPath: String, values: [Any], duration: CFTimeInterval, repeatCount: Float) {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.duration = duration
        animation.repeatCount = repeatCount
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(animation, forKey: "petAction")
    }
}

private extension NSShadow {
    static func with(color: NSColor, blur: CGFloat, offset: CGSize, draw: () -> Void) {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowBlurRadius = blur
        shadow.shadowOffset = offset

        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }
}

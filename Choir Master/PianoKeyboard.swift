import SwiftUI
import UIKit

struct PianoKeyboard: UIViewRepresentable {
    @ObservedObject var model: ConductorModel
    func makeUIView(context: Context) -> KeyboardScrollView { KeyboardScrollView() }
    func updateUIView(_ view: KeyboardScrollView, context: Context) {
        view.keyboard.down = { model.noteDown($0) }
        view.keyboard.up = { model.noteUp($0) }
        view.keyboard.cancelled = { model.noteCancelled($0) }
        view.configure(start: model.octave * 12 + 12, sounding: model.sounding, names: model.keyNames, divisions: model.divisions)
    }
}

// Keep key attacks immediate; the keyboard distinguishes one-finger swipes from chord touches.
final class KeyboardScrollView: UIScrollView {
    let keyboard = KeyboardView()
    private var start: Int?
    private var divisions = 12
    private var viewportWidth: CGFloat = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
        keyboard.semanticContentAttribute = .forceLeftToRight
        delaysContentTouches = false
        canCancelContentTouches = true
        isDirectionalLockEnabled = true
        alwaysBounceVertical = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = true
        isScrollEnabled = false // Touch routing below keeps scrolling separate from playing.
        keyboard.scrollBy = { [weak self] distance in
            guard let self else { return }
            let limit = max(0, self.contentSize.width - self.bounds.width)
            self.contentOffset = CGPoint(x: min(limit, max(0, self.contentOffset.x + distance)), y: 0)
            self.flashScrollIndicators()
        }
        keyboard.isMultipleTouchEnabled = true
        addSubview(keyboard)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(start: Int, sounding: Set<Double>, names: [String], divisions: Int) {
        let changed = self.start != start || self.divisions != divisions
        self.divisions = divisions
        self.start = start
        keyboard.configure(start: start, sounding: sounding, names: names, divisions: divisions)
        if changed { setNeedsLayout() }
        if changed { setContentOffset(.zero, animated: false) }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let fraction = viewportWidth > 0 ? contentOffset.x / viewportWidth : 0
        keyboard.frame = CGRect(x: 0, y: 0, width: max(width * (divisions == 24 ? 4 : 2), divisions == 24 ? 15 * 44 / 0.31 : 0), height: max(0, bounds.height - 8))
        contentSize = CGSize(width: max(width * (divisions == 24 ? 4 : 2), divisions == 24 ? 15 * 44 / 0.31 : 0), height: bounds.height)
        if viewportWidth != width {
            viewportWidth = width
            contentOffset = CGPoint(x: min(contentSize.width - width, max(0, fraction * width)), y: 0)
        }
    }
    override func touchesShouldCancel(in view: UIView) -> Bool { view === keyboard || super.touchesShouldCancel(in: view) }
}

final class KeyboardView: UIView {
    var down: ((Double) -> Void)?
    var up: ((Double) -> Void)?
    var cancelled: ((Double) -> Void)?
    var scrollBy: ((CGFloat) -> Void)?
    private var activeTouches: Set<ObjectIdentifier> = []
    private var dragTouch: ObjectIdentifier?
    private var dragOrigin = CGPoint.zero
    private var dragLast = CGPoint.zero
    private var dragging = false
    private var start = 48
    private var sounding: Set<Double> = []
    private var names = NoteNaming.pitchClasses(international: false)
    private var divisions = 12
    private var touches: [ObjectIdentifier: Double] = [:]
    private var geometryBounds = CGRect.null
    private var geometryDirty = true
    private var keys: [(note: Double, rect: CGRect, black: Bool)] = []
    func configure(start: Int, sounding: Set<Double>, names: [String], divisions: Int) {
        let geometryChanged = self.start != start || self.divisions != divisions
        let labelsChanged = self.names != names
        let soundChanged = self.sounding != sounding
        if geometryChanged { cancelTouches(); geometryDirty = true }
        self.divisions = divisions
        self.start = start; self.sounding = sounding; self.names = names
        if geometryChanged { setNeedsLayout() }
        if labelsChanged { updateAccessibility() }
        if soundChanged { updateAccessibilitySelection() }
        if geometryChanged || labelsChanged || soundChanged { setNeedsDisplay() }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard geometryDirty || geometryBounds != bounds else { return }
        geometryDirty = false; geometryBounds = bounds
        keys = []
        let whites = (start...(start + 24)).filter { ![1,3,6,8,10].contains($0 % 12) }
        let width = bounds.width / CGFloat(whites.count)
        for (i,note) in whites.enumerated() { appendKey(note, rect: CGRect(x: CGFloat(i)*width, y: 0, width: width, height: bounds.height), black: false) }
        for note in start...(start + 24) where [1,3,6,8,10].contains(note % 12) {
            let before = whites.filter { $0 < note }.count
            appendKey(note, rect: CGRect(x: CGFloat(before)*width-width*0.31, y: 0, width: width*0.62, height: bounds.height*0.60), black: true)
        }
        updateAccessibility()
    }
    private func updateAccessibility() {
        accessibilityElements = keys.map { key in
            let element = PianoKeyAccessibilityElement(accessibilityContainer: self)
            element.activate = { [weak self] in
                guard let self else { return false }
                self.down?(key.note)
                // VoiceOver activation gives a short audible note without requiring a held touch.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.up?(key.note) }
                return true
            }
            element.accessibilityLabel = NoteNaming.label(key.note, names: names)
            element.accessibilityTraits = sounding.contains(key.note) ? [.button, .selected] : [.button]
            element.accessibilityFrameInContainerSpace = key.rect
            return element
        }
    }
    private func updateAccessibilitySelection() {
        guard let elements = accessibilityElements as? [PianoKeyAccessibilityElement] else { return }
        for (key, element) in zip(keys, elements) { element.accessibilityTraits = sounding.contains(key.note) ? [.button, .selected] : [.button] }
    }
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard direction == .left || direction == .right else { return false }
        let distance = (superview?.bounds.width ?? bounds.width) * 0.75
        scrollBy?(direction == .left ? distance : -distance)
        UIAccessibility.post(notification: .pageScrolled, argument: nil)
        return true
    }
    private func appendKey(_ note: Int, rect: CGRect, black: Bool) {
        guard divisions == 24 else { keys.append((Double(note), rect, black)); return }
        // Split each physical key left/right: base pitch, then 50 cents above it.
        // The visible range ends at its final C; it has no raised half beyond that range.
        if note == start + 24 { keys.append((Double(note), rect, black)); return }
        let half = rect.width / 2
        keys.append((Double(note), CGRect(x: rect.minX, y: rect.minY, width: half, height: rect.height), black))
        keys.append((Double(note) + 0.5, CGRect(x: rect.minX + half, y: rect.minY, width: half, height: rect.height), black))
    }
    override func draw(_ rect: CGRect) {
        for key in keys {
            let active = sounding.contains(key.note)
            let quarter = key.note != key.note.rounded(.down)
            let resting: UIColor = key.black ? (quarter ? UIColor(red: 0.12, green: 0.23, blue: 0.27, alpha: 1) : UIColor(white: 0.13, alpha: 1)) : (quarter ? UIColor(red: 0.87, green: 0.94, blue: 0.95, alpha: 1) : .white)
            (active ? UIColor.systemTeal : resting).setFill()
            let path = UIBezierPath(roundedRect: key.rect.insetBy(dx: 0.6, dy: 1), cornerRadius: 4)
            path.fill(); UIColor(white: 0.65, alpha: 1).setStroke(); path.lineWidth = 0.5; path.stroke()
            let text = NoteNaming.label(key.note, names: names)
            let font = UIFont.systemFont(ofSize: min(key.black ? 10 : 12, key.rect.width * 0.45), weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: (key.black || active) ? UIColor.white : UIColor.darkGray]
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: key.rect.midX - size.width/2, y: key.rect.maxY - size.height - 10), withAttributes: attributes)
        }
    }
    private func hit(_ point: CGPoint) -> Double? { keys.reversed().first { $0.rect.contains(point) }?.note }
    override func touchesBegan(_ incoming: Set<UITouch>, with event: UIEvent?) {
        activeTouches.formUnion(incoming.map(ObjectIdentifier.init))
        if activeTouches.count == 1, let touch = incoming.first {
            dragTouch = ObjectIdentifier(touch)
            dragOrigin = touch.location(in: window)
            dragLast = dragOrigin
            dragging = false
        } else {
            dragTouch = nil // A chord cannot turn into a swipe when one finger lifts.
            dragging = false
        }
        track(incoming)
    }
    override func touchesMoved(_ incoming: Set<UITouch>, with event: UIEvent?) {
        if !handleDrag(incoming) { track(incoming) }
    }
    private func handleDrag(_ incoming: Set<UITouch>) -> Bool {
        guard let id = dragTouch, let touch = incoming.first(where: { ObjectIdentifier($0) == id }) else { return false }
        let point = touch.location(in: window)
        let dx = point.x - dragOrigin.x
        let dy = point.y - dragOrigin.y
        if !dragging, abs(dx) >= 24, abs(dx) > abs(dy) {
            dragging = true
            let notes = Set(touches.values)
            touches.removeAll()
            for note in notes { cancelled?(note) }
        }
        if dragging {
            scrollBy?(dragLast.x - point.x)
            dragLast = point
        }
        return dragging
    }
    private func track(_ incoming: Set<UITouch>) {
        for touch in incoming {
            let id = ObjectIdentifier(touch)
            let old = touches[id]; let new = hit(touch.location(in: self))
            if old == new { continue }
            touches.removeValue(forKey: id)
            if let old, !touches.values.contains(old) { up?(old) }
            if let new { let alreadyPressed = touches.values.contains(new); touches[id] = new; if !alreadyPressed { down?(new) } }
        }
    }
    override func touchesEnded(_ incoming: Set<UITouch>, with event: UIEvent?) {
        _ = handleDrag(incoming)
        finish(incoming)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches, cancelled: true) }
    private func finish(_ incoming: Set<UITouch>, cancelled: Bool = false) {
        for touch in incoming {
            let id = ObjectIdentifier(touch)
            activeTouches.remove(id)
            if dragTouch == id { dragTouch = nil; dragging = false }
            if let note = touches.removeValue(forKey: ObjectIdentifier(touch)), !touches.values.contains(note) { if cancelled { self.cancelled?(note) } else { up?(note) } } }
    }
    private func cancelTouches() {
        let notes = Set(touches.values)
        touches.removeAll(); activeTouches.removeAll(); dragTouch = nil; dragging = false
        for note in notes { cancelled?(note) }
    }
    override func didMoveToWindow() { if window == nil { cancelTouches() } }
}

private final class PianoKeyAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Bool)?
    override func accessibilityActivate() -> Bool { activate?() ?? false }
}

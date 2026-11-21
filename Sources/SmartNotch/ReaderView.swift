import AppKit
import SwiftUI
import QuartzCore

final class ClickableReaderTextView: NSTextView {
    var onWordClick: ((Int) -> Void)?
    private let wordUnderline = CALayer()
    private let departingUnderline = CALayer()
    private var activeRange: NSRange?
    private var underlineRect: CGRect?

    func prepareUnderline() {
        wantsLayer = true
        for indicator in [departingUnderline, wordUnderline] {
            indicator.anchorPoint = CGPoint(x: 0, y: 0.5)
            indicator.bounds = CGRect(x: 0, y: 0, width: 1, height: 2)
            indicator.cornerRadius = 1
            indicator.isHidden = true
            layer?.addSublayer(indicator)
        }
    }

    override func layout() {
        super.layout()
        if let activeRange { placeUnderline(range: activeRange, color: nil, animated: false) }
    }

    func placeUnderline(range: NSRange?, color: NSColor?, animated: Bool) {
        guard let range, let layoutManager, let textContainer else {
            activeRange = nil
            underlineRect = nil
            wordUnderline.isHidden = true
            departingUnderline.isHidden = true
            return
        }
        layoutManager.ensureLayout(for: textContainer)
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        // Keep the stroke below the glyphs without changing text layout.
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
        let baseline = layoutManager.location(forGlyphAt: glyphs.location).y
        let wordFont = textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: 20, weight: .medium)
        let thickness = max(2, wordFont.underlineThickness * 2)
        rect = CGRect(x: rect.minX,
                      y: textContainerOrigin.y + line.minY + baseline - wordFont.underlinePosition - thickness / 2,
                      width: max(2, rect.width), height: thickness)
        let previous = wordUnderline.presentation()?.frame ?? underlineRect
        let previousRange = activeRange
        activeRange = range
        if let color {
            wordUnderline.backgroundColor = color.cgColor
            departingUnderline.backgroundColor = color.cgColor
        }
        guard rect != underlineRect || animated else { return }
        underlineRect = rect
        let shouldAnimate = animated && previousRange != range && previous != nil
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        wordUnderline.removeAllAnimations()
        departingUnderline.removeAllAnimations()
        departingUnderline.isHidden = true
        wordUnderline.isHidden = false
        wordUnderline.bounds = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)
        wordUnderline.cornerRadius = rect.height / 2
        wordUnderline.position = CGPoint(x: rect.minX, y: rect.midY)
        wordUnderline.transform = CATransform3DIdentity
        CATransaction.commit()
        guard shouldAnimate, let previous else { return }
        let forward = range.location > (previousRange?.location ?? range.location)
        let sameLine = abs(previous.midY - rect.midY) < rect.height * 2
        let tip: CGFloat = 2
        if sameLine {
            // One continuous underline glides and changes width together,
            // matching the reference's left/width transition.
            animate(wordUnderline, positions: [
                CGPoint(x: previous.minX, y: previous.midY),
                CGPoint(x: rect.minX, y: rect.midY)
            ], widths: [previous.width, rect.width], times: [0, 1], duration: 0.3)
        } else {
            // A line break contracts and reveals locally instead of drawing
            // a diagonal stroke through the script.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            departingUnderline.isHidden = false
            departingUnderline.bounds = CGRect(x: 0, y: 0, width: previous.width, height: previous.height)
            departingUnderline.cornerRadius = previous.height / 2
            departingUnderline.position = CGPoint(x: forward ? previous.maxX - tip : previous.minX, y: previous.midY)
            departingUnderline.transform = CATransform3DMakeScale(tip / previous.width, 1, 1)
            departingUnderline.opacity = 0
            CATransaction.commit()
            animate(departingUnderline, positions: [CGPoint(x: previous.minX, y: previous.midY), departingUnderline.position], widths: [previous.width, tip], times: [0, 1])
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.16
            departingUnderline.add(fade, forKey: "fade")
            animate(wordUnderline, positions: [CGPoint(x: forward ? rect.minX : rect.maxX - tip, y: rect.midY), wordUnderline.position], widths: [tip, rect.width], times: [0, 1])
        }
    }

    private func animate(_ indicator: CALayer, positions: [CGPoint], widths: [CGFloat], times: [NSNumber], duration: CFTimeInterval = 0.18) {
        let movement = CAKeyframeAnimation(keyPath: "position")
        movement.values = positions.map { NSValue(point: $0) }
        movement.keyTimes = times
        movement.duration = duration
        let contraction = CAKeyframeAnimation(keyPath: "transform.scale.x")
        contraction.values = widths.map { $0 / indicator.bounds.width }
        contraction.keyTimes = times
        contraction.duration = duration
        let curve = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
        movement.timingFunctions = Array(repeating: curve, count: times.count - 1)
        contraction.timingFunctions = movement.timingFunctions
        let transition = CAAnimationGroup()
        transition.animations = [movement, contraction]
        transition.duration = duration
        indicator.add(transition, forKey: "word-traversal")
    }


    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func cursorUpdate(with event: NSEvent) { NSCursor.pointingHand.set() }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let layoutManager, let textContainer, layoutManager.numberOfGlyphs > 0 else { return }
        layoutManager.ensureLayout(for: textContainer)
        let local = convert(event.locationInWindow, from: nil)
        let point = NSPoint(x: local.x - textContainerOrigin.x, y: local.y - textContainerOrigin.y)
        let glyph = layoutManager.glyphIndex(for: point, in: textContainer)
        guard glyph < layoutManager.numberOfGlyphs else { return }
        let box = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        guard box.insetBy(dx: -1, dy: -1).contains(point) else { return }
        onWordClick?(layoutManager.characterIndexForGlyph(at: glyph))
    }
}

struct ReaderView: NSViewRepresentable {
    let model: PromptModel

    final class Coordinator {
        var text = ""
        var size = 0.0
        var index = -1
        var ink: PromptInk?
        var outlined = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.identifier = NSUserInterfaceItemIdentifier("prompt-reader")
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let text = ClickableReaderTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        text.prepareUnderline()
        text.onWordClick = { character in
            if let index = model.script.wordIndex(containingUTF16: character) { model.activateWord(at: index) }
        }
        text.minSize = .zero
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.isEditable = false
        text.isSelectable = false
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 8, height: 16)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.lineFragmentPadding = 0
        text.setAccessibilityLabel("Teleprompter script")
        text.setAccessibilityHelp("Click a word to make it the active reading position.")
        scroll.documentView = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? ClickableReaderTextView else { return }
        let cache = context.coordinator
        let layoutChanged = cache.text != model.text || cache.size != model.textSize
        let followPosition = layoutChanged || cache.index != model.wordIndex
        let outlined = model.transparency >= 50
        let changed = layoutChanged || cache.ink != model.ink || cache.outlined != outlined
        let rgb = model.ink.rgb
        let foreground = NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        if changed {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 9
            let value = model.script.words.isEmpty ? "Write or paste content in the editor to begin." : model.text
            var attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: model.textSize, weight: .medium),
                .foregroundColor: foreground,
                .paragraphStyle: paragraph
            ]
            if outlined {
                let edge = NSColor.black.withAlphaComponent(0.7)
                let shadow = NSShadow()
                shadow.shadowColor = edge
                shadow.shadowBlurRadius = 2
                shadow.shadowOffset = NSSize(width: 0, height: -1)
                attributes[.shadow] = shadow
                attributes[.strokeColor] = edge
                attributes[.strokeWidth] = -0.5
            }
            textView.textStorage?.setAttributedString(NSAttributedString(string: value, attributes: attributes))
            cache.text = model.text
            cache.size = model.textSize
            cache.index = -1
            cache.ink = model.ink
            cache.outlined = outlined
        }
        guard changed || cache.index != model.wordIndex else { return }
        guard model.script.words.indices.contains(model.wordIndex) else {
            textView.placeUnderline(range: nil, color: nil, animated: false)
            return
        }
        let range = model.script.words[model.wordIndex].range
        let underline = model.ink.underlineRGB
        textView.placeUnderline(range: range,
            color: NSColor(srgbRed: underline.0, green: underline.1, blue: underline.2, alpha: 1),
            animated: !layoutChanged && cache.index >= 0)
        cache.index = model.wordIndex
        guard followPosition else { return }
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        guard let layout = textView.layoutManager, let container = textView.textContainer else { return }
        let glyph = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layout.boundingRect(forGlyphRange: glyph, in: container)
        let limit = max(0, textView.bounds.height - scroll.contentView.bounds.height)
        let y = min(limit, max(0, rect.minY - 24))
        // Follow the spoken word; manual scrolling remains available while paused.
        scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}

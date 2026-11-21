import Foundation

nonisolated enum PanelGeometry {
    static func hotspot(frame: CGRect, safeTop: CGFloat, notchWidth: CGFloat, menuBarInset: CGFloat) -> CGRect {
        let width = safeTop > 0 ? notchWidth : 210
        let height = safeTop > 0 ? max(26, menuBarInset) : menuBarInset + 26
        return CGRect(x: frame.midX - width / 2, y: frame.maxY - height, width: width, height: height)
    }

    static func isOverNotch(_ point: CGPoint, hotspot: CGRect) -> Bool {
        // CGRect.contains excludes its maximum edges. macOS can report the
        // pointer exactly at maxY when it is pushed against the screen border.
        point.x >= hotspot.minX && point.x <= hotspot.maxX
            && point.y >= hotspot.minY && point.y <= hotspot.maxY
    }

    static func panelFrame(screen: CGRect, width: CGFloat, height: CGFloat, menuBarInset: CGFloat) -> CGRect {
        let width = min(width, screen.width - 32)
        let height = min(height, screen.height - menuBarInset - 32)
        return CGRect(x: screen.midX - width / 2, y: screen.maxY - menuBarInset - height, width: width, height: height)
    }
}

import CoreGraphics

/// All rectangles in this module use the Accessibility coordinate space:
/// origin at the top-left of the primary screen, y grows downwards.

public enum Action: String, CaseIterable, Sendable {
    case left, right, top, bottom, maximize

    var opposite: Action {
        switch self {
        case .left: .right
        case .right: .left
        case .top: .bottom
        case .bottom: .top
        case .maximize: .maximize
        }
    }
}

public struct Screen: Equatable, Sendable {
    /// Full screen bounds, used to decide which screen a window is on.
    public var frame: CGRect
    /// Bounds minus menu bar and Dock, used for layout.
    public var visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

/// What we did to a window last time, so a repeated press can be recognised
/// even when the app rounded the size (terminals snap to their character grid).
public struct LastMove: Equatable, Sendable {
    public var action: Action
    public var resultingFrame: CGRect

    public init(action: Action, resultingFrame: CGRect) {
        self.action = action
        self.resultingFrame = resultingFrame
    }
}

public enum Layout {
    /// Converts an AppKit rect (bottom-left origin) to Accessibility space.
    public static func flip(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func frame(for action: Action, in area: CGRect) -> CGRect {
        let halfWidth = (area.width / 2).rounded(.down)
        let halfHeight = (area.height / 2).rounded(.down)
        switch action {
        case .left:
            return CGRect(x: area.minX, y: area.minY, width: halfWidth, height: area.height)
        case .right:
            return CGRect(x: area.minX + halfWidth, y: area.minY, width: area.width - halfWidth, height: area.height)
        case .top:
            return CGRect(x: area.minX, y: area.minY, width: area.width, height: halfHeight)
        case .bottom:
            return CGRect(x: area.minX, y: area.minY + halfHeight, width: area.width, height: area.height - halfHeight)
        case .maximize:
            return area
        }
    }

    /// The screen showing most of the window, or the nearest one if it is off-screen.
    public static func screenIndex(for window: CGRect, in screens: [Screen]) -> Int? {
        guard !screens.isEmpty else { return nil }
        let areas = screens.map { screen -> CGFloat in
            let overlap = screen.frame.intersection(window)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 {
            return best
        }
        return screens.indices.min { distance(window, screens[$0].frame) < distance(window, screens[$1].frame) }
    }

    /// The nearest screen to the left/right of `current`, preferring the one that overlaps it vertically.
    public static func adjacentScreenIndex(to current: Int, direction: Action, in screens: [Screen]) -> Int? {
        let here = screens[current].frame
        let candidates = screens.indices.filter { index in
            guard index != current else { return false }
            let there = screens[index].frame
            switch direction {
            case .left: return there.midX < here.midX && there.maxX <= here.minX + 1
            case .right: return there.midX > here.midX && there.minX >= here.maxX - 1
            default: return false
            }
        }
        return candidates.min { a, b in
            let gapA = horizontalGap(here, screens[a].frame), gapB = horizontalGap(here, screens[b].frame)
            if gapA != gapB { return gapA < gapB }
            return abs(screens[a].frame.midY - here.midY) < abs(screens[b].frame.midY - here.midY)
        }
    }

    /// Where the window should go. Pressing left/right again when the window is
    /// already in that half moves it to the facing half of the next screen over.
    public static func target(
        for action: Action,
        window: CGRect,
        screens: [Screen],
        lastMove: LastMove? = nil
    ) -> CGRect? {
        guard let current = screenIndex(for: window, in: screens) else { return nil }
        let destination = frame(for: action, in: screens[current].visibleFrame)

        if action == .left || action == .right {
            let alreadyThere = approximatelyEqual(window, destination)
                || (lastMove?.action == action && approximatelyEqual(window, lastMove!.resultingFrame))
            if alreadyThere, let next = adjacentScreenIndex(to: current, direction: action, in: screens) {
                return frame(for: action.opposite, in: screens[next].visibleFrame)
            }
        }
        return destination
    }

    public static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }

    private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        hypot(a.midX - b.midX, a.midY - b.midY)
    }

    private static func horizontalGap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        max(b.minX - a.maxX, a.minX - b.maxX, 0)
    }
}

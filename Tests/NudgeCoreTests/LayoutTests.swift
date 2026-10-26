import CoreGraphics
import Testing
@testable import NudgeCore

// A 1440x900 laptop with a 25pt menu bar, and a 2560x1440 monitor to its right
// whose top edge sits 200pt higher (Accessibility space: y grows downwards).
private let laptop = Screen(
    frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875)
)
private let monitor = Screen(
    frame: CGRect(x: 1440, y: -200, width: 2560, height: 1440),
    visibleFrame: CGRect(x: 1440, y: -175, width: 2560, height: 1415)
)
private let screens = [laptop, monitor]

@Suite struct FrameForAction {
    let area = CGRect(x: 0, y: 25, width: 1441, height: 875)

    @Test func leftAndRightHalvesCoverTheAreaWithoutGaps() {
        let left = Layout.frame(for: .left, in: area)
        let right = Layout.frame(for: .right, in: area)
        #expect(left == CGRect(x: 0, y: 25, width: 720, height: 875))
        #expect(right == CGRect(x: 720, y: 25, width: 721, height: 875))
    }

    @Test func topAndBottomHalvesCoverTheAreaWithoutGaps() {
        let top = Layout.frame(for: .top, in: area)
        let bottom = Layout.frame(for: .bottom, in: area)
        #expect(top == CGRect(x: 0, y: 25, width: 1441, height: 437))
        #expect(bottom == CGRect(x: 0, y: 462, width: 1441, height: 438))
    }

    @Test func maximizeFillsTheArea() {
        #expect(Layout.frame(for: .maximize, in: area) == area)
    }
}

@Suite struct Flip {
    @Test func convertsBottomLeftOriginToTopLeft() {
        // A secondary screen above the primary one in AppKit space.
        let appKit = CGRect(x: 100, y: 900, width: 1920, height: 1080)
        #expect(Layout.flip(appKit, primaryScreenHeight: 900) == CGRect(x: 100, y: -1080, width: 1920, height: 1080))
    }
}

@Suite struct ScreenSelection {
    @Test func picksTheScreenWithMostOfTheWindow() {
        let mostlyOnMonitor = CGRect(x: 1300, y: 100, width: 800, height: 600)
        #expect(Layout.screenIndex(for: mostlyOnMonitor, in: screens) == 1)
    }

    @Test func fallsBackToNearestScreenWhenOffScreen() {
        let offToTheLeft = CGRect(x: -3000, y: 100, width: 500, height: 500)
        #expect(Layout.screenIndex(for: offToTheLeft, in: screens) == 0)
    }

    @Test func noScreensMeansNoIndex() {
        #expect(Layout.screenIndex(for: .zero, in: []) == nil)
    }

    @Test func findsAdjacentScreens() {
        #expect(Layout.adjacentScreenIndex(to: 0, direction: .right, in: screens) == 1)
        #expect(Layout.adjacentScreenIndex(to: 1, direction: .left, in: screens) == 0)
        #expect(Layout.adjacentScreenIndex(to: 0, direction: .left, in: screens) == nil)
        #expect(Layout.adjacentScreenIndex(to: 1, direction: .right, in: screens) == nil)
    }

    @Test func prefersTheClosestScreenWhenThereAreThree() {
        let farRight = Screen(
            frame: CGRect(x: 4000, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 4000, y: 0, width: 1920, height: 1080)
        )
        #expect(Layout.adjacentScreenIndex(to: 0, direction: .right, in: [laptop, farRight, monitor]) == 2)
    }

    @Test func screenStackedAboveIsNotLeftOrRight() {
        let above = Screen(
            frame: CGRect(x: 0, y: -1080, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        )
        #expect(Layout.adjacentScreenIndex(to: 0, direction: .left, in: [laptop, above]) == nil)
        #expect(Layout.adjacentScreenIndex(to: 0, direction: .right, in: [laptop, above]) == nil)
    }
}

@Suite struct Target {
    let floating = CGRect(x: 200, y: 200, width: 600, height: 400)

    @Test func movesToHalfOfTheCurrentScreen() {
        #expect(Layout.target(for: .left, window: floating, screens: screens)
            == CGRect(x: 0, y: 25, width: 720, height: 875))
        #expect(Layout.target(for: .maximize, window: floating, screens: screens) == laptop.visibleFrame)
    }

    @Test func repeatedRightJumpsToLeftHalfOfNextScreen() {
        let rightHalf = Layout.frame(for: .right, in: laptop.visibleFrame)
        #expect(Layout.target(for: .right, window: rightHalf, screens: screens)
            == Layout.frame(for: .left, in: monitor.visibleFrame))
    }

    @Test func repeatedLeftJumpsToRightHalfOfPreviousScreen() {
        let leftHalf = Layout.frame(for: .left, in: monitor.visibleFrame)
        #expect(Layout.target(for: .left, window: leftHalf, screens: screens)
            == Layout.frame(for: .right, in: laptop.visibleFrame))
    }

    @Test func repeatedPressAtTheOuterEdgeStaysPut() {
        let leftHalf = Layout.frame(for: .left, in: laptop.visibleFrame)
        #expect(Layout.target(for: .left, window: leftHalf, screens: screens) == leftHalf)
    }

    @Test func recognisesARepeatWhenTheAppRoundedTheSize() {
        // Terminals snap to their character grid, so the window ends up a bit smaller than asked.
        let snapped = CGRect(x: 720, y: 25, width: 713, height: 868)
        let last = LastMove(action: .right, resultingFrame: snapped)
        #expect(Layout.target(for: .right, window: snapped, screens: screens, lastMove: last)
            == Layout.frame(for: .left, in: monitor.visibleFrame))
    }

    @Test func lastMoveInAnotherDirectionIsNotARepeat() {
        let snapped = CGRect(x: 720, y: 25, width: 713, height: 868)
        let last = LastMove(action: .left, resultingFrame: snapped)
        #expect(Layout.target(for: .right, window: snapped, screens: screens, lastMove: last)
            == Layout.frame(for: .right, in: laptop.visibleFrame))
    }

    @Test func upAndDownNeverChangeScreen() {
        let topHalf = Layout.frame(for: .top, in: laptop.visibleFrame)
        #expect(Layout.target(for: .top, window: topHalf, screens: screens) == topHalf)
    }
}

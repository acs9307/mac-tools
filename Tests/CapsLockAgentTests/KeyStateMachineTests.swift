import XCTest
@testable import CapsLockAgent

final class KeyStateMachineTests: XCTestCase {
    var config: CapsLockConfiguration!
    var currentTime: TimeInterval!

    override func setUp() {
        config = CapsLockConfiguration.default
        currentTime = 1000.0 // Arbitrary starting time
    }

    override func tearDown() {
        config = nil
        currentTime = nil
    }

    // MARK: - Time Provider Helper

    func makeStateMachine() -> KeyStateMachine {
        KeyStateMachine(configuration: config) { [unowned self] in
            self.currentTime
        }
    }

    func advanceTime(by interval: TimeInterval) {
        currentTime += interval
    }

    // MARK: - Basic State Transitions

    func testInitialState() {
        let sut = makeStateMachine()
        XCTAssertEqual(sut.currentState, .idle)
    }

    func testKeyDownTransition() {
        let sut = makeStateMachine()

        let result = sut.handleKeyDown()

        XCTAssertEqual(result.eventAction, .suppress)
        XCTAssertNil(result.keyAction)
        XCTAssertEqual(sut.currentState, .pressed(timestamp: currentTime))
    }

    func testKeyUpAfterQuickTap() {
        let sut = makeStateMachine()

        // Press key
        _ = sut.handleKeyDown()

        // Advance time by less than minPressDuration (0.2s)
        advanceTime(by: 0.1)

        // Release key
        let result = sut.handleKeyUp()

        XCTAssertEqual(result.eventAction, .suppress)
        XCTAssertEqual(result.keyAction, config.quickTapAction)
        XCTAssertEqual(sut.currentState, .idle)
    }

    func testKeyUpAfterLongPress() {
        let sut = makeStateMachine()

        // Press key
        _ = sut.handleKeyDown()

        // Advance time by more than minPressDuration (0.2s)
        advanceTime(by: 0.3)

        // Release key
        let result = sut.handleKeyUp()

        XCTAssertEqual(result.eventAction, .suppress)
        XCTAssertEqual(result.keyAction, config.longPressAction)
        XCTAssertEqual(sut.currentState, .idle)
    }

    func testKeyUpAtExactThreshold() {
        let sut = makeStateMachine()

        // Press key
        _ = sut.handleKeyDown()

        // Advance time by exactly minPressDuration (0.2s)
        advanceTime(by: config.minPressDuration)

        // Release key
        let result = sut.handleKeyUp()

        // At exact threshold, should trigger long press
        XCTAssertEqual(result.eventAction, .suppress)
        XCTAssertEqual(result.keyAction, config.longPressAction)
        XCTAssertEqual(sut.currentState, .idle)
    }

    // MARK: - Edge Cases

    func testKeyUpWithoutKeyDown() {
        let sut = makeStateMachine()

        let result = sut.handleKeyUp()

        // Should pass through when not in pressed state
        XCTAssertEqual(result.eventAction, .passThrough)
        XCTAssertNil(result.keyAction)
        XCTAssertEqual(sut.currentState, .idle)
    }

    func testDoubleKeyDown() {
        let sut = makeStateMachine()

        // Press key twice
        let result1 = sut.handleKeyDown()
        let result2 = sut.handleKeyDown()

        // Both should suppress
        XCTAssertEqual(result1.eventAction, .suppress)
        XCTAssertEqual(result2.eventAction, .suppress)
    }

    func testRapidTapping() {
        let sut = makeStateMachine()

        // First tap
        _ = sut.handleKeyDown()
        advanceTime(by: 0.05)
        let result1 = sut.handleKeyUp()
        XCTAssertEqual(result1.keyAction, config.quickTapAction)

        // Second tap immediately after
        advanceTime(by: 0.01)
        _ = sut.handleKeyDown()
        advanceTime(by: 0.05)
        let result2 = sut.handleKeyUp()
        XCTAssertEqual(result2.keyAction, config.quickTapAction)

        // Both should be quick taps
        XCTAssertEqual(sut.currentState, .idle)
    }

    func testVeryLongPress() {
        let sut = makeStateMachine()

        // Press key
        _ = sut.handleKeyDown()

        // Hold for a very long time (1 second)
        advanceTime(by: 1.0)

        // Release key
        let result = sut.handleKeyUp()

        XCTAssertEqual(result.eventAction, .suppress)
        XCTAssertEqual(result.keyAction, config.longPressAction)
        XCTAssertEqual(sut.currentState, .idle)
    }

    // MARK: - Long Press Detection

    func testCheckLongPressBeforeThreshold() {
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        advanceTime(by: 0.1) // Less than 0.2s threshold

        let result = sut.checkLongPress()

        XCTAssertEqual(result.eventAction, .suppress)
        XCTAssertNil(result.keyAction)
        XCTAssertEqual(sut.currentState, .pressed(timestamp: 1000.0))
    }

    func testCheckLongPressAfterThreshold() {
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        advanceTime(by: 0.25) // More than 0.2s threshold

        let result = sut.checkLongPress()

        XCTAssertEqual(result.eventAction, .suppress)
        XCTAssertEqual(result.keyAction, config.longPressAction)
        XCTAssertEqual(sut.currentState, .longPress)
    }

    func testKeyUpAfterLongPressDetected() {
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        advanceTime(by: 0.25)
        _ = sut.checkLongPress() // Transitions to longPress state

        let result = sut.handleKeyUp()

        // Should suppress without triggering another action
        XCTAssertEqual(result.eventAction, .suppress)
        XCTAssertNil(result.keyAction)
        XCTAssertEqual(sut.currentState, .idle)
    }

    // MARK: - Disabled Configuration

    func testDisabledConfiguration() {
        config.enabled = false
        let sut = makeStateMachine()

        let downResult = sut.handleKeyDown()
        XCTAssertEqual(downResult.eventAction, .passThrough)

        let upResult = sut.handleKeyUp()
        XCTAssertEqual(upResult.eventAction, .passThrough)

        let checkResult = sut.checkLongPress()
        XCTAssertEqual(checkResult.eventAction, .passThrough)
    }

    // MARK: - Custom Configuration

    func testCustomMinPressDuration() {
        config.minPressDuration = 0.5
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        advanceTime(by: 0.3) // Less than custom threshold

        let result = sut.handleKeyUp()

        XCTAssertEqual(result.keyAction, config.quickTapAction)
    }

    func testCustomActions() {
        config.quickTapAction = .sendKey(42)
        config.longPressAction = .sendModifier(.option)
        let sut = makeStateMachine()

        // Quick tap
        _ = sut.handleKeyDown()
        advanceTime(by: 0.1)
        let quickResult = sut.handleKeyUp()
        XCTAssertEqual(quickResult.keyAction, .sendKey(42))

        // Long press
        _ = sut.handleKeyDown()
        advanceTime(by: 0.3)
        let longResult = sut.handleKeyUp()
        XCTAssertEqual(longResult.keyAction, .sendModifier(.option))
    }

    func testDisabledAction() {
        config.quickTapAction = .disabled
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        advanceTime(by: 0.1)
        let result = sut.handleKeyUp()

        XCTAssertEqual(result.keyAction, .disabled)
        XCTAssertEqual(result.eventAction, .suppress)
    }

    // MARK: - Reset

    func testReset() {
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        XCTAssertNotEqual(sut.currentState, .idle)

        sut.reset()
        XCTAssertEqual(sut.currentState, .idle)
    }

    func testResetAfterLongPress() {
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        advanceTime(by: 0.3)
        _ = sut.checkLongPress()
        XCTAssertEqual(sut.currentState, .longPress)

        sut.reset()
        XCTAssertEqual(sut.currentState, .idle)
    }

    // MARK: - Timing Precision

    func testZeroDurationTap() {
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        // Don't advance time at all
        let result = sut.handleKeyUp()

        // Zero duration should be a quick tap
        XCTAssertEqual(result.keyAction, config.quickTapAction)
    }

    func testJustBelowThreshold() {
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        advanceTime(by: config.minPressDuration - 0.001)
        let result = sut.handleKeyUp()

        XCTAssertEqual(result.keyAction, config.quickTapAction)
    }

    func testJustAboveThreshold() {
        let sut = makeStateMachine()

        _ = sut.handleKeyDown()
        advanceTime(by: config.minPressDuration + 0.001)
        let result = sut.handleKeyUp()

        XCTAssertEqual(result.keyAction, config.longPressAction)
    }
}

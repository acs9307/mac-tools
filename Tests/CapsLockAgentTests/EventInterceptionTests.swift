import XCTest
@testable import CapsLockAgent

/// Integration tests for event interception and state machine integration
final class EventInterceptionTests: XCTestCase {
    var config: CapsLockConfiguration!
    var stateMachine: KeyStateMachine!
    var synthesizer: EventSynthesizer!
    var currentTime: TimeInterval!

    override func setUp() {
        config = CapsLockConfiguration.default
        currentTime = 1000.0
        stateMachine = KeyStateMachine(configuration: config) { [unowned self] in
            self.currentTime
        }
        synthesizer = EventSynthesizer()
    }

    override func tearDown() {
        config = nil
        stateMachine = nil
        synthesizer = nil
        currentTime = nil
    }

    func advanceTime(by interval: TimeInterval) {
        currentTime += interval
    }

    // MARK: - Event Stream Simulation Tests

    func testSingleQuickTapEventStream() {
        // Simulate: KeyDown -> 100ms -> KeyUp
        let downResult = stateMachine.handleKeyDown()
        XCTAssertEqual(downResult.eventAction, .suppress)
        XCTAssertNil(downResult.keyAction)

        advanceTime(by: 0.1)

        let upResult = stateMachine.handleKeyUp()
        XCTAssertEqual(upResult.eventAction, .suppress)
        XCTAssertEqual(upResult.keyAction, config.quickTapAction)

        // Verify state machine returned to idle
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testSingleLongPressEventStream() {
        // Simulate: KeyDown -> 300ms -> KeyUp
        let downResult = stateMachine.handleKeyDown()
        XCTAssertEqual(downResult.eventAction, .suppress)

        advanceTime(by: 0.3)

        let upResult = stateMachine.handleKeyUp()
        XCTAssertEqual(upResult.eventAction, .suppress)
        XCTAssertEqual(upResult.keyAction, config.longPressAction)

        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testRapidDoubleTapEventStream() {
        // First tap
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.05)
        let firstUp = stateMachine.handleKeyUp()
        XCTAssertEqual(firstUp.keyAction, config.quickTapAction)

        // Immediate second tap (10ms gap)
        advanceTime(by: 0.01)
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.05)
        let secondUp = stateMachine.handleKeyUp()
        XCTAssertEqual(secondUp.keyAction, config.quickTapAction)

        // Both taps should be quick taps, no events lost
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testTripleTapEventStream() {
        // Three rapid taps in succession
        for i in 1...3 {
            _ = stateMachine.handleKeyDown()
            advanceTime(by: 0.08)
            let upResult = stateMachine.handleKeyUp()

            XCTAssertEqual(upResult.keyAction, config.quickTapAction, "Tap \(i) should be quick tap")
            advanceTime(by: 0.02)
        }

        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testAlternatingQuickAndLongPresses() {
        // Quick tap
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.1)
        let quickUp = stateMachine.handleKeyUp()
        XCTAssertEqual(quickUp.keyAction, config.quickTapAction)

        advanceTime(by: 0.05)

        // Long press
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.3)
        let longUp = stateMachine.handleKeyUp()
        XCTAssertEqual(longUp.keyAction, config.longPressAction)

        advanceTime(by: 0.05)

        // Another quick tap
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.1)
        let quickUp2 = stateMachine.handleKeyUp()
        XCTAssertEqual(quickUp2.keyAction, config.quickTapAction)

        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testVeryRapidTapping() {
        // Simulate very rapid tapping (10 taps in quick succession)
        for i in 1...10 {
            _ = stateMachine.handleKeyDown()
            advanceTime(by: 0.03) // 30ms press
            let upResult = stateMachine.handleKeyUp()

            XCTAssertEqual(upResult.keyAction, config.quickTapAction, "Tap \(i) should be quick")
            XCTAssertEqual(upResult.eventAction, .suppress)

            advanceTime(by: 0.02) // 20ms gap
        }

        // All events should be processed, state should be idle
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testNoEventsDuplicated() {
        var eventCount = 0

        // Track each action generated
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.1)
        let upResult = stateMachine.handleKeyUp()

        if upResult.keyAction != nil {
            eventCount += 1
        }

        // Exactly one event should be generated for one key press/release cycle
        XCTAssertEqual(eventCount, 1)
    }

    func testNoEventsLostInRapidSequence() {
        var actionCount = 0

        // 5 rapid key presses
        for _ in 1...5 {
            _ = stateMachine.handleKeyDown()
            advanceTime(by: 0.05)
            let upResult = stateMachine.handleKeyUp()

            if upResult.keyAction != nil {
                actionCount += 1
            }
            advanceTime(by: 0.01)
        }

        // Should have exactly 5 actions, one for each press
        XCTAssertEqual(actionCount, 5)
    }

    func testLongPressDetectionDuringHold() {
        // Start pressing
        _ = stateMachine.handleKeyDown()

        // Check before threshold
        advanceTime(by: 0.1)
        let checkBefore = stateMachine.checkLongPress()
        XCTAssertNil(checkBefore.keyAction)
        XCTAssertEqual(stateMachine.currentState, .pressed(timestamp: 1000.0))

        // Check after threshold
        advanceTime(by: 0.15) // Total: 0.25s
        let checkAfter = stateMachine.checkLongPress()
        XCTAssertEqual(checkAfter.keyAction, config.longPressAction)
        XCTAssertEqual(stateMachine.currentState, .longPress)

        // Release should not generate another action
        advanceTime(by: 0.1)
        let upResult = stateMachine.handleKeyUp()
        XCTAssertNil(upResult.keyAction) // No duplicate action
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testEventSuppressionConsistency() {
        // All events should be suppressed when enabled
        let downResult = stateMachine.handleKeyDown()
        XCTAssertEqual(downResult.eventAction, .suppress)

        advanceTime(by: 0.1)

        let upResult = stateMachine.handleKeyUp()
        XCTAssertEqual(upResult.eventAction, .suppress)

        // Original Caps Lock behavior is completely suppressed
    }

    func testPassThroughWhenDisabled() {
        config.enabled = false
        let disabledMachine = KeyStateMachine(configuration: config)

        let downResult = disabledMachine.handleKeyDown()
        XCTAssertEqual(downResult.eventAction, .passThrough)

        let upResult = disabledMachine.handleKeyUp()
        XCTAssertEqual(upResult.eventAction, .passThrough)
    }

    func testActionSynthesisForAllActionTypes() {
        // Test that synthesizer can handle all action types without crashing

        // Send key action
        synthesizer.synthesizeEvent(for: .sendKey(53))

        // Send modifier action
        synthesizer.synthesizeEvent(for: .sendModifier(.control))

        // Disabled action
        synthesizer.synthesizeEvent(for: .disabled)

        // If we get here, all synthesis succeeded
        XCTAssertTrue(true)
    }

    func testComplexEventSequence() {
        // Simulate a complex real-world sequence:
        // Quick tap, pause, long press, pause, double tap

        // Quick tap
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.08)
        let tap1 = stateMachine.handleKeyUp()
        XCTAssertEqual(tap1.keyAction, config.quickTapAction)

        // Pause
        advanceTime(by: 0.5)

        // Long press
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.35)
        let long = stateMachine.handleKeyUp()
        XCTAssertEqual(long.keyAction, config.longPressAction)

        // Pause
        advanceTime(by: 0.3)

        // Double tap
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.06)
        let tap2 = stateMachine.handleKeyUp()
        XCTAssertEqual(tap2.keyAction, config.quickTapAction)

        advanceTime(by: 0.02)

        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.07)
        let tap3 = stateMachine.handleKeyUp()
        XCTAssertEqual(tap3.keyAction, config.quickTapAction)

        // All events processed correctly
        XCTAssertEqual(stateMachine.currentState, .idle)
    }

    func testStateResetClearsAllState() {
        // Get into pressed state
        _ = stateMachine.handleKeyDown()
        XCTAssertNotEqual(stateMachine.currentState, .idle)

        // Reset
        stateMachine.reset()
        XCTAssertEqual(stateMachine.currentState, .idle)

        // Should be able to process new events normally
        _ = stateMachine.handleKeyDown()
        advanceTime(by: 0.1)
        let upResult = stateMachine.handleKeyUp()
        XCTAssertNotNil(upResult.keyAction)
    }
}

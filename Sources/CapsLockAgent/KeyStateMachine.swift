import Foundation

/// State machine for tracking Caps Lock key state and determining actions
public final class KeyStateMachine {
    /// Current state of the state machine
    public enum State: Equatable {
        case idle
        case pressed(timestamp: TimeInterval)
        case longPress
    }

    /// Action to take with an event
    public enum EventAction: Equatable {
        case passThrough  // Let original event through unchanged
        case suppress     // Block the event from propagating
    }

    /// Result of processing a key event
    public struct ProcessResult: Equatable {
        public let eventAction: EventAction
        public let keyAction: KeyAction?

        public init(eventAction: EventAction, keyAction: KeyAction? = nil) {
            self.eventAction = eventAction
            self.keyAction = keyAction
        }
    }

    // MARK: - Properties

    private var state: State = .idle
    private let configuration: CapsLockConfiguration
    private let timeProvider: () -> TimeInterval

    // MARK: - Initialization

    /// Initialize with configuration and optional time provider (for testing)
    public init(
        configuration: CapsLockConfiguration,
        timeProvider: @escaping () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }
    ) {
        self.configuration = configuration
        self.timeProvider = timeProvider
    }

    // MARK: - Public Interface

    /// Current state of the machine (for testing/debugging)
    public var currentState: State {
        state
    }

    /// Reset state machine to idle
    public func reset() {
        state = .idle
    }

    /// Handle Caps Lock key down event
    public func handleKeyDown() -> ProcessResult {
        guard configuration.enabled else {
            return ProcessResult(eventAction: .passThrough)
        }

        switch state {
        case .idle:
            let timestamp = timeProvider()
            state = .pressed(timestamp: timestamp)
            return ProcessResult(eventAction: .suppress)

        case .pressed, .longPress:
            // Already pressed, shouldn't happen but handle gracefully
            return ProcessResult(eventAction: .suppress)
        }
    }

    /// Handle Caps Lock key up event
    public func handleKeyUp() -> ProcessResult {
        guard configuration.enabled else {
            return ProcessResult(eventAction: .passThrough)
        }

        switch state {
        case .idle:
            // Key up without key down, pass through
            return ProcessResult(eventAction: .passThrough)

        case .pressed(let downTime):
            let duration = timeProvider() - downTime
            let action = selectAction(forDuration: duration)
            state = .idle
            return ProcessResult(eventAction: .suppress, keyAction: action)

        case .longPress:
            // Long press already handled, just suppress the key up
            state = .idle
            return ProcessResult(eventAction: .suppress)
        }
    }

    /// Check if long press threshold has been exceeded
    /// Call this periodically while key is held down
    public func checkLongPress() -> ProcessResult {
        guard configuration.enabled else {
            return ProcessResult(eventAction: .passThrough)
        }

        switch state {
        case .pressed(let downTime):
            let duration = timeProvider() - downTime
            if duration >= configuration.minPressDuration {
                state = .longPress
                return ProcessResult(
                    eventAction: .suppress,
                    keyAction: configuration.longPressAction
                )
            }
            return ProcessResult(eventAction: .suppress)

        case .idle, .longPress:
            return ProcessResult(eventAction: .suppress)
        }
    }

    // MARK: - Private Methods

    private func selectAction(forDuration duration: TimeInterval) -> KeyAction {
        if duration < configuration.minPressDuration {
            return configuration.quickTapAction
        } else {
            return configuration.longPressAction
        }
    }
}

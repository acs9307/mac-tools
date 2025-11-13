import Foundation
import CoreGraphics
import MacToolsCore
import Logging

/// Agent for manipulating Caps Lock key behavior
public final class CapsLockAgent: BaseAgent {
    // MARK: - Properties

    private var eventTapManager: EventTapManager?
    private var stateMachine: KeyStateMachine
    private var eventSynthesizer: EventSynthesizer
    private var configuration: CapsLockConfiguration
    private let configurationManager: CapsLockConfigurationManager
    private let logger: Logger

    // Caps Lock virtual key code on macOS
    private static let capsLockKeyCode: CGKeyCode = 57

    // MARK: - Initialization

    /// Initialize with a specific configuration (useful for testing)
    public init(configuration: CapsLockConfiguration) {
        self.configuration = configuration
        self.configurationManager = CapsLockConfigurationManager()
        self.stateMachine = KeyStateMachine(configuration: configuration)
        self.eventSynthesizer = EventSynthesizer()
        self.logger = Logger(label: "com.mactools.capslock")

        super.init(identifier: "com.mactools.capslock", name: "Caps Lock Agent")
    }

    /// Initialize by loading configuration from persistent storage
    public convenience init() {
        let manager = CapsLockConfigurationManager()
        let config = manager.load()
        self.init(configuration: config)
    }

    // MARK: - Agent Lifecycle

    override public func performStart() throws {
        guard configuration.enabled else {
            logger.info("Caps Lock agent disabled in configuration")
            return
        }

        logger.info("Starting Caps Lock agent")

        // Create event tap manager with callback
        let manager = EventTapManager(callback: { [weak self] event in
            self?.handleKeyboardEvent(event) ?? event
        }, logger: logger)

        eventTapManager = manager

        // Start the event tap
        do {
            try manager.start()
            logger.info("Caps Lock event tap started")
        } catch {
            logger.error("Failed to start event tap: \(error)")
            eventTapManager = nil
            throw error
        }
    }

    override public func performStop() throws {
        logger.info("Stopping Caps Lock agent")

        eventTapManager?.stop()
        eventTapManager = nil
        stateMachine.reset()

        logger.info("Caps Lock agent stopped")
    }

    override public func configure(_ config: [String: Any]) async throws {
        // Extract configuration values
        if let enabled = config["enabled"] as? Bool {
            configuration.enabled = enabled
        }

        if let minPressDuration = config["minPressDuration"] as? TimeInterval {
            configuration.minPressDuration = minPressDuration
        }

        // Update state machine with new configuration
        stateMachine = KeyStateMachine(configuration: configuration)

        logger.info("Configuration updated: enabled=\(configuration.enabled), minPressDuration=\(configuration.minPressDuration)")
    }

    // MARK: - Event Handling

    private func handleKeyboardEvent(_ event: CGEvent) -> CGEvent? {
        let eventType = event.type
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Only process Caps Lock key events
        guard keyCode == Self.capsLockKeyCode else {
            return event // Pass through other keys
        }

        logger.debug("Caps Lock event: \(eventType.rawValue)")

        switch eventType {
        case .keyDown:
            return handleKeyDown(event)

        case .keyUp:
            return handleKeyUp(event)

        case .flagsChanged:
            // Caps Lock can also trigger flagsChanged events
            // Determine if it's a key down or up based on flags
            let flags = event.flags
            if flags.contains(.maskAlphaShift) {
                return handleKeyDown(event)
            } else {
                return handleKeyUp(event)
            }

        default:
            return event
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> CGEvent? {
        logger.debug("Processing Caps Lock key down")

        let result = stateMachine.handleKeyDown()

        switch result.eventAction {
        case .suppress:
            logger.debug("Suppressing Caps Lock key down")
            return nil // Suppress the original event

        case .passThrough:
            logger.debug("Passing through Caps Lock key down")
            return event
        }
    }

    private func handleKeyUp(_ event: CGEvent) -> CGEvent? {
        logger.debug("Processing Caps Lock key up")

        let result = stateMachine.handleKeyUp()

        // Synthesize replacement event if an action was determined
        if let action = result.keyAction {
            logger.debug("Synthesizing event for action: \(action)")
            eventSynthesizer.synthesizeEvent(for: action)
        }

        switch result.eventAction {
        case .suppress:
            logger.debug("Suppressing Caps Lock key up")
            return nil // Suppress the original event

        case .passThrough:
            logger.debug("Passing through Caps Lock key up")
            return event
        }
    }

    // MARK: - Public Interface

    /// Get current configuration
    public func getConfiguration() -> CapsLockConfiguration {
        configuration
    }

    /// Update configuration (in-memory only)
    public func updateConfiguration(_ newConfig: CapsLockConfiguration) async throws {
        configuration = newConfig
        stateMachine = KeyStateMachine(configuration: newConfig)
        logger.info("Configuration updated (in-memory)")

        // If agent is running and configuration changed, restart if needed
        if isRunning {
            if newConfig.enabled {
                // Already running, just updated config
                logger.info("Agent running with new configuration")
            } else {
                // Need to stop
                try await stop()
            }
        } else if newConfig.enabled {
            // Need to start
            try await start()
        }
    }

    /// Update configuration and persist to storage
    public func updateAndSaveConfiguration(_ newConfig: CapsLockConfiguration) async throws {
        try configurationManager.save(newConfig)
        try await updateConfiguration(newConfig)
        logger.info("Configuration updated and saved")
    }

    /// Reload configuration from persistent storage
    public func reloadConfiguration() async throws {
        let newConfig = configurationManager.load()
        try await updateConfiguration(newConfig)
        logger.info("Configuration reloaded from storage")
    }

    /// Save current configuration to persistent storage
    public func saveConfiguration() throws {
        try configurationManager.save(configuration)
        logger.info("Configuration saved to storage")
    }
}

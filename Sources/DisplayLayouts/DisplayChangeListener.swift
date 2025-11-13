import Foundation
import CoreGraphics
import Logging

/// Handles for display reconfiguration notifications
public protocol DisplayChangeHandler: AnyObject {
    /// Called when display configuration changes
    /// - Parameter configuration: The new display configuration
    func displayConfigurationDidChange(_ configuration: DisplayConfiguration)
}

/// Listens for display configuration changes
public final class DisplayChangeListener {
    private let logger = Logger(label: "com.mactools.displaylistener")
    private let enumerator: DisplayEnumerator
    private weak var handler: DisplayChangeHandler?

    // Debouncing
    private let debounceQueue = DispatchQueue(label: "com.mactools.displaylistener.debounce")
    private var debounceTimer: DispatchSourceTimer?
    private var debounceInterval: TimeInterval
    private var pendingNotification: Bool = false

    // State tracking
    private var currentConfiguration: DisplayConfiguration?
    private var isListening: Bool = false

    // MARK: - Initialization

    /// Initialize display change listener
    /// - Parameters:
    ///   - handler: Handler to receive configuration change notifications
    ///   - debounceInterval: Minimum time between notifications (default 0.5s)
    ///   - enumerator: Display enumerator (injectable for testing)
    public init(
        handler: DisplayChangeHandler,
        debounceInterval: TimeInterval = 0.5,
        enumerator: DisplayEnumerator = DisplayEnumerator()
    ) {
        self.handler = handler
        self.debounceInterval = debounceInterval
        self.enumerator = enumerator

        // Get initial configuration
        if let config = try? enumerator.getCurrentConfiguration() {
            self.currentConfiguration = config
        }
    }

    deinit {
        stopListening()
    }

    // MARK: - Public Interface

    /// Start listening for display changes
    public func startListening() {
        guard !isListening else {
            logger.debug("Already listening for display changes")
            return
        }

        logger.info("Starting display change listener")

        // Register for display configuration change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayReconfiguration),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        isListening = true
        logger.info("Display change listener started")
    }

    /// Stop listening for display changes
    public func stopListening() {
        guard isListening else { return }

        logger.info("Stopping display change listener")

        NotificationCenter.default.removeObserver(self)
        cancelDebounceTimer()

        isListening = false
        logger.info("Display change listener stopped")
    }

    /// Get current display configuration
    public func getCurrentConfiguration() -> DisplayConfiguration? {
        return currentConfiguration
    }

    /// Force a configuration check (useful for manual refresh)
    public func checkConfiguration() {
        handleDisplayReconfiguration()
    }

    // MARK: - Internal

    @objc private func handleDisplayReconfiguration() {
        logger.debug("Display reconfiguration detected")

        // Cancel existing debounce timer
        cancelDebounceTimer()

        // Mark that we have a pending notification
        pendingNotification = true

        // Start new debounce timer
        let timer = DispatchSource.makeTimerSource(queue: debounceQueue)
        timer.schedule(deadline: .now() + debounceInterval)
        timer.setEventHandler { [weak self] in
            self?.processConfigurationChange()
        }
        timer.resume()

        debounceTimer = timer
    }

    private func processConfigurationChange() {
        logger.debug("Processing debounced configuration change")

        // Get new configuration
        guard let newConfig = try? enumerator.getCurrentConfiguration() else {
            logger.warning("Failed to get display configuration")
            return
        }

        // Check if actually changed
        if let current = currentConfiguration {
            // Use fuzzy matching to avoid spurious notifications
            if current.matches(newConfig, tolerance: 1.0) {
                logger.debug("Configuration unchanged (fuzzy match), skipping notification")
                pendingNotification = false
                return
            }
        }

        // Update current configuration
        currentConfiguration = newConfig

        // Notify handler
        logger.info("Display configuration changed: \(newConfig.debugDescription)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.handler?.displayConfigurationDidChange(newConfig)
            self.pendingNotification = false
        }
    }

    private func cancelDebounceTimer() {
        debounceTimer?.cancel()
        debounceTimer = nil
    }

    // MARK: - Configuration

    /// Update debounce interval
    public func setDebounceInterval(_ interval: TimeInterval) {
        debounceQueue.sync {
            self.debounceInterval = interval
        }
    }

    /// Check if listener is active
    public var isActive: Bool {
        return isListening
    }

    /// Check if there's a pending notification
    public var hasPendingNotification: Bool {
        return debounceQueue.sync { pendingNotification }
    }
}

/// Registry for tracking display configurations
public final class DisplayConfigurationRegistry {
    private var configurations: [String: DisplayConfiguration] = [:]
    private let queue = DispatchQueue(label: "com.mactools.displayregistry", attributes: .concurrent)

    public init() {}

    // MARK: - Storage

    /// Store a display configuration
    /// - Parameters:
    ///   - configuration: Configuration to store
    ///   - identifier: Optional custom identifier (defaults to signature)
    public func store(_ configuration: DisplayConfiguration, identifier: String? = nil) {
        let id = identifier ?? configuration.signature
        queue.async(flags: .barrier) {
            self.configurations[id] = configuration
        }
    }

    /// Retrieve a configuration by identifier
    /// - Parameter identifier: Configuration identifier
    /// - Returns: Configuration if found
    public func retrieve(_ identifier: String) -> DisplayConfiguration? {
        return queue.sync {
            configurations[identifier]
        }
    }

    /// Find configuration matching current setup
    /// - Parameter current: Current configuration
    /// - Returns: Stored configuration that matches (fuzzy)
    public func findMatching(_ current: DisplayConfiguration) -> (identifier: String, configuration: DisplayConfiguration)? {
        return queue.sync {
            for (id, config) in configurations {
                if current.matches(config, tolerance: 1.0) {
                    return (id, config)
                }
            }
            return nil
        }
    }

    /// Get all stored configurations
    /// - Returns: Dictionary of identifier → configuration
    public func allConfigurations() -> [String: DisplayConfiguration] {
        return queue.sync {
            configurations
        }
    }

    /// Remove a configuration
    /// - Parameter identifier: Configuration identifier
    public func remove(_ identifier: String) {
        queue.async(flags: .barrier) {
            self.configurations.removeValue(forKey: identifier)
        }
    }

    /// Clear all configurations
    public func clearAll() {
        queue.async(flags: .barrier) {
            self.configurations.removeAll()
        }
    }

    /// Number of stored configurations
    public var count: Int {
        return queue.sync {
            configurations.count
        }
    }
}

/// Event representing a display configuration change
public struct DisplayConfigurationChangeEvent {
    /// Previous configuration (nil if first time)
    public let previousConfiguration: DisplayConfiguration?

    /// New configuration
    public let newConfiguration: DisplayConfiguration

    /// Timestamp of the change
    public let timestamp: Date

    /// Type of change
    public let changeType: ChangeType

    public enum ChangeType {
        case initial        // First configuration detected
        case displayAdded   // Display(s) added
        case displayRemoved // Display(s) removed
        case displayChanged // Display properties changed (resolution, position)
        case unknown        // Unable to determine
    }

    public init(
        previousConfiguration: DisplayConfiguration?,
        newConfiguration: DisplayConfiguration,
        timestamp: Date = Date()
    ) {
        self.previousConfiguration = previousConfiguration
        self.newConfiguration = newConfiguration
        self.timestamp = timestamp

        // Determine change type
        if let previous = previousConfiguration {
            let previousCount = previous.count
            let newCount = newConfiguration.count

            if newCount > previousCount {
                self.changeType = .displayAdded
            } else if newCount < previousCount {
                self.changeType = .displayRemoved
            } else if previous.signature != newConfiguration.signature {
                self.changeType = .displayChanged
            } else {
                self.changeType = .unknown
            }
        } else {
            self.changeType = .initial
        }
    }

    /// Description for debugging
    public var debugDescription: String {
        let prevDesc = previousConfiguration?.debugDescription ?? "none"
        return "DisplayConfigurationChangeEvent(type: \(changeType), from: \(prevDesc), to: \(newConfiguration.debugDescription), timestamp: \(timestamp))"
    }
}

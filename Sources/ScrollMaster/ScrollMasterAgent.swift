import Foundation
import MacToolsCore
import Logging

/// Main agent for ScrollMaster - coordinates all scroll behavior manipulation
public final class ScrollMasterAgent: BaseAgent {
    private let logger = Logger(label: "com.mactools.scrollmaster")

    // Core components
    private let enumerator: DeviceEnumerator
    private let registry: ScrollConfigurationRegistry
    private let configManager: ScrollConfigurationManager
    private var eventHandler: ScrollEventHandler?
    private var smoothScrollEngine: SmoothScrollEngine?

    // Global disable state
    private var globalDisabled: Bool = false
    private let disableQueue = DispatchQueue(label: "com.mactools.scrollmaster.disable", attributes: .concurrent)

    // MARK: - Initialization

    public init(
        enumerator: DeviceEnumerator = DeviceEnumerator(),
        registry: ScrollConfigurationRegistry = ScrollConfigurationRegistry(),
        configManager: ScrollConfigurationManager = ScrollConfigurationManager()
    ) {
        self.enumerator = enumerator
        self.registry = registry
        self.configManager = configManager

        super.init(agentName: "ScrollMaster")
    }

    // MARK: - BaseAgent Implementation

    override public func start() throws {
        logger.info("Starting ScrollMaster agent")

        // Load configuration
        loadConfiguration()

        // Initialize smooth scroll engine
        let smoothParams = configManager.loadSmoothScrollParameters()
        smoothScrollEngine = SmoothScrollEngine(parameters: smoothParams)

        // Set up event handler
        eventHandler = ScrollEventHandler { [weak self] event in
            self?.handleScrollEvent(event)
        }

        try eventHandler?.start()

        logger.info("ScrollMaster agent started successfully")
    }

    override public func stop() {
        logger.info("Stopping ScrollMaster agent")

        eventHandler?.stop()
        eventHandler = nil
        smoothScrollEngine = nil

        logger.info("ScrollMaster agent stopped")
    }

    // MARK: - Configuration Management

    /// Load configuration from persistent storage
    public func loadConfiguration() {
        logger.debug("Loading ScrollMaster configuration")

        // Load device configurations
        let configs = configManager.loadAll()
        for (_, config) in configs {
            registry.setConfiguration(config)
        }

        // Load default transform
        let defaultTransform = configManager.loadDefault()
        registry.defaultConfiguration = defaultTransform

        // Load smooth scroll parameters
        let smoothParams = configManager.loadSmoothScrollParameters()
        smoothScrollEngine?.updateParameters(smoothParams)

        logger.info("Loaded \(configs.count) device configurations")
    }

    /// Reload configuration without restarting
    public func reloadConfiguration() throws {
        logger.info("Reloading ScrollMaster configuration")
        loadConfiguration()
    }

    /// Update device configuration
    public func updateDeviceConfiguration(_ config: DeviceScrollConfiguration) throws {
        try configManager.save(config)
        registry.setConfiguration(config)
        logger.info("Updated configuration for device: \(config.deviceStableID)")
    }

    /// Update default configuration
    public func updateDefaultConfiguration(_ transform: ScrollTransform) throws {
        try configManager.saveDefault(transform)
        registry.defaultConfiguration = transform
        logger.info("Updated default configuration")
    }

    /// Update smooth scroll parameters
    public func updateSmoothScrollParameters(_ parameters: SmoothScrollParameters) throws {
        try configManager.saveSmoothScrollParameters(parameters)
        smoothScrollEngine?.updateParameters(parameters)
        logger.info("Updated smooth scroll parameters")
    }

    // MARK: - Global Disable/Enable

    /// Check if scroll modifications are globally disabled
    public var isGloballyDisabled: Bool {
        disableQueue.sync {
            globalDisabled
        }
    }

    /// Globally disable all scroll modifications (emergency bypass)
    public func disableGlobally() {
        disableQueue.async(flags: .barrier) {
            self.globalDisabled = true
            self.smoothScrollEngine?.reset() // Clear any active animations
        }
        logger.warning("ScrollMaster globally disabled - all modifications bypassed")
    }

    /// Re-enable scroll modifications
    public func enableGlobally() {
        disableQueue.async(flags: .barrier) {
            self.globalDisabled = false
        }
        logger.info("ScrollMaster globally enabled")
    }

    /// Toggle global disable state
    public func toggleGlobalDisable() {
        if isGloballyDisabled {
            enableGlobally()
        } else {
            disableGlobally()
        }
    }

    // MARK: - Event Handling

    private func handleScrollEvent(_ event: ScrollEvent) {
        // Check global disable first
        guard !isGloballyDisabled else {
            // Pass through unmodified
            return
        }

        // Get device ID
        guard let deviceID = event.deviceID else {
            // No device ID - apply default transform
            let transform = registry.defaultConfiguration
            applyTransformToEvent(event, transform: transform)
            return
        }

        // Get transform for device
        let transform = registry.transform(for: deviceID)

        // Apply transform
        applyTransformToEvent(event, transform: transform)
    }

    private func applyTransformToEvent(_ event: ScrollEvent, transform: ScrollTransform) {
        // Apply transform
        let transformedEvent = event.applying(transform)

        // If smooth scroll is enabled, feed to engine
        if transform.smoothScrollEnabled, let engine = smoothScrollEngine {
            engine.addInput(
                vertical: transformedEvent.verticalDelta,
                horizontal: transformedEvent.horizontalDelta
            )

            // Engine will emit smoothed deltas via tick()
            // In a real implementation, we'd set up a display link or timer
            // to call tick() regularly and post the smoothed events
        }

        // In a real implementation, we would post the transformed event
        // back to the system using CGEvent
    }

    // MARK: - Device Enumeration

    /// Get currently connected pointing devices
    public func enumerateDevices() throws -> [DeviceIdentity] {
        return try enumerator.enumeratePointingDevices()
    }

    /// Get configuration for a specific device
    public func getConfiguration(for deviceID: String) -> DeviceScrollConfiguration? {
        return configManager.load(for: deviceID)
    }

    /// Get all configured devices
    public func getAllConfigurations() -> [String: DeviceScrollConfiguration] {
        return configManager.loadAll()
    }

    // MARK: - Status

    /// Get current agent status
    public func getStatus() -> AgentStatus {
        return AgentStatus(
            name: "ScrollMaster",
            isRunning: isRunning,
            isGloballyDisabled: isGloballyDisabled,
            deviceCount: (try? enumerateDevices().count) ?? 0,
            configuredDevices: getAllConfigurations().count,
            smoothScrollEnabled: smoothScrollEngine != nil,
            activeAnimations: smoothScrollEngine?.activeAnimationCount ?? 0
        )
    }

    public struct AgentStatus: Codable {
        public let name: String
        public let isRunning: Bool
        public let isGloballyDisabled: Bool
        public let deviceCount: Int
        public let configuredDevices: Int
        public let smoothScrollEnabled: Bool
        public let activeAnimations: Int
    }
}

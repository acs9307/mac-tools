import Foundation
import Combine
import MacToolsCore

/// View model for ScrollMaster settings UI
@MainActor
public final class ScrollMasterViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public private(set) var devices: [DeviceInfo] = []
    @Published public var defaultTransform: ScrollTransform = .identity
    @Published public var smoothScrollParameters: SmoothScrollParameters = .default
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: String?

    // MARK: - Dependencies

    private let enumerator: DeviceEnumerator
    private let configManager: ScrollConfigurationManager
    private let registry: ScrollConfigurationRegistry

    // MARK: - Initialization

    public init(
        enumerator: DeviceEnumerator = DeviceEnumerator(),
        configManager: ScrollConfigurationManager = ScrollConfigurationManager(),
        registry: ScrollConfigurationRegistry = ScrollConfigurationRegistry()
    ) {
        self.enumerator = enumerator
        self.configManager = configManager
        self.registry = registry

        loadConfiguration()
    }

    // MARK: - Device Info

    public struct DeviceInfo: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let vendorID: Int
        public let productID: Int
        public var configuration: DeviceScrollConfiguration

        public init(
            id: String,
            name: String,
            vendorID: Int,
            productID: Int,
            configuration: DeviceScrollConfiguration
        ) {
            self.id = id
            self.name = name
            self.vendorID = vendorID
            self.productID = productID
            self.configuration = configuration
        }
    }

    // MARK: - Public Interface

    /// Load configuration from persistent storage
    public func loadConfiguration() {
        isLoading = true
        error = nil

        do {
            // Load all configurations
            let configs = configManager.loadAll()

            // Load default transform
            defaultTransform = configManager.loadDefault()

            // Load smooth scroll parameters
            smoothScrollParameters = configManager.loadSmoothScrollParameters()

            // Enumerate devices
            let identities = try enumerator.enumeratePointingDevices()

            // Build device info list
            devices = identities.map { identity in
                let config = configs[identity.stableID] ?? DeviceScrollConfiguration(
                    deviceStableID: identity.stableID
                )

                return DeviceInfo(
                    id: identity.stableID,
                    name: identity.productName ?? "Unknown Device",
                    vendorID: identity.vendorID,
                    productID: identity.productID,
                    configuration: config
                )
            }

            isLoading = false
        } catch {
            self.error = "Failed to load configuration: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Refresh device list (call when devices may have changed)
    public func refreshDevices() {
        loadConfiguration()
    }

    /// Update configuration for a specific device
    public func updateDevice(_ deviceID: String, configuration: DeviceScrollConfiguration) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else {
            error = "Device not found: \(deviceID)"
            return
        }

        devices[index].configuration = configuration

        do {
            try configManager.save(configuration)
            registry.setConfiguration(configuration)
            error = nil
        } catch {
            self.error = "Failed to save configuration: \(error.localizedDescription)"
        }
    }

    /// Toggle invert vertical for a device
    public func toggleInvertVertical(for deviceID: String) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }

        var config = devices[index].configuration
        config.transform.invertVertical.toggle()
        updateDevice(deviceID, configuration: config)
    }

    /// Toggle invert horizontal for a device
    public func toggleInvertHorizontal(for deviceID: String) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }

        var config = devices[index].configuration
        config.transform.invertHorizontal.toggle()
        updateDevice(deviceID, configuration: config)
    }

    /// Toggle smooth scroll for a device
    public func toggleSmoothScroll(for deviceID: String) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }

        var config = devices[index].configuration
        config.transform.smoothScrollEnabled.toggle()
        updateDevice(deviceID, configuration: config)
    }

    /// Set vertical multiplier for a device
    public func setVerticalMultiplier(for deviceID: String, value: Double) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }

        var config = devices[index].configuration
        config.transform.verticalMultiplier = value
        updateDevice(deviceID, configuration: config)
    }

    /// Set horizontal multiplier for a device
    public func setHorizontalMultiplier(for deviceID: String, value: Double) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }

        var config = devices[index].configuration
        config.transform.horizontalMultiplier = value
        updateDevice(deviceID, configuration: config)
    }

    /// Toggle device enabled state
    public func toggleEnabled(for deviceID: String) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }

        var config = devices[index].configuration
        config.enabled.toggle()
        updateDevice(deviceID, configuration: config)
    }

    /// Update default transform
    public func updateDefaultTransform(_ transform: ScrollTransform) {
        defaultTransform = transform
        registry.defaultConfiguration = transform

        do {
            try configManager.saveDefault(transform)
            error = nil
        } catch {
            self.error = "Failed to save default configuration: \(error.localizedDescription)"
        }
    }

    /// Update smooth scroll parameters
    public func updateSmoothScrollParameters(_ parameters: SmoothScrollParameters) {
        smoothScrollParameters = parameters

        do {
            try configManager.saveSmoothScrollParameters(parameters)
            error = nil
        } catch {
            self.error = "Failed to save smooth scroll parameters: \(error.localizedDescription)"
        }
    }

    /// Reset device to defaults
    public func resetDevice(_ deviceID: String) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }

        let config = DeviceScrollConfiguration(deviceStableID: deviceID)
        devices[index].configuration = config

        do {
            try configManager.save(config)
            registry.setConfiguration(config)
            error = nil
        } catch {
            self.error = "Failed to reset device: \(error.localizedDescription)"
        }
    }

    /// Remove device configuration (falls back to default)
    public func removeDevice(_ deviceID: String) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }

        devices.remove(at: index)

        do {
            try configManager.remove(for: deviceID)
            registry.removeConfiguration(for: deviceID)
            error = nil
        } catch {
            self.error = "Failed to remove device: \(error.localizedDescription)"
        }
    }

    /// Clear error
    public func clearError() {
        error = nil
    }
}

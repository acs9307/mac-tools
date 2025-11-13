import Foundation

/// Per-device scroll configuration
public struct DeviceScrollConfiguration: Equatable, Codable {
    /// The device this configuration applies to
    public let deviceStableID: String

    /// Scroll transformation to apply
    public var transform: ScrollTransform

    /// Whether this configuration is enabled
    public var enabled: Bool

    public init(
        deviceStableID: String,
        transform: ScrollTransform = .identity,
        enabled: Bool = true
    ) {
        self.deviceStableID = deviceStableID
        self.transform = transform
        self.enabled = enabled
    }
}

/// Registry for per-device scroll configurations
public final class ScrollConfigurationRegistry {
    private var configurations: [String: DeviceScrollConfiguration] = [:]
    private let queue = DispatchQueue(label: "com.mactools.scrollconfig", attributes: .concurrent)

    /// Default configuration for unknown devices
    public var defaultConfiguration: ScrollTransform = .identity

    public init() {}

    // MARK: - Configuration Management

    /// Set configuration for a specific device
    /// - Parameter config: The device configuration
    public func setConfiguration(_ config: DeviceScrollConfiguration) {
        queue.async(flags: .barrier) {
            self.configurations[config.deviceStableID] = config
        }
    }

    /// Get configuration for a device
    /// - Parameter stableID: Device stable ID
    /// - Returns: Configuration, or nil if not found
    public func configuration(for stableID: String) -> DeviceScrollConfiguration? {
        queue.sync {
            configurations[stableID]
        }
    }

    /// Get transform for a device (returns default if not configured)
    /// - Parameter stableID: Device stable ID
    /// - Returns: Scroll transform to apply
    public func transform(for stableID: String) -> ScrollTransform {
        queue.sync {
            if let config = configurations[stableID], config.enabled {
                return config.transform
            }
            return defaultConfiguration
        }
    }

    /// Remove configuration for a device
    /// - Parameter stableID: Device stable ID
    public func removeConfiguration(for stableID: String) {
        queue.async(flags: .barrier) {
            self.configurations.removeValue(forKey: stableID)
        }
    }

    /// Get all configured devices
    /// - Returns: Array of device configurations
    public func allConfigurations() -> [DeviceScrollConfiguration] {
        queue.sync {
            Array(configurations.values)
        }
    }

    /// Clear all configurations
    public func clearAll() {
        queue.async(flags: .barrier) {
            self.configurations.removeAll()
        }
    }

    /// Number of configured devices
    public var count: Int {
        queue.sync {
            configurations.count
        }
    }
}

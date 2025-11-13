import Foundation
import MacToolsCore

/// Manages persistence of scroll configurations
public final class ScrollConfigurationManager {
    private let configuration = Configuration.shared

    public init() {}

    // MARK: - Loading

    /// Load all device configurations from persistent storage
    /// - Returns: Dictionary mapping device stable IDs to configurations
    public func loadAll() -> [String: DeviceScrollConfiguration] {
        guard let scrollConfig = configuration.get("scroll") as? [String: Any],
              let devices = scrollConfig["devices"] as? [String: Any] else {
            return [:]
        }

        var configs: [String: DeviceScrollConfiguration] = [:]

        for (deviceID, deviceConfigData) in devices {
            if let deviceDict = deviceConfigData as? [String: Any],
               let config = parseDeviceConfiguration(deviceID: deviceID, from: deviceDict) {
                configs[deviceID] = config
            }
        }

        return configs
    }

    /// Load configuration for a specific device
    /// - Parameter deviceID: Device stable ID
    /// - Returns: Configuration, or nil if not found
    public func load(for deviceID: String) -> DeviceScrollConfiguration? {
        let all = loadAll()
        return all[deviceID]
    }

    /// Load default configuration for unknown devices
    /// - Returns: Default scroll transform
    public func loadDefault() -> ScrollTransform {
        guard let scrollConfig = configuration.get("scroll") as? [String: Any],
              let defaultDict = scrollConfig["default"] as? [String: Any] else {
            return .identity
        }

        return parseScrollTransform(from: defaultDict) ?? .identity
    }

    /// Load smooth scroll parameters
    /// - Returns: Smooth scroll parameters, or default if not configured
    public func loadSmoothScrollParameters() -> SmoothScrollParameters {
        guard let scrollConfig = configuration.get("scroll") as? [String: Any],
              let smoothDict = scrollConfig["smoothScroll"] as? [String: Any] else {
            return .default
        }

        return parseSmoothScrollParameters(from: smoothDict) ?? .default
    }

    // MARK: - Saving

    /// Save a device configuration to persistent storage
    /// - Parameter config: Device configuration to save
    /// - Throws: Error if save fails
    public func save(_ config: DeviceScrollConfiguration) throws {
        var scrollConfig = configuration.get("scroll") as? [String: Any] ?? [:]
        var devices = scrollConfig["devices"] as? [String: Any] ?? [:]

        devices[config.deviceStableID] = serializeDeviceConfiguration(config)
        scrollConfig["devices"] = devices

        configuration.set("scroll", value: scrollConfig)
        try configuration.save()
    }

    /// Save all device configurations
    /// - Parameter configs: Dictionary of configurations
    /// - Throws: Error if save fails
    public func saveAll(_ configs: [String: DeviceScrollConfiguration]) throws {
        var scrollConfig = configuration.get("scroll") as? [String: Any] ?? [:]
        var devices: [String: Any] = [:]

        for (deviceID, config) in configs {
            devices[deviceID] = serializeDeviceConfiguration(config)
        }

        scrollConfig["devices"] = devices

        configuration.set("scroll", value: scrollConfig)
        try configuration.save()
    }

    /// Save default configuration
    /// - Parameter transform: Default scroll transform
    /// - Throws: Error if save fails
    public func saveDefault(_ transform: ScrollTransform) throws {
        var scrollConfig = configuration.get("scroll") as? [String: Any] ?? [:]
        scrollConfig["default"] = serializeScrollTransform(transform)

        configuration.set("scroll", value: scrollConfig)
        try configuration.save()
    }

    /// Save smooth scroll parameters
    /// - Parameter parameters: Smooth scroll parameters
    /// - Throws: Error if save fails
    public func saveSmoothScrollParameters(_ parameters: SmoothScrollParameters) throws {
        var scrollConfig = configuration.get("scroll") as? [String: Any] ?? [:]
        scrollConfig["smoothScroll"] = serializeSmoothScrollParameters(parameters)

        configuration.set("scroll", value: scrollConfig)
        try configuration.save()
    }

    /// Remove configuration for a device
    /// - Parameter deviceID: Device stable ID
    /// - Throws: Error if save fails
    public func remove(for deviceID: String) throws {
        var scrollConfig = configuration.get("scroll") as? [String: Any] ?? [:]
        var devices = scrollConfig["devices"] as? [String: Any] ?? [:]

        devices.removeValue(forKey: deviceID)
        scrollConfig["devices"] = devices

        configuration.set("scroll", value: scrollConfig)
        try configuration.save()
    }

    // MARK: - Parsing

    private func parseDeviceConfiguration(
        deviceID: String,
        from dict: [String: Any]
    ) -> DeviceScrollConfiguration? {
        guard let transformDict = dict["transform"] as? [String: Any],
              let transform = parseScrollTransform(from: transformDict) else {
            return nil
        }

        let enabled = dict["enabled"] as? Bool ?? true

        return DeviceScrollConfiguration(
            deviceStableID: deviceID,
            transform: transform,
            enabled: enabled
        )
    }

    private func parseScrollTransform(from dict: [String: Any]) -> ScrollTransform? {
        let invertVertical = dict["invertVertical"] as? Bool ?? false
        let invertHorizontal = dict["invertHorizontal"] as? Bool ?? false
        let verticalMultiplier = dict["verticalMultiplier"] as? Double ?? 1.0
        let horizontalMultiplier = dict["horizontalMultiplier"] as? Double ?? 1.0
        let smoothScrollEnabled = dict["smoothScrollEnabled"] as? Bool ?? false

        return ScrollTransform(
            invertVertical: invertVertical,
            invertHorizontal: invertHorizontal,
            verticalMultiplier: verticalMultiplier,
            horizontalMultiplier: horizontalMultiplier,
            smoothScrollEnabled: smoothScrollEnabled
        )
    }

    private func parseSmoothScrollParameters(from dict: [String: Any]) -> SmoothScrollParameters? {
        let duration = dict["duration"] as? TimeInterval ?? 0.3
        let curveString = dict["curve"] as? String ?? "easeOut"
        let curve = InterpolationCurve(rawValue: curveString) ?? .easeOut
        let distanceMultiplier = dict["distanceMultiplier"] as? Double ?? 1.0
        let minimumDelta = dict["minimumDelta"] as? Double ?? 0.01

        return SmoothScrollParameters(
            duration: duration,
            curve: curve,
            distanceMultiplier: distanceMultiplier,
            minimumDelta: minimumDelta
        )
    }

    // MARK: - Serialization

    private func serializeDeviceConfiguration(_ config: DeviceScrollConfiguration) -> [String: Any] {
        return [
            "transform": serializeScrollTransform(config.transform),
            "enabled": config.enabled
        ]
    }

    private func serializeScrollTransform(_ transform: ScrollTransform) -> [String: Any] {
        return [
            "invertVertical": transform.invertVertical,
            "invertHorizontal": transform.invertHorizontal,
            "verticalMultiplier": transform.verticalMultiplier,
            "horizontalMultiplier": transform.horizontalMultiplier,
            "smoothScrollEnabled": transform.smoothScrollEnabled
        ]
    }

    private func serializeSmoothScrollParameters(_ parameters: SmoothScrollParameters) -> [String: Any] {
        return [
            "duration": parameters.duration,
            "curve": parameters.curve.rawValue,
            "distanceMultiplier": parameters.distanceMultiplier,
            "minimumDelta": parameters.minimumDelta
        ]
    }
}

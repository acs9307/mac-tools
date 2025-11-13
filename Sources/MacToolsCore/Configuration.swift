import Foundation
import Logging

/// Configuration manager for the daemon and agents
public final class Configuration {
    public static let shared = Configuration()

    private var config: [String: Any] = [:]
    private let logger = Logger(label: "com.mactools.config")
    private let configQueue = DispatchQueue(label: "com.mactools.config", attributes: .concurrent)

    /// Default configuration file path
    public static let defaultConfigPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/mactools/config.json")

    private init() {
        loadDefaultConfiguration()
    }

    /// Load configuration from file
    /// - Parameter path: Path to the configuration file
    /// - Throws: Error if the file cannot be read or parsed
    public func load(from path: URL = defaultConfigPath) throws {
        logger.info("Loading configuration from \(path.path)")

        guard FileManager.default.fileExists(atPath: path.path) else {
            logger.warning("Configuration file not found at \(path.path), using defaults")
            return
        }

        let data = try Data(contentsOf: path)
        let json = try JSONSerialization.jsonObject(with: data, options: [])

        guard let dictionary = json as? [String: Any] else {
            throw AgentError.configurationError("Invalid configuration format")
        }

        configQueue.sync(flags: .barrier) {
            config = dictionary
        }

        logger.info("Configuration loaded successfully")
    }

    /// Save configuration to file
    /// - Parameter path: Path to save the configuration file
    /// - Throws: Error if the file cannot be written
    public func save(to path: URL = defaultConfigPath) throws {
        logger.info("Saving configuration to \(path.path)")

        let data = try configQueue.sync {
            try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        }

        // Create directory if it doesn't exist
        let directory = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try data.write(to: path)
        logger.info("Configuration saved successfully")
    }

    /// Get a configuration value
    /// - Parameter key: The configuration key (supports dot notation for nested values)
    /// - Returns: The configuration value, or nil if not found
    public func get(_ key: String) -> Any? {
        configQueue.sync {
            let components = key.split(separator: ".").map(String.init)
            var current: Any? = config

            for component in components {
                guard let dict = current as? [String: Any] else {
                    return nil
                }
                current = dict[component]
            }

            return current
        }
    }

    /// Set a configuration value
    /// - Parameters:
    ///   - key: The configuration key
    ///   - value: The value to set
    public func set(_ key: String, value: Any) {
        configQueue.sync(flags: .barrier) {
            config[key] = value
        }
    }

    /// Get a typed configuration value
    /// - Parameters:
    ///   - key: The configuration key
    ///   - default: Default value if key is not found
    /// - Returns: The configuration value or default
    public func get<T>(_ key: String, default defaultValue: T) -> T {
        guard let value = get(key) as? T else {
            return defaultValue
        }
        return value
    }

    /// Load default configuration
    private func loadDefaultConfiguration() {
        config = [
            "daemon": [
                "logLevel": "info",
                "autoStart": true
            ],
            "keyManipulation": [
                "enabled": true,
                "hotkeys": [:] as [String: Any]
            ],
            "windowManipulation": [
                "enabled": true,
                "animations": true,
                "animationDuration": 0.2
            ]
        ]
    }

    /// Reset configuration to defaults
    public func reset() {
        configQueue.sync(flags: .barrier) {
            loadDefaultConfiguration()
        }
        logger.info("Configuration reset to defaults")
    }

    /// Get all configuration as a dictionary
    /// - Returns: The complete configuration dictionary
    public func all() -> [String: Any] {
        configQueue.sync {
            config
        }
    }
}

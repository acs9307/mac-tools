import Foundation

/// Registry for tracking known pointing devices
public final class DeviceRegistry {
    private var devices: [String: DeviceIdentity] = [:]
    private let queue = DispatchQueue(label: "com.mactools.deviceregistry", attributes: .concurrent)

    public init() {}

    // MARK: - Public Interface

    /// Register a device in the registry
    /// - Parameter device: The device identity to register
    public func register(_ device: DeviceIdentity) {
        queue.async(flags: .barrier) {
            self.devices[device.stableID] = device
        }
    }

    /// Register multiple devices
    /// - Parameter devices: Array of device identities to register
    public func registerAll(_ devices: [DeviceIdentity]) {
        queue.async(flags: .barrier) {
            for device in devices {
                self.devices[device.stableID] = device
            }
        }
    }

    /// Unregister a device by its stable ID
    /// - Parameter stableID: The stable identifier of the device
    public func unregister(stableID: String) {
        queue.async(flags: .barrier) {
            self.devices.removeValue(forKey: stableID)
        }
    }

    /// Get a device by its stable ID
    /// - Parameter stableID: The stable identifier
    /// - Returns: The device identity, or nil if not found
    public func device(withStableID stableID: String) -> DeviceIdentity? {
        queue.sync {
            devices[stableID]
        }
    }

    /// Get all registered devices
    /// - Returns: Array of all registered device identities
    public func allDevices() -> [DeviceIdentity] {
        queue.sync {
            Array(devices.values)
        }
    }

    /// Check if a device is registered
    /// - Parameter stableID: The stable identifier
    /// - Returns: True if the device is registered
    public func isRegistered(stableID: String) -> Bool {
        queue.sync {
            devices[stableID] != nil
        }
    }

    /// Get the count of registered devices
    public var count: Int {
        queue.sync {
            devices.count
        }
    }

    /// Clear all registered devices
    public func clear() {
        queue.async(flags: .barrier) {
            self.devices.removeAll()
        }
    }

    /// Find devices matching specific criteria
    /// - Parameter predicate: Predicate to match devices
    /// - Returns: Array of matching devices
    public func findDevices(matching predicate: (DeviceIdentity) -> Bool) -> [DeviceIdentity] {
        queue.sync {
            devices.values.filter(predicate)
        }
    }

    /// Find device by vendor and product IDs
    /// - Parameters:
    ///   - vendorID: The vendor ID
    ///   - productID: The product ID
    /// - Returns: First matching device, or nil
    public func findDevice(vendorID: Int, productID: Int) -> DeviceIdentity? {
        queue.sync {
            devices.values.first { device in
                device.vendorID == vendorID && device.productID == productID
            }
        }
    }

    /// Update registry with current devices (add new, keep existing)
    /// - Parameter currentDevices: Currently connected devices
    /// - Returns: Tuple of (added, removed) device stable IDs
    public func updateWith(currentDevices: [DeviceIdentity]) -> (added: [String], removed: [String]) {
        queue.sync(flags: .barrier) {
            let currentIDs = Set(currentDevices.map { $0.stableID })
            let registeredIDs = Set(devices.keys)

            let added = currentIDs.subtracting(registeredIDs)
            let removed = registeredIDs.subtracting(currentIDs)

            // Add new devices
            for device in currentDevices where added.contains(device.stableID) {
                devices[device.stableID] = device
            }

            // Remove disconnected devices
            for id in removed {
                devices.removeValue(forKey: id)
            }

            return (Array(added), Array(removed))
        }
    }
}

import Foundation
import IOKit
import IOKit.hid

/// Represents a unique identity for a pointing device
public struct DeviceIdentity: Hashable, Codable {
    /// Vendor ID (assigned by USB Implementers Forum)
    public let vendorID: Int

    /// Product ID (assigned by vendor)
    public let productID: Int

    /// Serial number (if available)
    public let serialNumber: String?

    /// Location ID (physical USB port/location)
    public let locationID: Int?

    /// Product name (human-readable)
    public let productName: String?

    /// Transport type (USB, Bluetooth, etc.)
    public let transport: String?

    public init(
        vendorID: Int,
        productID: Int,
        serialNumber: String? = nil,
        locationID: Int? = nil,
        productName: String? = nil,
        transport: String? = nil
    ) {
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.locationID = locationID
        self.productName = productName
        self.transport = transport
    }

    /// Generate a stable identifier string for this device
    public var stableID: String {
        var components = ["\(vendorID)", "\(productID)"]

        if let serial = serialNumber {
            components.append(serial)
        }

        if let location = locationID {
            components.append("\(location)")
        }

        return components.joined(separator: "-")
    }

    /// Human-readable description of the device
    public var description: String {
        var parts: [String] = []

        if let name = productName {
            parts.append(name)
        }

        parts.append("VID:\(vendorID) PID:\(productID)")

        if let serial = serialNumber {
            parts.append("SN:\(serial)")
        }

        if let transport = transport {
            parts.append("(\(transport))")
        }

        return parts.joined(separator: " ")
    }
}

/// Errors that can occur during device enumeration
public enum DeviceEnumerationError: Error, LocalizedError {
    case hidManagerCreationFailed
    case deviceMatchingFailed
    case propertyRetrievalFailed(String)

    public var errorDescription: String? {
        switch self {
        case .hidManagerCreationFailed:
            return "Failed to create IOHIDManager"
        case .deviceMatchingFailed:
            return "Failed to match HID devices"
        case .propertyRetrievalFailed(let property):
            return "Failed to retrieve device property: \(property)"
        }
    }
}

/// Enumerates and identifies HID pointing devices
public final class DeviceEnumerator {
    private var hidManager: IOHIDManager?

    public init() {}

    deinit {
        close()
    }

    // MARK: - Public Interface

    /// Enumerate all connected pointing devices
    /// - Returns: Array of device identities
    /// - Throws: DeviceEnumerationError if enumeration fails
    public func enumeratePointingDevices() throws -> [DeviceIdentity] {
        let manager = try createHIDManager()

        // Set matching criteria for pointing devices
        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Mouse
        ]

        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)

        // Open the manager
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw DeviceEnumerationError.deviceMatchingFailed
        }

        // Get the set of devices
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return []
        }

        let devices = deviceSet.compactMap { device in
            try? extractDeviceIdentity(from: device)
        }

        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        return devices
    }

    /// Close the HID manager
    public func close() {
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }
    }

    // MARK: - Private Methods

    private func createHIDManager() throws -> IOHIDManager {
        guard let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone)) else {
            throw DeviceEnumerationError.hidManagerCreationFailed
        }

        hidManager = manager
        return manager
    }

    private func extractDeviceIdentity(from device: IOHIDDevice) throws -> DeviceIdentity {
        let vendorID = getIntProperty(from: device, key: kIOHIDVendorIDKey as String) ?? 0
        let productID = getIntProperty(from: device, key: kIOHIDProductIDKey as String) ?? 0
        let serialNumber = getStringProperty(from: device, key: kIOHIDSerialNumberKey as String)
        let locationID = getIntProperty(from: device, key: kIOHIDLocationIDKey as String)
        let productName = getStringProperty(from: device, key: kIOHIDProductKey as String)
        let transport = getStringProperty(from: device, key: kIOHIDTransportKey as String)

        return DeviceIdentity(
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber,
            locationID: locationID,
            productName: productName,
            transport: transport
        )
    }

    private func getIntProperty(from device: IOHIDDevice, key: String) -> Int? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }

        return (value as? NSNumber)?.intValue
    }

    private func getStringProperty(from device: IOHIDDevice, key: String) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }

        return value as? String
    }
}

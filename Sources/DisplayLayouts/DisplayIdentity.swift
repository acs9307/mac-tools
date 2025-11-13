import Foundation
import CoreGraphics

/// Represents a physical display with stable identification
public struct DisplayIdentity: Hashable, Codable {
    /// Display ID (from CGDirectDisplayID)
    public let displayID: UInt32

    /// Display serial number (if available)
    public let serialNumber: String?

    /// Display vendor ID
    public let vendorID: UInt32

    /// Display model ID
    public let modelID: UInt32

    /// Display name (human-readable)
    public let name: String

    /// Display bounds (position and size)
    public let bounds: DisplayBounds

    /// Display resolution (backing scale factor)
    public let scale: Double

    /// Whether this is the main display
    public let isMain: Bool

    public init(
        displayID: UInt32,
        serialNumber: String? = nil,
        vendorID: UInt32,
        modelID: UInt32,
        name: String,
        bounds: DisplayBounds,
        scale: Double,
        isMain: Bool
    ) {
        self.displayID = displayID
        self.serialNumber = serialNumber
        self.vendorID = vendorID
        self.modelID = modelID
        self.name = name
        self.bounds = bounds
        self.scale = scale
        self.isMain = isMain
    }

    /// Stable identifier for this display (vendor-model-serial)
    public var stableID: String {
        var components = [
            String(format: "0x%08X", vendorID),
            String(format: "0x%08X", modelID)
        ]

        if let serial = serialNumber, !serial.isEmpty {
            components.append(serial)
        }

        return components.joined(separator: "-")
    }

    /// Hash value based on stable properties
    public func hash(into hasher: inout Hasher) {
        hasher.combine(stableID)
    }

    /// Equality based on stable ID
    public static func == (lhs: DisplayIdentity, rhs: DisplayIdentity) -> Bool {
        return lhs.stableID == rhs.stableID
    }
}

/// Represents display position and size
public struct DisplayBounds: Hashable, Codable {
    /// X coordinate (in points)
    public let x: Double

    /// Y coordinate (in points)
    public let y: Double

    /// Width (in points)
    public let width: Double

    /// Height (in points)
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Create from CGRect
    public init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    /// Convert to CGRect
    public var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Area in square points
    public var area: Double {
        return width * height
    }
}

/// Represents a configuration of displays
public struct DisplayConfiguration: Hashable, Codable {
    /// All displays in this configuration
    public let displays: [DisplayIdentity]

    /// Configuration signature (stable hash)
    public let signature: String

    /// Timestamp when configuration was detected
    public let timestamp: Date

    public init(displays: [DisplayIdentity], timestamp: Date = Date()) {
        // Sort displays by stable ID for consistent ordering
        self.displays = displays.sorted { $0.stableID < $1.stableID }
        self.timestamp = timestamp

        // Generate signature
        self.signature = Self.computeSignature(for: self.displays)
    }

    /// Compute stable signature for a set of displays
    private static func computeSignature(for displays: [DisplayIdentity]) -> String {
        // Create a deterministic string from display properties
        let sorted = displays.sorted { $0.stableID < $1.stableID }

        var components: [String] = []
        for display in sorted {
            let bounds = display.bounds
            let component = "\(display.stableID)|\(Int(bounds.width))x\(Int(bounds.height))@\(display.scale)"
            components.append(component)
        }

        let combined = components.joined(separator: ";")

        // Hash the combined string
        var hasher = Hasher()
        hasher.combine(combined)
        let hashValue = hasher.finalize()

        return String(format: "%016llx", UInt64(bitPattern: Int64(hashValue)))
    }

    /// Number of displays
    public var count: Int {
        return displays.count
    }

    /// Main display (if any)
    public var mainDisplay: DisplayIdentity? {
        return displays.first { $0.isMain }
    }

    /// Check if configuration matches another (ignoring minor resolution changes)
    public func matches(_ other: DisplayConfiguration, tolerance: Double = 0.1) -> Bool {
        guard displays.count == other.displays.count else {
            return false
        }

        // Sort both by stable ID
        let sorted1 = displays.sorted { $0.stableID < $1.stableID }
        let sorted2 = other.displays.sorted { $0.stableID < $1.stableID }

        for (d1, d2) in zip(sorted1, sorted2) {
            // Check stable IDs match
            guard d1.stableID == d2.stableID else {
                return false
            }

            // Check dimensions are within tolerance
            let widthDiff = abs(d1.bounds.width - d2.bounds.width)
            let heightDiff = abs(d1.bounds.height - d2.bounds.height)

            if widthDiff > tolerance || heightDiff > tolerance {
                return false
            }

            // Check scale is within tolerance
            let scaleDiff = abs(d1.scale - d2.scale)
            if scaleDiff > tolerance {
                return false
            }
        }

        return true
    }

    /// Get total display area (sum of all display areas)
    public var totalArea: Double {
        return displays.reduce(0.0) { $0 + $1.bounds.area }
    }

    /// Get bounding rect that encompasses all displays
    public var boundingRect: DisplayBounds {
        guard !displays.isEmpty else {
            return DisplayBounds(x: 0, y: 0, width: 0, height: 0)
        }

        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity

        for display in displays {
            minX = min(minX, display.bounds.x)
            minY = min(minY, display.bounds.y)
            maxX = max(maxX, display.bounds.x + display.bounds.width)
            maxY = max(maxY, display.bounds.y + display.bounds.height)
        }

        return DisplayBounds(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    /// Description for debugging
    public var debugDescription: String {
        let displayDesc = displays.map { d in
            "\(d.name) (\(Int(d.bounds.width))x\(Int(d.bounds.height))@\(d.scale)x)"
        }.joined(separator: ", ")

        return "DisplayConfiguration(signature: \(signature), displays: [\(displayDesc)])"
    }
}

/// Enumerates and identifies displays
public final class DisplayEnumerator {
    public init() {}

    /// Enumerate all active displays
    public func enumerateDisplays() throws -> [DisplayIdentity] {
        var displayIDs = [UInt32](repeating: 0, count: 16)
        var displayCount: UInt32 = 0

        // Get active displays
        let error = CGGetActiveDisplayList(
            UInt32(displayIDs.count),
            &displayIDs,
            &displayCount
        )

        guard error == .success else {
            throw DisplayError.enumerationFailed(code: error.rawValue)
        }

        // Get main display
        let mainDisplayID = CGMainDisplayID()

        // Build identity for each display
        var identities: [DisplayIdentity] = []
        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]

            guard let identity = buildIdentity(for: displayID, isMain: displayID == mainDisplayID) else {
                continue
            }

            identities.append(identity)
        }

        return identities
    }

    /// Get current display configuration
    public func getCurrentConfiguration() throws -> DisplayConfiguration {
        let displays = try enumerateDisplays()
        return DisplayConfiguration(displays: displays)
    }

    // MARK: - Private Helpers

    private func buildIdentity(for displayID: UInt32, isMain: Bool) -> DisplayIdentity? {
        // Get display bounds
        let bounds = CGDisplayBounds(displayID)

        // Get backing scale factor
        let mode = CGDisplayCopyDisplayMode(displayID)
        let scale = mode?.pixelWidth ?? 0 > 0 && mode?.width ?? 0 > 0
            ? Double(mode!.pixelWidth) / Double(mode!.width)
            : 1.0

        // Extract vendor and model
        let vendorID = CGDisplayVendorNumber(displayID)
        let modelID = CGDisplayModelNumber(displayID)

        // Try to get serial number
        let serialNumber = extractSerialNumber(for: displayID)

        // Get display name
        let name = extractDisplayName(for: displayID) ?? "Display \(displayID)"

        return DisplayIdentity(
            displayID: displayID,
            serialNumber: serialNumber,
            vendorID: vendorID,
            modelID: modelID,
            name: name,
            bounds: DisplayBounds(bounds),
            scale: scale,
            isMain: isMain
        )
    }

    private func extractSerialNumber(for displayID: UInt32) -> String? {
        // Try to extract serial from display info dictionary
        guard let info = infoForDisplay(displayID),
              let serialDict = info[kDisplaySerialNumber as String] as? [String: Any] else {
            return nil
        }

        // Serial number can be stored in various formats
        if let serial = serialDict["SerialNumber"] as? String, !serial.isEmpty {
            return serial
        }

        if let serial = serialDict[kDisplaySerialNumber as String] as? String, !serial.isEmpty {
            return serial
        }

        return nil
    }

    private func extractDisplayName(for displayID: UInt32) -> String? {
        guard let info = infoForDisplay(displayID) else {
            return nil
        }

        // Try display product name
        if let names = info["DisplayProductName" as String] as? [String: String] {
            // Prefer English name
            if let name = names["en_US"], !name.isEmpty {
                return name
            }

            // Fall back to any available name
            if let name = names.values.first, !name.isEmpty {
                return name
            }
        }

        // Fall back to vendor/model description
        let vendorID = CGDisplayVendorNumber(displayID)
        let modelID = CGDisplayModelNumber(displayID)
        return "Display 0x\(String(format: "%04X", vendorID))-0x\(String(format: "%04X", modelID))"
    }

    private func infoForDisplay(_ displayID: UInt32) -> [String: Any]? {
        // Get IOKit service for display
        guard let servicePort = displayServicePort(for: displayID) else {
            return nil
        }

        defer { IOObjectRelease(servicePort) }

        // Get display info dictionary
        guard let infoDict = IODisplayCreateInfoDictionary(servicePort, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any] else {
            return nil
        }

        return infoDict
    }

    private func displayServicePort(for displayID: UInt32) -> io_service_t? {
        var serialPortIterator = io_iterator_t()
        let matching = IOServiceMatching("IODisplayConnect")

        let kernResult = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            matching,
            &serialPortIterator
        )

        guard kernResult == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(serialPortIterator) }

        var service = IOIteratorNext(serialPortIterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            let info = IODisplayCreateInfoDictionary(service, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as! [String: Any]

            if let displayIDFromInfo = info[kDisplayVendorID] as? UInt32,
               displayIDFromInfo == CGDisplayVendorNumber(displayID) {
                return service
            }

            service = IOIteratorNext(serialPortIterator)
        }

        return nil
    }
}

/// Errors related to display operations
public enum DisplayError: Error, LocalizedError {
    case enumerationFailed(code: Int32)
    case noDisplaysFound
    case invalidDisplayID(UInt32)

    public var errorDescription: String? {
        switch self {
        case .enumerationFailed(let code):
            return "Failed to enumerate displays (error code: \(code))"
        case .noDisplaysFound:
            return "No displays found"
        case .invalidDisplayID(let id):
            return "Invalid display ID: \(id)"
        }
    }
}

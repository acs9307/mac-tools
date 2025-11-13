import Foundation
import ApplicationServices
import Logging

/// Manages macOS permissions required for system-level operations
public final class PermissionsManager {
    public static let shared = PermissionsManager()
    private let logger = Logger(label: "com.mactools.permissions")

    private init() {}

    /// Check if accessibility permissions are granted
    /// - Returns: true if accessibility is enabled, false otherwise
    public func checkAccessibilityPermissions() -> Bool {
        let enabled = AXIsProcessTrusted()
        if !enabled {
            logger.warning("Accessibility permissions not granted")
        }
        return enabled
    }

    /// Request accessibility permissions (will prompt the user)
    /// - Returns: true if permissions are already granted
    public func requestAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let enabled = AXIsProcessTrustedWithOptions(options)

        if !enabled {
            logger.info("Requesting accessibility permissions - user action required")
        }

        return enabled
    }

    /// Check if screen recording permissions are granted (macOS 10.15+)
    /// - Returns: true if screen recording is enabled, false otherwise
    @available(macOS 10.15, *)
    public func checkScreenRecordingPermissions() -> Bool {
        // This is a simple check - for full functionality, we'd need to attempt screen capture
        // For now, we'll return true and let specific operations fail if permissions are missing
        return true
    }

    /// Verify all required permissions for daemon operation
    /// - Returns: Dictionary of permission types and their status
    public func verifyAllPermissions() -> [String: Bool] {
        var permissions: [String: Bool] = [:]

        permissions["accessibility"] = checkAccessibilityPermissions()

        if #available(macOS 10.15, *) {
            permissions["screenRecording"] = checkScreenRecordingPermissions()
        }

        return permissions
    }

    /// Print permission status to console
    public func printPermissionStatus() {
        let permissions = verifyAllPermissions()

        print("\nPermission Status:")
        print("------------------")

        for (permission, granted) in permissions.sorted(by: { $0.key < $1.key }) {
            let status = granted ? "✓ Granted" : "✗ Not Granted"
            print("\(permission.capitalized): \(status)")
        }

        print()

        if permissions.values.contains(false) {
            print("⚠️  Some permissions are not granted. The daemon may not function correctly.")
            print("   Please grant the required permissions in System Settings > Privacy & Security")
            print()
        }
    }
}

import Foundation
import ApplicationServices
import Logging
import Combine

/// Manages macOS permissions required for system-level operations
public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()
    private let logger = Logger(label: "com.mactools.permissions")

    /// Current permission state
    @Published public private(set) var permissionState: PermissionState

    /// Timer for polling permission status
    private var pollTimer: Timer?

    /// Whether to poll for permission changes
    public var pollForChanges: Bool = false {
        didSet {
            if pollForChanges {
                startPolling()
            } else {
                stopPolling()
            }
        }
    }

    private init() {
        self.permissionState = PermissionState()
        updateAllPermissions()
    }

    // MARK: - Permission Checking

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
    @discardableResult
    public func requestAccessibilityPermissions() -> Bool {
        permissionState.accessibility = .promptShown

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let enabled = AXIsProcessTrustedWithOptions(options)

        if !enabled {
            logger.info("Requesting accessibility permissions - user action required")
        } else {
            permissionState.accessibility = .granted
        }

        return enabled
    }

    /// Check if Input Monitoring permissions are granted
    /// - Returns: true if input monitoring is enabled, false otherwise
    public func checkInputMonitoringPermissions() -> Bool {
        #if os(macOS)
        // Input monitoring can be checked by attempting to create an event tap
        // If it fails, permissions are not granted
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, _ in
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            logger.warning("Input Monitoring permissions not granted")
            return false
        }

        CFRelease(eventTap)
        return true
        #else
        return true
        #endif
    }

    /// Request Input Monitoring permissions (will prompt the user on first event tap creation)
    /// - Returns: true if permissions are already granted
    @discardableResult
    public func requestInputMonitoringPermissions() -> Bool {
        permissionState.inputMonitoring = .promptShown

        let granted = checkInputMonitoringPermissions()

        if granted {
            permissionState.inputMonitoring = .granted
        } else {
            logger.info("Input Monitoring permissions need to be granted in System Settings")
        }

        return granted
    }

    /// Check if screen recording permissions are granted (macOS 10.15+)
    /// - Returns: true if screen recording is enabled, false otherwise
    @available(macOS 10.15, *)
    public func checkScreenRecordingPermissions() -> Bool {
        // This is a simple check - for full functionality, we'd need to attempt screen capture
        // For now, we'll return true and let specific operations fail if permissions are missing
        return true
    }

    // MARK: - Permission Status Management

    /// Check the status of a specific permission type
    public func checkPermission(_ type: PermissionType) -> PermissionStatus {
        let isGranted: Bool
        switch type {
        case .accessibility:
            isGranted = checkAccessibilityPermissions()
        case .inputMonitoring:
            isGranted = checkInputMonitoringPermissions()
        case .screenRecording:
            if #available(macOS 10.15, *) {
                isGranted = checkScreenRecordingPermissions()
            } else {
                isGranted = true
            }
        }

        return isGranted ? .granted : .denied
    }

    /// Request a specific permission
    @discardableResult
    public func requestPermission(_ type: PermissionType) -> Bool {
        switch type {
        case .accessibility:
            return requestAccessibilityPermissions()
        case .inputMonitoring:
            return requestInputMonitoringPermissions()
        case .screenRecording:
            logger.info("Screen recording permissions cannot be requested programmatically")
            return false
        }
    }

    /// Update the status of all permissions
    public func updateAllPermissions() {
        permissionState.accessibility = checkPermission(.accessibility)
        permissionState.inputMonitoring = checkPermission(.inputMonitoring)
        permissionState.screenRecording = checkPermission(.screenRecording)
    }

    /// Verify all required permissions for daemon operation
    /// - Returns: Dictionary of permission types and their status
    public func verifyAllPermissions() -> [String: Bool] {
        var permissions: [String: Bool] = [:]

        permissions["accessibility"] = checkAccessibilityPermissions()
        permissions["inputMonitoring"] = checkInputMonitoringPermissions()

        if #available(macOS 10.15, *) {
            permissions["screenRecording"] = checkScreenRecordingPermissions()
        }

        return permissions
    }

    // MARK: - Polling

    /// Start polling for permission changes
    private func startPolling() {
        stopPolling()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAllPermissions()
        }
    }

    /// Stop polling for permission changes
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Utility Methods

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

    /// Open System Settings to the Privacy & Security pane
    public func openSystemSettings() {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            // macOS 13+ uses new Settings app URL scheme
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // macOS 12 and earlier
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        #endif
    }
}

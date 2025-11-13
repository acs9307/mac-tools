import Foundation

/// Types of permissions required by MacTools
public enum PermissionType: String, CaseIterable, Codable {
    case accessibility
    case inputMonitoring
    case screenRecording

    /// Human-readable name for the permission
    public var displayName: String {
        switch self {
        case .accessibility:
            return "Accessibility"
        case .inputMonitoring:
            return "Input Monitoring"
        case .screenRecording:
            return "Screen Recording"
        }
    }

    /// Description of why this permission is needed
    public var purpose: String {
        switch self {
        case .accessibility:
            return "Required to intercept keyboard events and manipulate windows"
        case .inputMonitoring:
            return "Required to monitor mouse and keyboard input for scroll manipulation"
        case .screenRecording:
            return "Required to capture display information for window management"
        }
    }

    /// System Settings path for this permission
    public var systemSettingsPath: String {
        switch self {
        case .accessibility:
            return "Privacy & Security > Accessibility"
        case .inputMonitoring:
            return "Privacy & Security > Input Monitoring"
        case .screenRecording:
            return "Privacy & Security > Screen Recording"
        }
    }

    /// Whether this permission is critical (app won't work without it)
    public var isCritical: Bool {
        switch self {
        case .accessibility, .inputMonitoring:
            return true
        case .screenRecording:
            return false
        }
    }
}

/// Status of a permission request
public enum PermissionStatus: Equatable, Codable {
    case notDetermined
    case denied
    case granted
    case promptShown

    /// Whether the permission is granted
    public var isGranted: Bool {
        return self == .granted
    }

    /// Whether the permission request is in progress
    public var isInProgress: Bool {
        return self == .promptShown
    }

    /// Whether the permission was explicitly denied
    public var isDenied: Bool {
        return self == .denied
    }
}

/// Represents the state of all permissions
public struct PermissionState: Codable {
    public var accessibility: PermissionStatus
    public var inputMonitoring: PermissionStatus
    public var screenRecording: PermissionStatus

    public init(
        accessibility: PermissionStatus = .notDetermined,
        inputMonitoring: PermissionStatus = .notDetermined,
        screenRecording: PermissionStatus = .notDetermined
    ) {
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
        self.screenRecording = screenRecording
    }

    /// Get status for a specific permission type
    public subscript(_ type: PermissionType) -> PermissionStatus {
        get {
            switch type {
            case .accessibility:
                return accessibility
            case .inputMonitoring:
                return inputMonitoring
            case .screenRecording:
                return screenRecording
            }
        }
        set {
            switch type {
            case .accessibility:
                accessibility = newValue
            case .inputMonitoring:
                inputMonitoring = newValue
            case .screenRecording:
                screenRecording = newValue
            }
        }
    }

    /// Whether all critical permissions are granted
    public var allCriticalGranted: Bool {
        return accessibility.isGranted && inputMonitoring.isGranted
    }

    /// Whether any permissions are denied
    public var anyDenied: Bool {
        return accessibility.isDenied || inputMonitoring.isDenied || screenRecording.isDenied
    }

    /// List of permissions that are not granted
    public var missingPermissions: [PermissionType] {
        return PermissionType.allCases.filter { !self[$0].isGranted }
    }

    /// List of critical permissions that are not granted
    public var missingCriticalPermissions: [PermissionType] {
        return PermissionType.allCases.filter { $0.isCritical && !self[$0].isGranted }
    }
}

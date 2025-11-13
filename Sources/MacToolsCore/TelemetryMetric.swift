import Foundation

/// Types of metrics tracked by the telemetry system
public enum MetricType: String, CaseIterable, Codable {
    // Caps Lock metrics
    case capsLockEnabled = "capslock.enabled"
    case capsLockDisabled = "capslock.disabled"
    case capsLockQuickTap = "capslock.quick_tap"
    case capsLockLongPress = "capslock.long_press"
    case capsLockConfigChanged = "capslock.config_changed"

    // Scroll Master metrics
    case scrollMasterEnabled = "scroll.enabled"
    case scrollMasterDisabled = "scroll.disabled"
    case scrollConfigChanged = "scroll.config_changed"
    case scrollDeviceConfigured = "scroll.device_configured"
    case scrollSmoothingEnabled = "scroll.smoothing_enabled"

    // Display Layouts metrics
    case layoutPresetCreated = "layout.preset_created"
    case layoutPresetApplied = "layout.preset_applied"
    case layoutPresetDeleted = "layout.preset_deleted"
    case layoutAutoApplyEnabled = "layout.auto_apply_enabled"
    case layoutAutoApplyDisabled = "layout.auto_apply_disabled"
    case layoutUndo = "layout.undo"
    case layoutRedo = "layout.redo"

    // General metrics
    case appLaunched = "app.launched"
    case appTerminated = "app.terminated"
    case permissionGranted = "permission.granted"
    case permissionDenied = "permission.denied"

    /// Category for organizing metrics
    public var category: MetricCategory {
        if rawValue.hasPrefix("capslock") {
            return .capsLock
        } else if rawValue.hasPrefix("scroll") {
            return .scroll
        } else if rawValue.hasPrefix("layout") {
            return .displayLayouts
        } else if rawValue.hasPrefix("permission") {
            return .permissions
        } else {
            return .general
        }
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .capsLockEnabled:
            return "Caps Lock Enabled"
        case .capsLockDisabled:
            return "Caps Lock Disabled"
        case .capsLockQuickTap:
            return "Caps Lock Quick Tap"
        case .capsLockLongPress:
            return "Caps Lock Long Press"
        case .capsLockConfigChanged:
            return "Caps Lock Config Changed"
        case .scrollMasterEnabled:
            return "Scroll Master Enabled"
        case .scrollMasterDisabled:
            return "Scroll Master Disabled"
        case .scrollConfigChanged:
            return "Scroll Config Changed"
        case .scrollDeviceConfigured:
            return "Scroll Device Configured"
        case .scrollSmoothingEnabled:
            return "Scroll Smoothing Enabled"
        case .layoutPresetCreated:
            return "Layout Preset Created"
        case .layoutPresetApplied:
            return "Layout Preset Applied"
        case .layoutPresetDeleted:
            return "Layout Preset Deleted"
        case .layoutAutoApplyEnabled:
            return "Layout Auto-Apply Enabled"
        case .layoutAutoApplyDisabled:
            return "Layout Auto-Apply Disabled"
        case .layoutUndo:
            return "Layout Undo"
        case .layoutRedo:
            return "Layout Redo"
        case .appLaunched:
            return "App Launched"
        case .appTerminated:
            return "App Terminated"
        case .permissionGranted:
            return "Permission Granted"
        case .permissionDenied:
            return "Permission Denied"
        }
    }
}

/// Categories for grouping metrics
public enum MetricCategory: String, CaseIterable, Codable {
    case capsLock = "capslock"
    case scroll = "scroll"
    case displayLayouts = "layouts"
    case permissions = "permissions"
    case general = "general"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .capsLock:
            return "Caps Lock"
        case .scroll:
            return "Scroll Master"
        case .displayLayouts:
            return "Display Layouts"
        case .permissions:
            return "Permissions"
        case .general:
            return "General"
        }
    }
}

/// Represents a single metric event
public struct MetricEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let type: MetricType
    public let metadata: [String: String]?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: MetricType,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.metadata = metadata
    }
}

/// Aggregated metrics for a specific type
public struct MetricAggregate: Codable {
    public let type: MetricType
    public var count: Int
    public var firstOccurrence: Date?
    public var lastOccurrence: Date?

    public init(
        type: MetricType,
        count: Int = 0,
        firstOccurrence: Date? = nil,
        lastOccurrence: Date? = nil
    ) {
        self.type = type
        self.count = count
        self.firstOccurrence = firstOccurrence
        self.lastOccurrence = lastOccurrence
    }

    /// Update aggregate with a new event
    public mutating func addEvent(at timestamp: Date) {
        count += 1

        if firstOccurrence == nil || timestamp < firstOccurrence! {
            firstOccurrence = timestamp
        }

        if lastOccurrence == nil || timestamp > lastOccurrence! {
            lastOccurrence = timestamp
        }
    }
}

/// Overall telemetry statistics
public struct TelemetryStatistics: Codable {
    public var totalEvents: Int
    public var eventsByCategory: [MetricCategory: Int]
    public var eventsByType: [MetricType: Int]
    public var firstEventDate: Date?
    public var lastEventDate: Date?

    public init(
        totalEvents: Int = 0,
        eventsByCategory: [MetricCategory: Int] = [:],
        eventsByType: [MetricType: Int] = [:],
        firstEventDate: Date? = nil,
        lastEventDate: Date? = nil
    ) {
        self.totalEvents = totalEvents
        self.eventsByCategory = eventsByCategory
        self.eventsByType = eventsByType
        self.firstEventDate = firstEventDate
        self.lastEventDate = lastEventDate
    }
}

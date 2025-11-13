import Foundation
import CoreGraphics

/// Represents a window's layout (position and size)
public struct WindowFrame: Hashable, Codable {
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

    /// Center point of the frame
    public var center: CGPoint {
        return CGPoint(x: x + width / 2, y: y + height / 2)
    }

    /// Check if frame contains a point
    public func contains(_ point: CGPoint) -> Bool {
        return cgRect.contains(point)
    }
}

/// Identifies an application
public struct ApplicationIdentifier: Hashable, Codable {
    /// Bundle identifier (e.g., "com.apple.Safari")
    public let bundleIdentifier: String

    /// Application name (e.g., "Safari")
    public let name: String

    public init(bundleIdentifier: String, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }
}

/// Window role types
public enum WindowRole: String, Codable {
    case standard = "AXStandardWindow"
    case dialog = "AXDialog"
    case sheet = "AXSheet"
    case unknown = "AXUnknown"
}

/// Identifies a window within an application
public struct WindowIdentifier: Hashable, Codable {
    /// Application identifier
    public let application: ApplicationIdentifier

    /// Window title
    public let title: String

    /// Window role
    public let role: WindowRole

    /// Window index within application (for untitled windows)
    public let index: Int?

    public init(
        application: ApplicationIdentifier,
        title: String,
        role: WindowRole = .standard,
        index: Int? = nil
    ) {
        self.application = application
        self.title = title
        self.role = role
        self.index = index
    }

    /// Stable identifier string
    public var stableID: String {
        var components = [application.bundleIdentifier, title]
        if let idx = index {
            components.append(String(idx))
        }
        return components.joined(separator: "|")
    }
}

/// Represents a window in the system
public struct WindowInfo: Hashable {
    /// Window identifier
    public let identifier: WindowIdentifier

    /// Current frame
    public let frame: WindowFrame

    /// Process ID of owning application
    public let processID: pid_t

    /// Whether window is minimized
    public let isMinimized: Bool

    /// Whether window is hidden
    public let isHidden: Bool

    public init(
        identifier: WindowIdentifier,
        frame: WindowFrame,
        processID: pid_t,
        isMinimized: Bool = false,
        isHidden: Bool = false
    ) {
        self.identifier = identifier
        self.frame = frame
        self.processID = processID
        self.isMinimized = isMinimized
        self.isHidden = isHidden
    }
}

/// Layout specification for a window
public struct WindowLayoutSpec: Codable, Hashable {
    /// Window identifier
    public let windowID: WindowIdentifier

    /// Target frame
    public let targetFrame: WindowFrame

    /// Display to place window on (optional - can use frame coords directly)
    public let displayID: String?

    /// Whether to restore from minimized state
    public let restoreIfMinimized: Bool

    /// Whether to unhide if hidden
    public let unhideIfHidden: Bool

    public init(
        windowID: WindowIdentifier,
        targetFrame: WindowFrame,
        displayID: String? = nil,
        restoreIfMinimized: Bool = true,
        unhideIfHidden: Bool = true
    ) {
        self.windowID = windowID
        self.targetFrame = targetFrame
        self.displayID = displayID
        self.restoreIfMinimized = restoreIfMinimized
        self.unhideIfHidden = unhideIfHidden
    }
}

/// Collection of window layouts for a display configuration
public struct WindowLayoutPreset: Codable {
    /// Preset name
    public let name: String

    /// Display configuration signature this preset is for
    public let displayConfigSignature: String

    /// Window layout specifications
    public let layouts: [WindowLayoutSpec]

    /// Creation timestamp
    public let createdAt: Date

    /// Last modified timestamp
    public var modifiedAt: Date

    public init(
        name: String,
        displayConfigSignature: String,
        layouts: [WindowLayoutSpec],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.name = name
        self.displayConfigSignature = displayConfigSignature
        self.layouts = layouts
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Number of windows in this preset
    public var windowCount: Int {
        return layouts.count
    }

    /// Get layout for specific window
    public func layout(for windowID: WindowIdentifier) -> WindowLayoutSpec? {
        return layouts.first { $0.windowID == windowID }
    }
}

/// Result of applying a window layout
public struct WindowLayoutResult {
    /// Window that was processed
    public let windowID: WindowIdentifier

    /// Whether the layout was applied successfully
    public let success: Bool

    /// Error if failed
    public let error: Error?

    /// Previous frame (before applying layout)
    public let previousFrame: WindowFrame?

    /// New frame (after applying layout)
    public let newFrame: WindowFrame?

    public init(
        windowID: WindowIdentifier,
        success: Bool,
        error: Error? = nil,
        previousFrame: WindowFrame? = nil,
        newFrame: WindowFrame? = nil
    ) {
        self.windowID = windowID
        self.success = success
        self.error = error
        self.previousFrame = previousFrame
        self.newFrame = newFrame
    }
}

/// Batch result of applying multiple window layouts
public struct WindowLayoutBatchResult {
    /// Individual results
    public let results: [WindowLayoutResult]

    /// Timestamp when layouts were applied
    public let timestamp: Date

    public init(results: [WindowLayoutResult], timestamp: Date = Date()) {
        self.results = results
        self.timestamp = timestamp
    }

    /// Number of successful layouts
    public var successCount: Int {
        return results.filter { $0.success }.count
    }

    /// Number of failed layouts
    public var failureCount: Int {
        return results.filter { !$0.success }.count
    }

    /// Whether all layouts succeeded
    public var allSucceeded: Bool {
        return failureCount == 0
    }

    /// Get failures
    public var failures: [WindowLayoutResult] {
        return results.filter { !$0.success }
    }
}

/// Errors related to window operations
public enum WindowError: Error, LocalizedError {
    case accessibilityNotEnabled
    case windowNotFound(WindowIdentifier)
    case invalidFrame(WindowFrame)
    case applicationNotRunning(ApplicationIdentifier)
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotEnabled:
            return "Accessibility permissions not granted. Please enable in System Preferences > Security & Privacy > Accessibility."
        case .windowNotFound(let id):
            return "Window not found: \(id.stableID)"
        case .invalidFrame(let frame):
            return "Invalid window frame: \(frame)"
        case .applicationNotRunning(let app):
            return "Application not running: \(app.name)"
        case .operationFailed(let reason):
            return "Window operation failed: \(reason)"
        }
    }
}

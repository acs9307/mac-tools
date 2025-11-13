import Foundation

/// Categories for organizing logs
public enum LogCategory: String, CaseIterable, Codable {
    case daemon = "daemon"
    case capsLock = "capslock"
    case scroll = "scroll"
    case displayLayouts = "layouts"
    case permissions = "permissions"
    case configuration = "config"
    case windowManagement = "windows"
    case general = "general"

    /// Label for use with Logger
    public var label: String {
        return "com.mactools.\(rawValue)"
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .daemon:
            return "Daemon"
        case .capsLock:
            return "Caps Lock"
        case .scroll:
            return "Scroll Master"
        case .displayLayouts:
            return "Display Layouts"
        case .permissions:
            return "Permissions"
        case .configuration:
            return "Configuration"
        case .windowManagement:
            return "Window Management"
        case .general:
            return "General"
        }
    }
}

/// Log level definitions
public enum LogLevel: String, CaseIterable, Codable, Comparable {
    case trace
    case debug
    case info
    case notice
    case warning
    case error
    case critical

    /// Human-readable display name
    public var displayName: String {
        return rawValue.capitalized
    }

    /// Compare log levels (higher severity = greater)
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.severity < rhs.severity
    }

    /// Numeric severity for comparison
    private var severity: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .notice: return 3
        case .warning: return 4
        case .error: return 5
        case .critical: return 6
        }
    }
}

/// Represents a single log entry
public struct LogEntry: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let file: String?
    public let function: String?
    public let line: Int?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        category: LogCategory,
        message: String,
        file: String? = nil,
        function: String? = nil,
        line: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
    }

    /// Formatted log message
    public var formatted: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: self.timestamp)

        var parts: [String] = [
            timestamp,
            "[\(level.displayName.uppercased())]",
            "[\(category.displayName)]",
            message
        ]

        if let file = file, let line = line {
            let filename = (file as NSString).lastPathComponent
            parts.append("(\(filename):\(line))")
        }

        return parts.joined(separator: " ")
    }
}

/// Filter for sensitive data in logs
public struct SensitiveDataFilter {
    /// Patterns that should be redacted from logs
    private static let sensitivePatterns: [String] = [
        // Passwords
        "password",
        "passwd",
        "pwd",
        // Tokens
        "token",
        "auth",
        "secret",
        "key",
        // Personal info
        "email",
        "ssn",
        "credit",
        // Paths that might contain usernames
        "/Users/[^/]+",
        // Serial numbers (might be unique identifiers)
        "serial",
        "serialNumber"
    ]

    /// Redact sensitive information from log messages
    public static func redact(_ message: String) -> String {
        var redacted = message

        // Redact patterns (case-insensitive)
        for pattern in sensitivePatterns {
            let regex = try? NSRegularExpression(
                pattern: "\\b\(pattern)\\b[^\\s]*",
                options: .caseInsensitive
            )

            if let regex = regex {
                let range = NSRange(redacted.startIndex..., in: redacted)
                redacted = regex.stringByReplacingMatches(
                    in: redacted,
                    range: range,
                    withTemplate: "[REDACTED]"
                )
            }
        }

        // Redact email addresses
        let emailRegex = try? NSRegularExpression(
            pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
            options: []
        )

        if let emailRegex = emailRegex {
            let range = NSRange(redacted.startIndex..., in: redacted)
            redacted = emailRegex.stringByReplacingMatches(
                in: redacted,
                range: range,
                withTemplate: "[EMAIL]"
            )
        }

        // Redact file paths that contain usernames
        let pathRegex = try? NSRegularExpression(
            pattern: "/Users/[^/\\s]+",
            options: []
        )

        if let pathRegex = pathRegex {
            let range = NSRange(redacted.startIndex..., in: redacted)
            redacted = pathRegex.stringByReplacingMatches(
                in: redacted,
                range: range,
                withTemplate: "/Users/[USER]"
            )
        }

        return redacted
    }

    /// Check if a message contains sensitive data
    public static func containsSensitiveData(_ message: String) -> Bool {
        let lowercased = message.lowercased()

        for pattern in sensitivePatterns {
            if lowercased.contains(pattern.lowercased()) {
                return true
            }
        }

        // Check for email pattern
        let emailRegex = try? NSRegularExpression(
            pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
            options: []
        )

        if let emailRegex = emailRegex {
            let range = NSRange(message.startIndex..., in: message)
            if emailRegex.firstMatch(in: message, range: range) != nil {
                return true
            }
        }

        return false
    }
}

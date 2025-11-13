import Foundation
import Logging
import Combine

/// Centralized log management system
public final class LogManager: ObservableObject {
    public static let shared = LogManager()

    /// Published log entries for UI observation
    @Published public private(set) var recentLogs: [LogEntry] = []

    /// Maximum number of logs to keep in memory
    public var maxInMemoryLogs: Int = 1000

    /// Minimum log level to capture
    public var minimumLogLevel: LogLevel = .info

    /// Log file URL
    private let logFileURL: URL

    /// Queue for thread-safe log operations
    private let queue = DispatchQueue(label: "com.mactools.logmanager", attributes: .concurrent)

    /// File handle for writing logs
    private var fileHandle: FileHandle?

    /// Whether to automatically redact sensitive data
    public var autoRedactSensitiveData: Bool = true

    private init() {
        // Set up log file location
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let macToolsDir = appSupport.appendingPathComponent("MacTools", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: macToolsDir, withIntermediateDirectories: true)

        self.logFileURL = macToolsDir.appendingPathComponent("mactools.log")

        // Initialize file handle
        initializeFileHandle()

        // Configure swift-log backend
        LoggingSystem.bootstrap { label in
            return MacToolsLogHandler(label: label, logManager: self)
        }
    }

    // MARK: - File Management

    private func initializeFileHandle() {
        let fileManager = FileManager.default

        // Create file if it doesn't exist
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }

        // Open file handle for appending
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()
    }

    // MARK: - Logging

    /// Log an entry
    public func log(
        _ level: LogLevel,
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Check if level meets minimum threshold
        guard level >= minimumLogLevel else { return }

        // Redact sensitive data if enabled
        let finalMessage = autoRedactSensitiveData ?
            SensitiveDataFilter.redact(message) : message

        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: finalMessage,
            file: file,
            function: function,
            line: line
        )

        queue.async(flags: .barrier) {
            // Add to in-memory logs
            self.recentLogs.append(entry)

            // Trim if exceeds maximum
            if self.recentLogs.count > self.maxInMemoryLogs {
                self.recentLogs.removeFirst(self.recentLogs.count - self.maxInMemoryLogs)
            }

            // Write to file
            self.writeToFile(entry)
        }

        // Update published property on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    private func writeToFile(_ entry: LogEntry) {
        guard let handle = fileHandle else { return }

        let line = entry.formatted + "\n"
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }

    // MARK: - Query and Export

    /// Get logs filtered by criteria
    public func getLogs(
        category: LogCategory? = nil,
        level: LogLevel? = nil,
        since: Date? = nil,
        limit: Int? = nil
    ) -> [LogEntry] {
        return queue.sync {
            var filtered = recentLogs

            if let category = category {
                filtered = filtered.filter { $0.category == category }
            }

            if let level = level {
                filtered = filtered.filter { $0.level >= level }
            }

            if let since = since {
                filtered = filtered.filter { $0.timestamp >= since }
            }

            if let limit = limit {
                filtered = Array(filtered.suffix(limit))
            }

            return filtered
        }
    }

    /// Export logs to a file
    public func exportLogs(to url: URL) throws {
        queue.sync {
            let content = recentLogs.map { $0.formatted }.joined(separator: "\n")
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Export logs as JSON
    public func exportLogsJSON(to url: URL) throws {
        let logs = queue.sync { recentLogs }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(logs)
        try data.write(to: url)
    }

    /// Get log file contents (from disk)
    public func getLogFileContents() throws -> String {
        return try String(contentsOf: logFileURL, encoding: .utf8)
    }

    /// Clear in-memory logs
    public func clearMemoryLogs() {
        queue.async(flags: .barrier) {
            self.recentLogs.removeAll()
        }

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    /// Clear log file
    public func clearLogFile() throws {
        try "".write(to: logFileURL, atomically: true, encoding: .utf8)

        // Re-initialize file handle
        fileHandle?.closeFile()
        initializeFileHandle()
    }

    /// Get log statistics
    public func getStatistics() -> LogStatistics {
        return queue.sync {
            var stats = LogStatistics()

            for entry in recentLogs {
                stats.totalCount += 1

                switch entry.level {
                case .trace:
                    stats.traceCount += 1
                case .debug:
                    stats.debugCount += 1
                case .info:
                    stats.infoCount += 1
                case .notice:
                    stats.noticeCount += 1
                case .warning:
                    stats.warningCount += 1
                case .error:
                    stats.errorCount += 1
                case .critical:
                    stats.criticalCount += 1
                }

                stats.countByCategory[entry.category, default: 0] += 1
            }

            return stats
        }
    }
}

// MARK: - Log Statistics

public struct LogStatistics {
    public var totalCount: Int = 0
    public var traceCount: Int = 0
    public var debugCount: Int = 0
    public var infoCount: Int = 0
    public var noticeCount: Int = 0
    public var warningCount: Int = 0
    public var errorCount: Int = 0
    public var criticalCount: Int = 0
    public var countByCategory: [LogCategory: Int] = [:]

    public init() {}
}

// MARK: - Swift Log Handler

/// Custom log handler for swift-log that integrates with LogManager
struct MacToolsLogHandler: LogHandler {
    let label: String
    weak var logManager: LogManager?

    var metadata: Logging.Logger.Metadata = [:]
    var logLevel: Logging.Logger.Level = .info

    init(label: String, logManager: LogManager) {
        self.label = label
        self.logManager = logManager
    }

    func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Convert swift-log level to our LogLevel
        let ourLevel: LogLevel
        switch level {
        case .trace:
            ourLevel = .trace
        case .debug:
            ourLevel = .debug
        case .info:
            ourLevel = .info
        case .notice:
            ourLevel = .notice
        case .warning:
            ourLevel = .warning
        case .error:
            ourLevel = .error
        case .critical:
            ourLevel = .critical
        }

        // Determine category from label
        let category: LogCategory
        if label.contains("capslock") {
            category = .capsLock
        } else if label.contains("scroll") {
            category = .scroll
        } else if label.contains("layout") || label.contains("window") {
            category = .displayLayouts
        } else if label.contains("permission") {
            category = .permissions
        } else if label.contains("config") {
            category = .configuration
        } else if label.contains("daemon") {
            category = .daemon
        } else {
            category = .general
        }

        // Log to manager
        logManager?.log(
            ourLevel,
            message.description,
            category: category,
            file: file,
            function: function,
            line: Int(line)
        )
    }

    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
}

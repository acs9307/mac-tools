import XCTest
@testable import MacToolsCore

// MARK: - Log Category Tests

final class LogCategoryTests: XCTestCase {
    // MARK: - Label Tests

    func testDaemonLabel() {
        XCTAssertEqual(LogCategory.daemon.label, "com.mactools.daemon")
    }

    func testCapsLockLabel() {
        XCTAssertEqual(LogCategory.capsLock.label, "com.mactools.capslock")
    }

    func testScrollLabel() {
        XCTAssertEqual(LogCategory.scroll.label, "com.mactools.scroll")
    }

    // MARK: - Display Name Tests

    func testDaemonDisplayName() {
        XCTAssertEqual(LogCategory.daemon.displayName, "Daemon")
    }

    func testCapsLockDisplayName() {
        XCTAssertEqual(LogCategory.capsLock.displayName, "Caps Lock")
    }

    func testDisplayLayoutsDisplayName() {
        XCTAssertEqual(LogCategory.displayLayouts.displayName, "Display Layouts")
    }

    // MARK: - Codable Tests

    func testLogCategoryCodable() throws {
        for category in LogCategory.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(category)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(LogCategory.self, from: data)

            XCTAssertEqual(decoded, category)
        }
    }
}

// MARK: - Log Level Tests

final class LogLevelTests: XCTestCase {
    // MARK: - Display Name Tests

    func testDisplayNames() {
        XCTAssertEqual(LogLevel.trace.displayName, "Trace")
        XCTAssertEqual(LogLevel.debug.displayName, "Debug")
        XCTAssertEqual(LogLevel.info.displayName, "Info")
        XCTAssertEqual(LogLevel.warning.displayName, "Warning")
        XCTAssertEqual(LogLevel.error.displayName, "Error")
        XCTAssertEqual(LogLevel.critical.displayName, "Critical")
    }

    // MARK: - Comparison Tests

    func testLogLevelComparison() {
        XCTAssertTrue(LogLevel.trace < LogLevel.debug)
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.notice)
        XCTAssertTrue(LogLevel.notice < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
        XCTAssertTrue(LogLevel.error < LogLevel.critical)
    }

    func testLogLevelEqualComparison() {
        XCTAssertTrue(LogLevel.info <= LogLevel.info)
        XCTAssertTrue(LogLevel.info >= LogLevel.info)
    }

    func testLogLevelGreaterComparison() {
        XCTAssertTrue(LogLevel.critical > LogLevel.error)
        XCTAssertTrue(LogLevel.error > LogLevel.warning)
        XCTAssertTrue(LogLevel.warning > LogLevel.notice)
    }

    // MARK: - Codable Tests

    func testLogLevelCodable() throws {
        for level in LogLevel.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(level)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(LogLevel.self, from: data)

            XCTAssertEqual(decoded, level)
        }
    }
}

// MARK: - Log Entry Tests

final class LogEntryTests: XCTestCase {
    // MARK: - Initialization Tests

    func testLogEntryCreation() {
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .general,
            message: "Test message"
        )

        XCTAssertEqual(entry.level, .info)
        XCTAssertEqual(entry.category, .general)
        XCTAssertEqual(entry.message, "Test message")
    }

    func testLogEntryWithFileInfo() {
        let entry = LogEntry(
            timestamp: Date(),
            level: .error,
            category: .daemon,
            message: "Error message",
            file: "/path/to/file.swift",
            function: "testFunction()",
            line: 42
        )

        XCTAssertEqual(entry.file, "/path/to/file.swift")
        XCTAssertEqual(entry.function, "testFunction()")
        XCTAssertEqual(entry.line, 42)
    }

    // MARK: - Formatted Output Tests

    func testFormattedOutput() {
        let entry = LogEntry(
            timestamp: Date(),
            level: .info,
            category: .general,
            message: "Test message"
        )

        let formatted = entry.formatted

        XCTAssertTrue(formatted.contains("[INFO]"))
        XCTAssertTrue(formatted.contains("[General]"))
        XCTAssertTrue(formatted.contains("Test message"))
    }

    func testFormattedOutputWithFileInfo() {
        let entry = LogEntry(
            timestamp: Date(),
            level: .error,
            category: .daemon,
            message: "Error",
            file: "/path/to/file.swift",
            line: 42
        )

        let formatted = entry.formatted

        XCTAssertTrue(formatted.contains("file.swift"))
        XCTAssertTrue(formatted.contains("42"))
    }

    // MARK: - Codable Tests

    func testLogEntryCodable() throws {
        let entry = LogEntry(
            timestamp: Date(),
            level: .warning,
            category: .capsLock,
            message: "Test message",
            file: "test.swift",
            function: "test()",
            line: 10
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LogEntry.self, from: data)

        XCTAssertEqual(decoded.level, entry.level)
        XCTAssertEqual(decoded.category, entry.category)
        XCTAssertEqual(decoded.message, entry.message)
        XCTAssertEqual(decoded.file, entry.file)
        XCTAssertEqual(decoded.function, entry.function)
        XCTAssertEqual(decoded.line, entry.line)
    }
}

// MARK: - Sensitive Data Filter Tests

final class SensitiveDataFilterTests: XCTestCase {
    // MARK: - Redaction Tests

    func testRedactPassword() {
        let message = "User password is secret123"
        let redacted = SensitiveDataFilter.redact(message)

        XCTAssertTrue(redacted.contains("[REDACTED]"))
        XCTAssertFalse(redacted.contains("secret123"))
    }

    func testRedactEmail() {
        let message = "Contact user@example.com for help"
        let redacted = SensitiveDataFilter.redact(message)

        XCTAssertTrue(redacted.contains("[EMAIL]"))
        XCTAssertFalse(redacted.contains("user@example.com"))
    }

    func testRedactToken() {
        let message = "Auth token: abc123xyz"
        let redacted = SensitiveDataFilter.redact(message)

        XCTAssertTrue(redacted.contains("[REDACTED]"))
        XCTAssertFalse(redacted.contains("abc123xyz"))
    }

    func testRedactFilePath() {
        let message = "File located at /Users/johndoe/Documents"
        let redacted = SensitiveDataFilter.redact(message)

        XCTAssertTrue(redacted.contains("/Users/[USER]"))
        XCTAssertFalse(redacted.contains("johndoe"))
    }

    func testRedactMultipleSensitiveData() {
        let message = "Password: secret, Email: user@example.com, Token: abc123"
        let redacted = SensitiveDataFilter.redact(message)

        XCTAssertTrue(redacted.contains("[REDACTED]"))
        XCTAssertTrue(redacted.contains("[EMAIL]"))
        XCTAssertFalse(redacted.contains("secret"))
        XCTAssertFalse(redacted.contains("user@example.com"))
        XCTAssertFalse(redacted.contains("abc123"))
    }

    func testDoesNotRedactNormalText() {
        let message = "Application started successfully"
        let redacted = SensitiveDataFilter.redact(message)

        XCTAssertEqual(redacted, message)
    }

    // MARK: - Detection Tests

    func testContainsSensitiveDataPassword() {
        XCTAssertTrue(SensitiveDataFilter.containsSensitiveData("password: secret"))
        XCTAssertTrue(SensitiveDataFilter.containsSensitiveData("pwd=123"))
    }

    func testContainsSensitiveDataEmail() {
        XCTAssertTrue(SensitiveDataFilter.containsSensitiveData("user@example.com"))
    }

    func testContainsSensitiveDataToken() {
        XCTAssertTrue(SensitiveDataFilter.containsSensitiveData("auth token"))
    }

    func testDoesNotContainSensitiveData() {
        XCTAssertFalse(SensitiveDataFilter.containsSensitiveData("Normal log message"))
        XCTAssertFalse(SensitiveDataFilter.containsSensitiveData("Application started"))
    }
}

// MARK: - Log Manager Tests

final class LogManagerTests: XCTestCase {
    var logManager: LogManager!

    override func setUp() {
        super.setUp()
        logManager = .shared
        logManager.clearMemoryLogs()
    }

    override func tearDown() {
        logManager.clearMemoryLogs()
        logManager = nil
        super.tearDown()
    }

    // MARK: - Logging Tests

    func testBasicLogging() {
        logManager.log(.info, "Test message", category: .general)

        XCTAssertEqual(logManager.recentLogs.count, 1)
        XCTAssertEqual(logManager.recentLogs.first?.message, "Test message")
        XCTAssertEqual(logManager.recentLogs.first?.level, .info)
        XCTAssertEqual(logManager.recentLogs.first?.category, .general)
    }

    func testLoggingMultipleEntries() {
        logManager.log(.info, "Message 1", category: .general)
        logManager.log(.warning, "Message 2", category: .daemon)
        logManager.log(.error, "Message 3", category: .capsLock)

        XCTAssertEqual(logManager.recentLogs.count, 3)
    }

    func testMinimumLogLevel() {
        logManager.minimumLogLevel = .warning

        logManager.log(.debug, "Debug message", category: .general)
        logManager.log(.info, "Info message", category: .general)
        logManager.log(.warning, "Warning message", category: .general)
        logManager.log(.error, "Error message", category: .general)

        // Only warning and error should be logged
        XCTAssertEqual(logManager.recentLogs.count, 2)
    }

    func testAutoRedactSensitiveData() {
        logManager.autoRedactSensitiveData = true
        logManager.log(.info, "Password: secret123", category: .general)

        XCTAssertTrue(logManager.recentLogs.first?.message.contains("[REDACTED]") ?? false)
        XCTAssertFalse(logManager.recentLogs.first?.message.contains("secret123") ?? true)
    }

    func testAutoRedactCanBeDisabled() {
        logManager.autoRedactSensitiveData = false
        logManager.log(.info, "Password: secret123", category: .general)

        XCTAssertTrue(logManager.recentLogs.first?.message.contains("secret123") ?? false)
    }

    // MARK: - Memory Management Tests

    func testMaxInMemoryLogs() {
        logManager.maxInMemoryLogs = 5

        for i in 1...10 {
            logManager.log(.info, "Message \(i)", category: .general)
        }

        // Should only keep last 5
        XCTAssertEqual(logManager.recentLogs.count, 5)
        XCTAssertEqual(logManager.recentLogs.first?.message, "Message 6")
        XCTAssertEqual(logManager.recentLogs.last?.message, "Message 10")
    }

    func testClearMemoryLogs() {
        logManager.log(.info, "Message 1", category: .general)
        logManager.log(.info, "Message 2", category: .general)

        XCTAssertEqual(logManager.recentLogs.count, 2)

        logManager.clearMemoryLogs()

        XCTAssertEqual(logManager.recentLogs.count, 0)
    }

    // MARK: - Query Tests

    func testGetLogsByCategory() {
        logManager.log(.info, "Daemon message", category: .daemon)
        logManager.log(.info, "General message", category: .general)
        logManager.log(.info, "Caps lock message", category: .capsLock)

        let daemonLogs = logManager.getLogs(category: .daemon)

        XCTAssertEqual(daemonLogs.count, 1)
        XCTAssertEqual(daemonLogs.first?.category, .daemon)
    }

    func testGetLogsByLevel() {
        logManager.log(.info, "Info message", category: .general)
        logManager.log(.warning, "Warning message", category: .general)
        logManager.log(.error, "Error message", category: .general)

        let warningAndAbove = logManager.getLogs(level: .warning)

        XCTAssertEqual(warningAndAbove.count, 2)
    }

    func testGetLogsSinceDate() {
        let now = Date()

        logManager.log(.info, "Old message", category: .general)

        sleep(1)

        let recent = Date()
        logManager.log(.info, "Recent message", category: .general)

        let recentLogs = logManager.getLogs(since: recent)

        XCTAssertEqual(recentLogs.count, 1)
        XCTAssertEqual(recentLogs.first?.message, "Recent message")
    }

    func testGetLogsWithLimit() {
        for i in 1...10 {
            logManager.log(.info, "Message \(i)", category: .general)
        }

        let limited = logManager.getLogs(limit: 5)

        XCTAssertEqual(limited.count, 5)
        // Should get last 5
        XCTAssertEqual(limited.first?.message, "Message 6")
    }

    // MARK: - Statistics Tests

    func testGetStatistics() {
        logManager.log(.info, "Info 1", category: .general)
        logManager.log(.info, "Info 2", category: .daemon)
        logManager.log(.warning, "Warning", category: .general)
        logManager.log(.error, "Error", category: .capsLock)

        let stats = logManager.getStatistics()

        XCTAssertEqual(stats.totalCount, 4)
        XCTAssertEqual(stats.infoCount, 2)
        XCTAssertEqual(stats.warningCount, 1)
        XCTAssertEqual(stats.errorCount, 1)
    }

    func testGetStatisticsByCategory() {
        logManager.log(.info, "Message 1", category: .general)
        logManager.log(.info, "Message 2", category: .general)
        logManager.log(.info, "Message 3", category: .daemon)

        let stats = logManager.getStatistics()

        XCTAssertEqual(stats.countByCategory[.general], 2)
        XCTAssertEqual(stats.countByCategory[.daemon], 1)
    }

    // MARK: - Export Tests

    func testExportLogs() throws {
        logManager.log(.info, "Message 1", category: .general)
        logManager.log(.warning, "Message 2", category: .daemon)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-logs.txt")

        try logManager.exportLogs(to: tempURL)

        let content = try String(contentsOf: tempURL, encoding: .utf8)

        XCTAssertTrue(content.contains("Message 1"))
        XCTAssertTrue(content.contains("Message 2"))

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testExportLogsJSON() throws {
        logManager.log(.info, "Message 1", category: .general)
        logManager.log(.warning, "Message 2", category: .daemon)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-logs.json")

        try logManager.exportLogsJSON(to: tempURL)

        let data = try Data(contentsOf: tempURL)
        let logs = try JSONDecoder().decode([LogEntry].self, from: data)

        XCTAssertEqual(logs.count, 2)

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
}

// MARK: - Log Statistics Tests

final class LogStatisticsTests: XCTestCase {
    func testLogStatisticsInitialization() {
        let stats = LogStatistics()

        XCTAssertEqual(stats.totalCount, 0)
        XCTAssertEqual(stats.infoCount, 0)
        XCTAssertEqual(stats.errorCount, 0)
        XCTAssertTrue(stats.countByCategory.isEmpty)
    }
}

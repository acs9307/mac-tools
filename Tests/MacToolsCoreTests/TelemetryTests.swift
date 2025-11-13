import XCTest
@testable import MacToolsCore

// MARK: - Metric Type Tests

final class MetricTypeTests: XCTestCase {
    // MARK: - Category Tests

    func testCapsLockMetricsCategory() {
        XCTAssertEqual(MetricType.capsLockEnabled.category, .capsLock)
        XCTAssertEqual(MetricType.capsLockDisabled.category, .capsLock)
        XCTAssertEqual(MetricType.capsLockQuickTap.category, .capsLock)
    }

    func testScrollMetricsCategory() {
        XCTAssertEqual(MetricType.scrollMasterEnabled.category, .scroll)
        XCTAssertEqual(MetricType.scrollConfigChanged.category, .scroll)
    }

    func testLayoutMetricsCategory() {
        XCTAssertEqual(MetricType.layoutPresetCreated.category, .displayLayouts)
        XCTAssertEqual(MetricType.layoutPresetApplied.category, .displayLayouts)
    }

    func testPermissionMetricsCategory() {
        XCTAssertEqual(MetricType.permissionGranted.category, .permissions)
        XCTAssertEqual(MetricType.permissionDenied.category, .permissions)
    }

    func testGeneralMetricsCategory() {
        XCTAssertEqual(MetricType.appLaunched.category, .general)
        XCTAssertEqual(MetricType.appTerminated.category, .general)
    }

    // MARK: - Display Name Tests

    func testMetricTypeDisplayNames() {
        XCTAssertEqual(MetricType.capsLockEnabled.displayName, "Caps Lock Enabled")
        XCTAssertEqual(MetricType.scrollMasterEnabled.displayName, "Scroll Master Enabled")
        XCTAssertEqual(MetricType.layoutPresetCreated.displayName, "Layout Preset Created")
    }

    // MARK: - Codable Tests

    func testMetricTypeCodable() throws {
        for metricType in MetricType.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(metricType)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(MetricType.self, from: data)

            XCTAssertEqual(decoded, metricType)
        }
    }
}

// MARK: - Metric Category Tests

final class MetricCategoryTests: XCTestCase {
    // MARK: - Display Name Tests

    func testCategoryDisplayNames() {
        XCTAssertEqual(MetricCategory.capsLock.displayName, "Caps Lock")
        XCTAssertEqual(MetricCategory.scroll.displayName, "Scroll Master")
        XCTAssertEqual(MetricCategory.displayLayouts.displayName, "Display Layouts")
    }

    // MARK: - Codable Tests

    func testMetricCategoryCodable() throws {
        for category in MetricCategory.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(category)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(MetricCategory.self, from: data)

            XCTAssertEqual(decoded, category)
        }
    }
}

// MARK: - Metric Event Tests

final class MetricEventTests: XCTestCase {
    // MARK: - Initialization Tests

    func testMetricEventCreation() {
        let event = MetricEvent(
            timestamp: Date(),
            type: .capsLockEnabled,
            metadata: ["key": "value"]
        )

        XCTAssertEqual(event.type, .capsLockEnabled)
        XCTAssertEqual(event.metadata?["key"], "value")
        XCTAssertNotNil(event.id)
    }

    func testMetricEventWithoutMetadata() {
        let event = MetricEvent(
            timestamp: Date(),
            type: .scrollMasterEnabled,
            metadata: nil
        )

        XCTAssertEqual(event.type, .scrollMasterEnabled)
        XCTAssertNil(event.metadata)
    }

    // MARK: - Codable Tests

    func testMetricEventCodable() throws {
        let event = MetricEvent(
            timestamp: Date(),
            type: .layoutPresetApplied,
            metadata: ["preset": "Work Layout"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MetricEvent.self, from: data)

        XCTAssertEqual(decoded.type, event.type)
        XCTAssertEqual(decoded.metadata?["preset"], "Work Layout")
    }
}

// MARK: - Metric Aggregate Tests

final class MetricAggregateTests: XCTestCase {
    // MARK: - Initialization Tests

    func testMetricAggregateCreation() {
        let aggregate = MetricAggregate(type: .capsLockEnabled)

        XCTAssertEqual(aggregate.type, .capsLockEnabled)
        XCTAssertEqual(aggregate.count, 0)
        XCTAssertNil(aggregate.firstOccurrence)
        XCTAssertNil(aggregate.lastOccurrence)
    }

    // MARK: - Add Event Tests

    func testAddEventIncreasesCount() {
        var aggregate = MetricAggregate(type: .scrollConfigChanged)

        aggregate.addEvent(at: Date())

        XCTAssertEqual(aggregate.count, 1)
    }

    func testAddEventSetsFirstOccurrence() {
        var aggregate = MetricAggregate(type: .layoutPresetCreated)
        let timestamp = Date()

        aggregate.addEvent(at: timestamp)

        XCTAssertEqual(aggregate.firstOccurrence, timestamp)
    }

    func testAddEventUpdatesLastOccurrence() {
        var aggregate = MetricAggregate(type: .layoutPresetApplied)
        let first = Date()
        let second = Date().addingTimeInterval(10)

        aggregate.addEvent(at: first)
        aggregate.addEvent(at: second)

        XCTAssertEqual(aggregate.lastOccurrence, second)
    }

    func testAddEventKeepsEarliestFirst() {
        var aggregate = MetricAggregate(type: .capsLockQuickTap)
        let later = Date()
        let earlier = Date().addingTimeInterval(-10)

        aggregate.addEvent(at: later)
        aggregate.addEvent(at: earlier)

        XCTAssertEqual(aggregate.firstOccurrence, earlier)
    }

    // MARK: - Codable Tests

    func testMetricAggregateCodable() throws {
        var aggregate = MetricAggregate(type: .scrollSmoothingEnabled)
        aggregate.addEvent(at: Date())

        let encoder = JSONEncoder()
        let data = try encoder.encode(aggregate)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MetricAggregate.self, from: data)

        XCTAssertEqual(decoded.type, aggregate.type)
        XCTAssertEqual(decoded.count, aggregate.count)
    }
}

// MARK: - Telemetry Configuration Tests

final class TelemetryConfigurationTests: XCTestCase {
    // MARK: - Default Values Tests

    func testDefaultConfiguration() {
        let config = TelemetryConfiguration()

        XCTAssertFalse(config.enabled) // Disabled by default
        XCTAssertEqual(config.maxEventsInMemory, 10000)
        XCTAssertTrue(config.persistToDisk)
        XCTAssertEqual(config.retentionDays, 90)
    }

    func testCustomConfiguration() {
        let config = TelemetryConfiguration(
            enabled: true,
            maxEventsInMemory: 5000,
            persistToDisk: false,
            retentionDays: 30
        )

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.maxEventsInMemory, 5000)
        XCTAssertFalse(config.persistToDisk)
        XCTAssertEqual(config.retentionDays, 30)
    }

    // MARK: - Codable Tests

    func testTelemetryConfigurationCodable() throws {
        let config = TelemetryConfiguration(
            enabled: true,
            maxEventsInMemory: 5000,
            persistToDisk: false,
            retentionDays: 30
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TelemetryConfiguration.self, from: data)

        XCTAssertEqual(decoded.enabled, config.enabled)
        XCTAssertEqual(decoded.maxEventsInMemory, config.maxEventsInMemory)
        XCTAssertEqual(decoded.persistToDisk, config.persistToDisk)
        XCTAssertEqual(decoded.retentionDays, config.retentionDays)
    }
}

// MARK: - Telemetry Manager Tests

final class TelemetryManagerTests: XCTestCase {
    var telemetryManager: TelemetryManager!

    override func setUp() {
        super.setUp()
        telemetryManager = .shared
        telemetryManager.clearAllEvents()
        telemetryManager.disableTelemetry()
    }

    override func tearDown() {
        telemetryManager.clearAllEvents()
        telemetryManager.disableTelemetry()
        telemetryManager = nil
        super.tearDown()
    }

    // MARK: - Disabled by Default Tests

    func testTelemetryDisabledByDefault() {
        XCTAssertFalse(telemetryManager.isEnabled)
    }

    func testNoEventsRecordedWhenDisabled() {
        telemetryManager.disableTelemetry()
        telemetryManager.recordEvent(.capsLockEnabled)

        XCTAssertEqual(telemetryManager.eventCount, 0)
    }

    // MARK: - Enable/Disable Tests

    func testEnableTelemetry() {
        telemetryManager.enableTelemetry()

        XCTAssertTrue(telemetryManager.isEnabled)
    }

    func testDisableTelemetry() {
        telemetryManager.enableTelemetry()
        telemetryManager.disableTelemetry()

        XCTAssertFalse(telemetryManager.isEnabled)
    }

    func testDisablingDoesNotClearExistingEvents() {
        telemetryManager.enableTelemetry()
        telemetryManager.recordEvent(.capsLockEnabled)

        let countBefore = telemetryManager.eventCount

        telemetryManager.disableTelemetry()

        XCTAssertEqual(telemetryManager.eventCount, countBefore)
    }

    // MARK: - Event Recording Tests

    func testRecordEvent() {
        telemetryManager.enableTelemetry()
        telemetryManager.recordEvent(.capsLockEnabled)

        XCTAssertEqual(telemetryManager.eventCount, 1)
    }

    func testRecordEventWithMetadata() {
        telemetryManager.enableTelemetry()
        telemetryManager.recordEvent(.layoutPresetApplied, metadata: ["preset": "Work"])

        let events = telemetryManager.recentEvents
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.metadata?["preset"], "Work")
    }

    func testRecordMultipleEvents() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.capsLockEnabled)
        telemetryManager.recordEvent(.scrollMasterEnabled)
        telemetryManager.recordEvent(.layoutPresetCreated)

        XCTAssertEqual(telemetryManager.eventCount, 3)
    }

    func testMaxEventsInMemory() {
        telemetryManager.enableTelemetry()
        telemetryManager.configuration.maxEventsInMemory = 5

        // Record more than max
        for i in 1...10 {
            telemetryManager.recordEvent(.capsLockQuickTap, metadata: ["count": "\(i)"])
        }

        // Should only keep last 5
        XCTAssertEqual(telemetryManager.eventCount, 5)
    }

    // MARK: - Query Tests

    func testGetEventsByType() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.capsLockEnabled)
        telemetryManager.recordEvent(.scrollMasterEnabled)
        telemetryManager.recordEvent(.capsLockEnabled)

        let capsLockEvents = telemetryManager.getEvents(type: .capsLockEnabled)

        XCTAssertEqual(capsLockEvents.count, 2)
        XCTAssertTrue(capsLockEvents.allSatisfy { $0.type == .capsLockEnabled })
    }

    func testGetEventsByCategory() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.capsLockEnabled)
        telemetryManager.recordEvent(.capsLockDisabled)
        telemetryManager.recordEvent(.scrollMasterEnabled)

        let capsLockEvents = telemetryManager.getEvents(category: .capsLock)

        XCTAssertEqual(capsLockEvents.count, 2)
        XCTAssertTrue(capsLockEvents.allSatisfy { $0.type.category == .capsLock })
    }

    func testGetEventsSinceDate() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.layoutPresetCreated)

        sleep(1)

        let cutoff = Date()
        telemetryManager.recordEvent(.layoutPresetApplied)

        let recentEvents = telemetryManager.getEvents(since: cutoff)

        XCTAssertEqual(recentEvents.count, 1)
        XCTAssertEqual(recentEvents.first?.type, .layoutPresetApplied)
    }

    func testGetEventsWithLimit() {
        telemetryManager.enableTelemetry()

        for _ in 1...10 {
            telemetryManager.recordEvent(.scrollConfigChanged)
        }

        let limited = telemetryManager.getEvents(limit: 5)

        XCTAssertEqual(limited.count, 5)
    }

    // MARK: - Aggregates Tests

    func testGetAggregates() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.capsLockEnabled)
        telemetryManager.recordEvent(.capsLockEnabled)
        telemetryManager.recordEvent(.scrollMasterEnabled)

        let aggregates = telemetryManager.getAggregates()

        XCTAssertEqual(aggregates[.capsLockEnabled]?.count, 2)
        XCTAssertEqual(aggregates[.scrollMasterEnabled]?.count, 1)
    }

    func testAggregatesIncludeTimestamps() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.layoutPresetApplied)

        let aggregates = telemetryManager.getAggregates()

        XCTAssertNotNil(aggregates[.layoutPresetApplied]?.firstOccurrence)
        XCTAssertNotNil(aggregates[.layoutPresetApplied]?.lastOccurrence)
    }

    // MARK: - Statistics Tests

    func testGetStatistics() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.capsLockEnabled)
        telemetryManager.recordEvent(.scrollMasterEnabled)
        telemetryManager.recordEvent(.layoutPresetCreated)

        let stats = telemetryManager.getStatistics()

        XCTAssertEqual(stats.totalEvents, 3)
        XCTAssertEqual(stats.eventsByCategory[.capsLock], 1)
        XCTAssertEqual(stats.eventsByCategory[.scroll], 1)
        XCTAssertEqual(stats.eventsByCategory[.displayLayouts], 1)
    }

    func testStatisticsIncludeDateRange() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.appLaunched)

        let stats = telemetryManager.getStatistics()

        XCTAssertNotNil(stats.firstEventDate)
        XCTAssertNotNil(stats.lastEventDate)
    }

    // MARK: - Data Management Tests

    func testClearAllEvents() {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.capsLockEnabled)
        telemetryManager.recordEvent(.scrollMasterEnabled)

        XCTAssertGreaterThan(telemetryManager.eventCount, 0)

        telemetryManager.clearAllEvents()

        XCTAssertEqual(telemetryManager.eventCount, 0)
    }

    // MARK: - Export Tests

    func testExportEvents() throws {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.capsLockEnabled)
        telemetryManager.recordEvent(.scrollMasterEnabled)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-telemetry.json")

        try telemetryManager.exportEvents(to: tempURL)

        let data = try Data(contentsOf: tempURL)
        let events = try JSONDecoder().decode([MetricEvent].self, from: data)

        XCTAssertEqual(events.count, 2)

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testExportStatistics() throws {
        telemetryManager.enableTelemetry()

        telemetryManager.recordEvent(.layoutPresetCreated)
        telemetryManager.recordEvent(.layoutPresetApplied)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-stats.json")

        try telemetryManager.exportStatistics(to: tempURL)

        let data = try Data(contentsOf: tempURL)
        let stats = try JSONDecoder().decode(TelemetryStatistics.self, from: data)

        XCTAssertEqual(stats.totalEvents, 2)

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
}

// MARK: - Telemetry Statistics Tests

final class TelemetryStatisticsTests: XCTestCase {
    func testTelemetryStatisticsInitialization() {
        let stats = TelemetryStatistics()

        XCTAssertEqual(stats.totalEvents, 0)
        XCTAssertTrue(stats.eventsByCategory.isEmpty)
        XCTAssertTrue(stats.eventsByType.isEmpty)
        XCTAssertNil(stats.firstEventDate)
        XCTAssertNil(stats.lastEventDate)
    }

    func testTelemetryStatisticsCodable() throws {
        let stats = TelemetryStatistics(
            totalEvents: 10,
            eventsByCategory: [.capsLock: 5, .scroll: 5],
            eventsByType: [.capsLockEnabled: 3, .scrollMasterEnabled: 2],
            firstEventDate: Date(),
            lastEventDate: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(stats)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TelemetryStatistics.self, from: data)

        XCTAssertEqual(decoded.totalEvents, stats.totalEvents)
    }
}

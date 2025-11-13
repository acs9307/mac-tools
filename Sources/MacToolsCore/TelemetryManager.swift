import Foundation
import Combine

/// Configuration for telemetry collection
public struct TelemetryConfiguration: Codable {
    /// Whether telemetry is enabled (opt-in, disabled by default)
    public var enabled: Bool

    /// Maximum number of events to keep in memory
    public var maxEventsInMemory: Int

    /// Whether to persist events to disk
    public var persistToDisk: Bool

    /// How long to retain events (in days, 0 = forever)
    public var retentionDays: Int

    public init(
        enabled: Bool = false,
        maxEventsInMemory: Int = 10000,
        persistToDisk: Bool = true,
        retentionDays: Int = 90
    ) {
        self.enabled = enabled
        self.maxEventsInMemory = maxEventsInMemory
        self.persistToDisk = persistToDisk
        self.retentionDays = retentionDays
    }
}

/// Manages telemetry collection and storage
public final class TelemetryManager: ObservableObject {
    public static let shared = TelemetryManager()

    /// Current configuration
    @Published public var configuration: TelemetryConfiguration {
        didSet {
            saveConfiguration()
        }
    }

    /// Recent events (in memory)
    @Published public private(set) var recentEvents: [MetricEvent] = []

    /// Queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.mactools.telemetry", attributes: .concurrent)

    /// Storage URL
    private let storageURL: URL
    private let configURL: URL

    private init() {
        // Set up storage location
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let macToolsDir = appSupport.appendingPathComponent("MacTools", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: macToolsDir, withIntermediateDirectories: true)

        self.storageURL = macToolsDir.appendingPathComponent("telemetry.json")
        self.configURL = macToolsDir.appendingPathComponent("telemetry-config.json")

        // Load configuration (defaults to disabled)
        self.configuration = Self.loadConfiguration(from: configURL)

        // Load events if telemetry is enabled
        if configuration.enabled {
            loadEvents()
        }
    }

    // MARK: - Configuration Management

    private static func loadConfiguration(from url: URL) -> TelemetryConfiguration {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(TelemetryConfiguration.self, from: data) else {
            return TelemetryConfiguration()
        }
        return config
    }

    private func saveConfiguration() {
        queue.async(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            if let data = try? encoder.encode(self.configuration) {
                try? data.write(to: self.configURL)
            }
        }
    }

    /// Enable telemetry collection
    public func enableTelemetry() {
        configuration.enabled = true
        loadEvents()
    }

    /// Disable telemetry collection
    public func disableTelemetry() {
        configuration.enabled = false
    }

    // MARK: - Event Recording

    /// Record a metric event
    public func recordEvent(
        _ type: MetricType,
        metadata: [String: String]? = nil
    ) {
        // Only record if telemetry is enabled
        guard configuration.enabled else { return }

        let event = MetricEvent(
            timestamp: Date(),
            type: type,
            metadata: metadata
        )

        queue.async(flags: .barrier) {
            // Add to in-memory events
            self.recentEvents.append(event)

            // Trim if exceeds maximum
            if self.recentEvents.count > self.configuration.maxEventsInMemory {
                self.recentEvents.removeFirst(self.recentEvents.count - self.configuration.maxEventsInMemory)
            }

            // Persist to disk if enabled
            if self.configuration.persistToDisk {
                self.saveEvents()
            }
        }

        // Update published property on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    // MARK: - Event Storage

    private func loadEvents() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        queue.async(flags: .barrier) {
            do {
                let data = try Data(contentsOf: self.storageURL)
                let events = try JSONDecoder().decode([MetricEvent].self, from: data)

                // Apply retention policy
                let retentionDate = self.getRetentionDate()
                self.recentEvents = events.filter { $0.timestamp >= retentionDate }

                // Update on main thread
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            } catch {
                // Failed to load, start fresh
                self.recentEvents = []
            }
        }
    }

    private func saveEvents() {
        let events = recentEvents

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(events) {
            try? data.write(to: storageURL)
        }
    }

    private func getRetentionDate() -> Date {
        if configuration.retentionDays == 0 {
            return Date.distantPast
        }

        return Calendar.current.date(
            byAdding: .day,
            value: -configuration.retentionDays,
            to: Date()
        ) ?? Date.distantPast
    }

    // MARK: - Querying

    /// Get events filtered by criteria
    public func getEvents(
        type: MetricType? = nil,
        category: MetricCategory? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil
    ) -> [MetricEvent] {
        return queue.sync {
            var filtered = recentEvents

            if let type = type {
                filtered = filtered.filter { $0.type == type }
            }

            if let category = category {
                filtered = filtered.filter { $0.type.category == category }
            }

            if let since = since {
                filtered = filtered.filter { $0.timestamp >= since }
            }

            if let until = until {
                filtered = filtered.filter { $0.timestamp <= until }
            }

            if let limit = limit {
                filtered = Array(filtered.suffix(limit))
            }

            return filtered
        }
    }

    /// Get aggregated metrics
    public func getAggregates() -> [MetricType: MetricAggregate] {
        return queue.sync {
            var aggregates: [MetricType: MetricAggregate] = [:]

            for event in recentEvents {
                if aggregates[event.type] == nil {
                    aggregates[event.type] = MetricAggregate(type: event.type)
                }
                aggregates[event.type]?.addEvent(at: event.timestamp)
            }

            return aggregates
        }
    }

    /// Get overall statistics
    public func getStatistics() -> TelemetryStatistics {
        return queue.sync {
            var stats = TelemetryStatistics()

            for event in recentEvents {
                stats.totalEvents += 1

                // By category
                let category = event.type.category
                stats.eventsByCategory[category, default: 0] += 1

                // By type
                stats.eventsByType[event.type, default: 0] += 1

                // Date range
                if stats.firstEventDate == nil || event.timestamp < stats.firstEventDate! {
                    stats.firstEventDate = event.timestamp
                }
                if stats.lastEventDate == nil || event.timestamp > stats.lastEventDate! {
                    stats.lastEventDate = event.timestamp
                }
            }

            return stats
        }
    }

    // MARK: - Data Management

    /// Clear all events
    public func clearAllEvents() {
        queue.async(flags: .barrier) {
            self.recentEvents.removeAll()

            if self.configuration.persistToDisk {
                try? FileManager.default.removeItem(at: self.storageURL)
            }
        }

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    /// Apply retention policy (remove old events)
    public func applyRetentionPolicy() {
        queue.async(flags: .barrier) {
            let retentionDate = self.getRetentionDate()
            let beforeCount = self.recentEvents.count

            self.recentEvents = self.recentEvents.filter { $0.timestamp >= retentionDate }

            let removedCount = beforeCount - self.recentEvents.count
            if removedCount > 0 && self.configuration.persistToDisk {
                self.saveEvents()
            }

            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    /// Export events to JSON
    public func exportEvents(to url: URL) throws {
        let events = queue.sync { recentEvents }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(events)
        try data.write(to: url)
    }

    /// Export statistics to JSON
    public func exportStatistics(to url: URL) throws {
        let stats = getStatistics()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(stats)
        try data.write(to: url)
    }

    /// Get event count
    public var eventCount: Int {
        return queue.sync { recentEvents.count }
    }

    /// Check if telemetry is enabled
    public var isEnabled: Bool {
        return configuration.enabled
    }
}

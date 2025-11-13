import SwiftUI

/// SwiftUI view for viewing and managing telemetry
public struct TelemetryViewerView: View {
    @ObservedObject private var telemetryManager: TelemetryManager

    @State private var selectedCategory: MetricCategory?
    @State private var showingSettings = false
    @State private var showingExportSheet = false

    public init(telemetryManager: TelemetryManager = .shared) {
        self.telemetryManager = telemetryManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            if !telemetryManager.isEnabled {
                disabledView
            } else {
                // Content
                contentView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showingSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showingExportSheet) {
            exportSheet
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Telemetry & Metrics")
                    .font(.title)
                    .fontWeight(.bold)

                if telemetryManager.isEnabled {
                    Text("\(telemetryManager.eventCount) events recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Telemetry is disabled")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                if telemetryManager.isEnabled {
                    Button("Export") {
                        showingExportSheet = true
                    }
                    .buttonStyle(.bordered)

                    Button("Clear Data") {
                        telemetryManager.clearAllEvents()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Settings") {
                    showingSettings = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var disabledView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 72))
                .foregroundColor(.secondary)

            Text("Telemetry is Disabled")
                .font(.title)
                .fontWeight(.semibold)

            Text("Enable telemetry to collect anonymous usage statistics that help improve MacTools.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            VStack(alignment: .leading, spacing: 8) {
                privacyBullet("All data is stored locally on your Mac")
                privacyBullet("No personal information is collected")
                privacyBullet("No data is sent to external servers")
                privacyBullet("You can clear all data at any time")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Button("Enable Telemetry") {
                telemetryManager.enableTelemetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Statistics overview
                statisticsSection

                Divider()

                // Category filter
                categoryFilterView

                Divider()

                // Aggregated metrics
                aggregatesSection
            }
            .padding()
        }
    }

    private var statisticsSection: some View {
        let stats = telemetryManager.getStatistics()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            HStack(spacing: 20) {
                StatCard(
                    title: "Total Events",
                    value: "\(stats.totalEvents)",
                    icon: "chart.bar",
                    color: .blue
                )

                if let firstDate = stats.firstEventDate {
                    StatCard(
                        title: "First Event",
                        value: formatDate(firstDate),
                        icon: "calendar",
                        color: .green
                    )
                }

                if let lastDate = stats.lastEventDate {
                    StatCard(
                        title: "Last Event",
                        value: formatDate(lastDate),
                        icon: "clock",
                        color: .orange
                    )
                }

                Spacer()
            }

            // By category
            if !stats.eventsByCategory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By Category")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(MetricCategory.allCases, id: \.self) { category in
                            if let count = stats.eventsByCategory[category], count > 0 {
                                CategoryChip(
                                    category: category,
                                    count: count
                                )
                            }
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private var categoryFilterView: some View {
        HStack {
            Text("Filter by Category:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: { selectedCategory = nil }) {
                Text("All")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedCategory == nil ? Color.blue : Color.clear)
                    .foregroundColor(selectedCategory == nil ? .white : .primary)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            ForEach(MetricCategory.allCases, id: \.self) { category in
                Button(action: { selectedCategory = category }) {
                    Text(category.displayName)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedCategory == category ? Color.blue : Color.clear)
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private var aggregatesSection: some View {
        let aggregates = telemetryManager.getAggregates()
        let filtered = aggregates.filter { entry in
            selectedCategory == nil || entry.value.type.category == selectedCategory
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Metrics")
                .font(.headline)

            if filtered.isEmpty {
                Text("No metrics recorded")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(filtered.values.sorted(by: { $0.count > $1.count })), id: \.type) { aggregate in
                    AggregateRow(aggregate: aggregate)
                }
            }
        }
    }

    private var settingsSheet: some View {
        VStack(spacing: 20) {
            Text("Telemetry Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable Telemetry", isOn: $telemetryManager.configuration.enabled)
                    .onChange(of: telemetryManager.configuration.enabled) { enabled in
                        if enabled {
                            telemetryManager.enableTelemetry()
                        } else {
                            telemetryManager.disableTelemetry()
                        }
                    }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Retention Period")
                        .font(.subheadline)

                    Picker("Days:", selection: $telemetryManager.configuration.retentionDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("180 days").tag(180)
                        Text("Forever").tag(0)
                    }
                    .frame(width: 200)
                }

                Toggle("Persist to Disk", isOn: $telemetryManager.configuration.persistToDisk)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Notice")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    privacyBullet("Only feature usage counts are collected")
                    privacyBullet("No personal information is tracked")
                    privacyBullet("All data stays on your local machine")
                    privacyBullet("No analytics are sent to external servers")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            HStack {
                Button("Apply Retention Policy") {
                    telemetryManager.applyRetentionPolicy()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") {
                    showingSettings = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500)
    }

    private var exportSheet: some View {
        VStack(spacing: 20) {
            Text("Export Telemetry Data")
                .font(.headline)

            Text("Choose export format")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("Export Events") {
                    exportEvents()
                }
                .buttonStyle(.borderedProminent)

                Button("Export Statistics") {
                    exportStatistics()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Cancel") {
                showingExportSheet = false
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 400)
    }

    // MARK: - Helper Views

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func exportEvents() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "telemetry-events.json"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? telemetryManager.exportEvents(to: url)
                showingExportSheet = false
            }
        }
    }

    private func exportStatistics() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "telemetry-stats.json"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? telemetryManager.exportStatistics(to: url)
                showingExportSheet = false
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(minWidth: 150)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: MetricCategory
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(categoryColor)
                .frame(width: 8, height: 8)

            Text(category.displayName)
                .font(.caption)

            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(categoryColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var categoryColor: Color {
        switch category {
        case .capsLock:
            return .blue
        case .scroll:
            return .green
        case .displayLayouts:
            return .purple
        case .permissions:
            return .orange
        case .general:
            return .gray
        }
    }
}

// MARK: - Aggregate Row

struct AggregateRow: View {
    let aggregate: MetricAggregate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(aggregate.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(aggregate.type.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(aggregate.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("occurrences")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let first = aggregate.firstOccurrence, let last = aggregate.lastOccurrence {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("First:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(formatTimestamp(first))
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Text("Last:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(formatTimestamp(last))
                            .font(.caption)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct TelemetryViewerView_Previews: PreviewProvider {
    static var previews: some View {
        TelemetryViewerView()
    }
}

import SwiftUI

/// SwiftUI view for viewing and managing logs
public struct LogViewerView: View {
    @ObservedObject private var logManager: LogManager

    @State private var selectedCategory: LogCategory?
    @State private var selectedLevel: LogLevel = .trace
    @State private var searchText: String = ""
    @State private var showingExportSheet = false
    @State private var autoScroll: Bool = true

    public init(logManager: LogManager = .shared) {
        self.logManager = logManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Filters
            filtersView
                .padding()

            Divider()

            // Log list
            logListView

            Divider()

            // Statistics
            statisticsView
                .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showingExportSheet) {
            exportSheet
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Log Viewer")
                    .font(.title)
                    .fontWeight(.bold)

                Text("\(filteredLogs.count) log entries")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Toggle("Auto-scroll", isOn: $autoScroll)

                Button("Export") {
                    showingExportSheet = true
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    logManager.clearMemoryLogs()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var filtersView: some View {
        HStack(spacing: 16) {
            // Category filter
            Picker("Category:", selection: $selectedCategory) {
                Text("All Categories").tag(nil as LogCategory?)
                ForEach(LogCategory.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category as LogCategory?)
                }
            }
            .frame(width: 200)

            // Level filter
            Picker("Min Level:", selection: $selectedLevel) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .frame(width: 150)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredLogs) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: filteredLogs.count) { _ in
                if autoScroll, let lastLog = filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var statisticsView: some View {
        let stats = logManager.getStatistics()

        return VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 20) {
                StatChip(label: "Total", count: stats.totalCount, color: .gray)
                StatChip(label: "Info", count: stats.infoCount, color: .blue)
                StatChip(label: "Warning", count: stats.warningCount, color: .orange)
                StatChip(label: "Error", count: stats.errorCount, color: .red)
                StatChip(label: "Critical", count: stats.criticalCount, color: .purple)

                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var exportSheet: some View {
        VStack(spacing: 20) {
            Text("Export Logs")
                .font(.headline)

            Text("Choose export format")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("Export as Text") {
                    exportAsText()
                }
                .buttonStyle(.borderedProminent)

                Button("Export as JSON") {
                    exportAsJSON()
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

    // MARK: - Computed Properties

    private var filteredLogs: [LogEntry] {
        var logs = logManager.recentLogs

        // Filter by category
        if let category = selectedCategory {
            logs = logs.filter { $0.category == category }
        }

        // Filter by minimum level
        logs = logs.filter { $0.level >= selectedLevel }

        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }

        return logs
    }

    // MARK: - Export Methods

    private func exportAsText() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "mactools-logs.txt"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? logManager.exportLogs(to: url)
                showingExportSheet = false
            }
        }
    }

    private func exportAsJSON() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "mactools-logs.json"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? logManager.exportLogsJSON(to: url)
                showingExportSheet = false
            }
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Level indicator
            levelIndicator
                .frame(width: 8)

            // Timestamp
            Text(formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            // Level badge
            Text(entry.level.displayName.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(levelTextColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(levelBackgroundColor)
                .cornerRadius(4)

            // Category
            Text(entry.category.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(rowBackgroundColor)
        .cornerRadius(4)
    }

    private var levelIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(levelColor)
    }

    private var levelColor: Color {
        switch entry.level {
        case .trace, .debug:
            return .gray
        case .info, .notice:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }

    private var levelTextColor: Color {
        switch entry.level {
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        default:
            return .primary
        }
    }

    private var levelBackgroundColor: Color {
        switch entry.level {
        case .warning:
            return Color.orange.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .critical:
            return Color.purple.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }

    private var rowBackgroundColor: Color {
        switch entry.level {
        case .error, .critical:
            return Color.red.opacity(0.05)
        case .warning:
            return Color.orange.opacity(0.05)
        default:
            return Color.clear
        }
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: entry.timestamp)
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

struct LogViewerView_Previews: PreviewProvider {
    static var previews: some View {
        LogViewerView()
    }
}

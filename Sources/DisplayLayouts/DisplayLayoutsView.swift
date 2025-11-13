import SwiftUI

/// Main view for DisplayLayouts management
public struct DisplayLayoutsView: View {
    @StateObject private var viewModel: DisplayLayoutsViewModel

    @State private var showingCreatePreset = false
    @State private var newPresetName = ""
    @State private var showingRenamePreset: WindowLayoutPreset?
    @State private var renamePresetName = ""

    public init(viewModel: DisplayLayoutsViewModel = DisplayLayoutsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Content
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else if !viewModel.checkAccessibilityPermissions() {
                permissionsView
            } else {
                contentView
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $showingCreatePreset) {
            createPresetSheet
        }
        .sheet(item: $showingRenamePreset) { preset in
            renamePresetSheet(preset: preset)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Display Layouts")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Manage window layouts per display configuration")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                // Undo/Redo buttons
                HStack(spacing: 4) {
                    Button(action: viewModel.undo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16))
                    }
                    .disabled(!viewModel.canUndo)
                    .help(viewModel.canUndo ? "Undo: \(viewModel.undoActionName ?? "")" : "Undo")

                    Button(action: viewModel.redo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 16))
                    }
                    .disabled(!viewModel.canRedo)
                    .help(viewModel.canRedo ? "Redo: \(viewModel.redoActionName ?? "")" : "Redo")
                }

                Divider()
                    .frame(height: 20)

                Toggle("Auto-apply", isOn: $viewModel.autoApplyEnabled)
                    .onChange(of: viewModel.autoApplyEnabled) { _ in
                        viewModel.toggleAutoApply()
                    }

                Button(action: viewModel.refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                }
                .help("Refresh")
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading display configuration...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Dismiss") {
                viewModel.clearError()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var permissionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Accessibility Permissions Required")
                .font(.headline)

            Text("DisplayLayouts needs accessibility permissions to enumerate and move windows.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Grant Permissions") {
                viewModel.requestAccessibilityPermissions()
            }
            .buttonStyle(.borderedProminent)

            Text("After granting permissions, click Refresh")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Display configuration section
                displayConfigurationSection

                Divider()

                // Presets section
                presetsSection

                Divider()

                // Windows section
                windowsSection
            }
            .padding()
        }
    }

    private var displayConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Display Configuration")
                .font(.headline)

            if let config = viewModel.currentConfiguration {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration ID: \(config.signature)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(config.count) display(s) detected")
                        .font(.subheadline)

                    ForEach(viewModel.displayInfo) { display in
                        HStack {
                            Image(systemName: display.isMain ? "display.2" : "display")
                                .foregroundColor(display.isMain ? .blue : .secondary)

                            VStack(alignment: .leading) {
                                Text(display.name)
                                    .font(.subheadline)

                                Text("\(Int(display.bounds.width))×\(Int(display.bounds.height)) @ \(display.scale, specifier: "%.1f")x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if display.isMain {
                                Spacer()
                                Text("Main")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                Text("No display configuration available")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Layout Presets")
                    .font(.headline)

                Spacer()

                Button(action: { showingCreatePreset = true }) {
                    Label("Create Preset", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if viewModel.presets.isEmpty {
                Text("No presets for this display configuration")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.presets, id: \.name) { preset in
                    PresetRow(
                        preset: preset,
                        info: viewModel.getPresetInfo(preset),
                        onApply: {
                            viewModel.applyPreset(preset)
                        },
                        onRename: {
                            showingRenamePreset = preset
                            renamePresetName = preset.name
                        },
                        onDelete: {
                            viewModel.deletePreset(preset)
                        }
                    )
                }
            }

            if let result = viewModel.lastApplyResult {
                applyResultView(result)
            }
        }
    }

    private func applyResultView(_ result: WindowLayoutBatchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if result.allSucceeded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Successfully applied all window layouts")
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(result.successCount) succeeded, \(result.failureCount) failed")
                }

                Spacer()

                Button("Dismiss") {
                    viewModel.clearLastResult()
                }
                .buttonStyle(.plain)
            }

            if !result.allSucceeded {
                ForEach(result.failures, id: \.windowID.stableID) { failure in
                    Text("• \(failure.windowID.title): \(failure.error?.localizedDescription ?? "Unknown error")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(result.allSucceeded ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private var windowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Windows")
                .font(.headline)

            Text("\(viewModel.allWindows.count) windows detected")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if viewModel.allWindows.isEmpty {
                Text("No windows available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.applications, id: \.bundleIdentifier) { app in
                    applicationWindowsSection(app: app)
                }
            }
        }
    }

    private func applicationWindowsSection(app: ApplicationIdentifier) -> some View {
        let windows = viewModel.windowsByApplication[app] ?? []

        return VStack(alignment: .leading, spacing: 4) {
            Text(app.name)
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(windows, id: \.identifier.stableID) { window in
                HStack {
                    Text(window.identifier.title.isEmpty ? "(Untitled)" : window.identifier.title)
                        .font(.caption)

                    Spacer()

                    if window.isMinimized {
                        Text("Minimized")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if window.isHidden {
                        Text("Hidden")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(Int(window.frame.width))×\(Int(window.frame.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Sheets

    private var createPresetSheet: some View {
        VStack(spacing: 20) {
            Text("Create Layout Preset")
                .font(.headline)

            TextField("Preset Name", text: $newPresetName)
                .textFieldStyle(.roundedBorder)

            Text("This will capture the current positions of all visible windows")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("Cancel") {
                    showingCreatePreset = false
                    newPresetName = ""
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    viewModel.createPreset(name: newPresetName)
                    showingCreatePreset = false
                    newPresetName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPresetName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func renamePresetSheet(preset: WindowLayoutPreset) -> some View {
        VStack(spacing: 20) {
            Text("Rename Preset")
                .font(.headline)

            TextField("New Name", text: $renamePresetName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showingRenamePreset = nil
                    renamePresetName = ""
                }
                .buttonStyle(.bordered)

                Button("Rename") {
                    viewModel.renamePreset(preset, to: renamePresetName)
                    showingRenamePreset = nil
                    renamePresetName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(renamePresetName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Preset Row

struct PresetRow: View {
    let preset: WindowLayoutPreset
    let info: DisplayLayoutsViewModel.PresetInfo
    let onApply: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(preset.name)
                        .font(.headline)

                    Text("\(preset.windowCount) windows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !info.isValid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .help("Some windows may not be available")
                }

                Button(action: onApply) {
                    Text("Apply")
                }
                .buttonStyle(.borderedProminent)

                Menu {
                    Button("Rename", action: onRename)
                    Button("Delete", action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()

                    Text("Created: \(preset.createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Modified: \(preset.modifiedAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !info.isValid {
                        if case .missingWindows(let windows) = info.validationResult {
                            Text("Missing \(windows.count) window(s)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct DisplayLayoutsView_Previews: PreviewProvider {
    static var previews: some View {
        DisplayLayoutsView()
    }
}

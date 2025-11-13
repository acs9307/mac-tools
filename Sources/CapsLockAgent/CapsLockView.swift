import SwiftUI

/// Main view for Caps Lock settings
public struct CapsLockView: View {
    @StateObject private var viewModel: CapsLockViewModel

    public init(viewModel: CapsLockViewModel = CapsLockViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Content
            if let error = viewModel.error {
                errorView(error)
            } else if !viewModel.hasAccessibilityPermissions {
                permissionsView
            } else {
                contentView
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            viewModel.loadConfiguration()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Caps Lock Remapping")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Configure Caps Lock key behavior")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            statusIndicator
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            Text(viewModel.statusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
    }

    private var statusColor: Color {
        switch viewModel.statusColor {
        case .active:
            return .green
        case .inactive:
            return .gray
        case .warning:
            return .orange
        case .error:
            return .red
        }
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

            Text("Caps Lock remapping needs accessibility permissions to intercept and modify key events.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Grant Permissions") {
                viewModel.requestPermissions()
            }
            .buttonStyle(.borderedProminent)

            Text("After granting permissions, restart the application")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Enable/Disable section
                enableSection

                Divider()

                // Delay configuration
                delaySection

                Divider()

                // Key actions section
                keyActionsSection

                Divider()

                // Additional options
                optionsSection

                Divider()

                // Agent control
                agentControlSection
            }
            .padding()
        }
    }

    private var enableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activation")
                .font(.headline)

            Toggle("Enable Caps Lock Remapping", isOn: $viewModel.enabled)
                .onChange(of: viewModel.enabled) { _ in
                    viewModel.toggleEnabled()
                }

            Text("When enabled, Caps Lock behavior will be modified based on press duration")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var delaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Press Duration Threshold")
                .font(.headline)

            HStack {
                Text("Delay:")
                    .frame(width: 80, alignment: .leading)

                Slider(
                    value: $viewModel.minPressDuration,
                    in: 0.05...2.0,
                    step: 0.05
                ) { _ in
                    viewModel.setMinPressDuration(viewModel.minPressDuration)
                }

                Text(String(format: "%.2fs", viewModel.minPressDuration))
                    .frame(width: 60, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))

                HStack(spacing: 4) {
                    Button(action: viewModel.decrementDelay) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Decrease delay")

                    Button(action: viewModel.incrementDelay) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Increase delay")
                }
            }

            Text("Presses shorter than this duration trigger the quick tap action. Longer presses trigger the long press action.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var keyActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Actions")
                .font(.headline)

            // Quick tap action
            HStack {
                Text("Quick Tap:")
                    .frame(width: 100, alignment: .leading)

                Picker("", selection: $viewModel.quickTapAction) {
                    ForEach(CapsLockViewModel.availableQuickTapActions, id: \.action) { item in
                        Text(item.name).tag(item.action)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
                .onChange(of: viewModel.quickTapAction) { _ in
                    viewModel.setQuickTapAction(viewModel.quickTapAction)
                }

                Text("(< \(String(format: "%.2fs", viewModel.minPressDuration)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Long press action
            HStack {
                Text("Long Press:")
                    .frame(width: 100, alignment: .leading)

                Picker("", selection: $viewModel.longPressAction) {
                    ForEach(CapsLockViewModel.availableLongPressActions, id: \.action) { item in
                        Text(item.name).tag(item.action)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
                .onChange(of: viewModel.longPressAction) { _ in
                    viewModel.setLongPressAction(viewModel.longPressAction)
                }

                Text("(≥ \(String(format: "%.2fs", viewModel.minPressDuration)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Choose what happens when Caps Lock is pressed quickly vs held down")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)

            Toggle("Disable Original Caps Lock", isOn: $viewModel.disableCapsLock)
                .onChange(of: viewModel.disableCapsLock) { _ in
                    viewModel.toggleDisableCapsLock()
                }

            Text("When enabled, the original Caps Lock functionality is completely disabled")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var agentControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agent Control")
                .font(.headline)

            HStack {
                if viewModel.isAgentRunning {
                    Text("Agent is running")
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Restart Agent") {
                        viewModel.restartAgent()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("Agent is not running")
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Start Agent") {
                        viewModel.startAgent()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Text("The agent must be running for Caps Lock remapping to work")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct CapsLockView_Previews: PreviewProvider {
    static var previews: some View {
        CapsLockView()
    }
}

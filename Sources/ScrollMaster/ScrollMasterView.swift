import SwiftUI

/// Main settings view for ScrollMaster
public struct ScrollMasterView: View {
    @StateObject private var viewModel: ScrollMasterViewModel

    public init(viewModel: ScrollMasterViewModel = ScrollMasterViewModel()) {
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
            } else {
                contentView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            viewModel.refreshDevices()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("ScrollMaster")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Per-device scroll behavior configuration")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: viewModel.refreshDevices) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16))
            }
            .help("Refresh device list")
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading devices...")
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

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Default configuration section
                defaultConfigurationSection

                Divider()

                // Device list section
                deviceListSection
            }
            .padding()
        }
    }

    private var defaultConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Default Configuration")
                .font(.headline)

            Text("Applied to devices without specific configuration")
                .font(.caption)
                .foregroundColor(.secondary)

            DefaultTransformEditor(transform: $viewModel.defaultTransform) { newTransform in
                viewModel.updateDefaultTransform(newTransform)
            }

            Divider()

            Text("Smooth Scroll Parameters")
                .font(.headline)
                .padding(.top, 8)

            SmoothScrollParametersEditor(
                parameters: $viewModel.smoothScrollParameters
            ) { newParams in
                viewModel.updateSmoothScrollParameters(newParams)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var deviceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Devices")
                .font(.headline)

            if viewModel.devices.isEmpty {
                emptyDeviceListView
            } else {
                ForEach(viewModel.devices) { device in
                    DeviceRow(
                        device: device,
                        onToggleInvertVertical: {
                            viewModel.toggleInvertVertical(for: device.id)
                        },
                        onToggleInvertHorizontal: {
                            viewModel.toggleInvertHorizontal(for: device.id)
                        },
                        onToggleSmoothScroll: {
                            viewModel.toggleSmoothScroll(for: device.id)
                        },
                        onSetVerticalMultiplier: { value in
                            viewModel.setVerticalMultiplier(for: device.id, value: value)
                        },
                        onSetHorizontalMultiplier: { value in
                            viewModel.setHorizontalMultiplier(for: device.id, value: value)
                        },
                        onToggleEnabled: {
                            viewModel.toggleEnabled(for: device.id)
                        },
                        onReset: {
                            viewModel.resetDevice(device.id)
                        }
                    )
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyDeviceListView: some View {
        VStack(spacing: 12) {
            Image(systemName: "computermouse")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No pointing devices detected")
                .foregroundColor(.secondary)

            Text("Connect a mouse or trackpad to configure it")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: ScrollMasterViewModel.DeviceInfo
    let onToggleInvertVertical: () -> Void
    let onToggleInvertHorizontal: () -> Void
    let onToggleSmoothScroll: () -> Void
    let onSetVerticalMultiplier: (Double) -> Void
    let onSetHorizontalMultiplier: (Double) -> Void
    let onToggleEnabled: () -> Void
    let onReset: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "computermouse.fill")
                    .foregroundColor(device.configuration.enabled ? .blue : .secondary)

                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)

                    Text("Vendor: 0x\(String(format: "%04X", device.vendorID)) Product: 0x\(String(format: "%04X", device.productID))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: .constant(device.configuration.enabled))
                    .labelsHidden()
                    .onChange(of: device.configuration.enabled) { _ in
                        onToggleEnabled()
                    }
                    .onTapGesture {
                        onToggleEnabled()
                    }

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }

            // Expanded details
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()

                    // Inversion toggles
                    HStack {
                        Toggle("Invert Vertical", isOn: .constant(device.configuration.transform.invertVertical))
                            .onChange(of: device.configuration.transform.invertVertical) { _ in
                                onToggleInvertVertical()
                            }
                            .onTapGesture {
                                onToggleInvertVertical()
                            }

                        Toggle("Invert Horizontal", isOn: .constant(device.configuration.transform.invertHorizontal))
                            .onChange(of: device.configuration.transform.invertHorizontal) { _ in
                                onToggleInvertHorizontal()
                            }
                            .onTapGesture {
                                onToggleInvertHorizontal()
                            }
                    }

                    // Multipliers
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Vertical Speed:")
                                .frame(width: 120, alignment: .leading)

                            Slider(
                                value: .constant(device.configuration.transform.verticalMultiplier),
                                in: 0.1...5.0,
                                step: 0.1
                            ) { _ in
                                onSetVerticalMultiplier(device.configuration.transform.verticalMultiplier)
                            }

                            Text(String(format: "%.1fx", device.configuration.transform.verticalMultiplier))
                                .frame(width: 40, alignment: .trailing)
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Horizontal Speed:")
                                .frame(width: 120, alignment: .leading)

                            Slider(
                                value: .constant(device.configuration.transform.horizontalMultiplier),
                                in: 0.1...5.0,
                                step: 0.1
                            ) { _ in
                                onSetHorizontalMultiplier(device.configuration.transform.horizontalMultiplier)
                            }

                            Text(String(format: "%.1fx", device.configuration.transform.horizontalMultiplier))
                                .frame(width: 40, alignment: .trailing)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    // Smooth scroll toggle
                    Toggle("Smooth Scrolling", isOn: .constant(device.configuration.transform.smoothScrollEnabled))
                        .onChange(of: device.configuration.transform.smoothScrollEnabled) { _ in
                            onToggleSmoothScroll()
                        }
                        .onTapGesture {
                            onToggleSmoothScroll()
                        }

                    // Reset button
                    HStack {
                        Spacer()

                        Button("Reset to Defaults") {
                            onReset()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Default Transform Editor

struct DefaultTransformEditor: View {
    @Binding var transform: ScrollTransform
    let onUpdate: (ScrollTransform) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Invert Vertical", isOn: $transform.invertVertical)
                    .onChange(of: transform.invertVertical) { _ in
                        onUpdate(transform)
                    }

                Toggle("Invert Horizontal", isOn: $transform.invertHorizontal)
                    .onChange(of: transform.invertHorizontal) { _ in
                        onUpdate(transform)
                    }
            }

            HStack {
                Text("Vertical Speed:")
                    .frame(width: 120, alignment: .leading)

                Slider(value: $transform.verticalMultiplier, in: 0.1...5.0, step: 0.1)
                    .onChange(of: transform.verticalMultiplier) { _ in
                        onUpdate(transform)
                    }

                Text(String(format: "%.1fx", transform.verticalMultiplier))
                    .frame(width: 40, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Horizontal Speed:")
                    .frame(width: 120, alignment: .leading)

                Slider(value: $transform.horizontalMultiplier, in: 0.1...5.0, step: 0.1)
                    .onChange(of: transform.horizontalMultiplier) { _ in
                        onUpdate(transform)
                    }

                Text(String(format: "%.1fx", transform.horizontalMultiplier))
                    .frame(width: 40, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }

            Toggle("Smooth Scrolling", isOn: $transform.smoothScrollEnabled)
                .onChange(of: transform.smoothScrollEnabled) { _ in
                    onUpdate(transform)
                }
        }
    }
}

// MARK: - Smooth Scroll Parameters Editor

struct SmoothScrollParametersEditor: View {
    @Binding var parameters: SmoothScrollParameters
    let onUpdate: (SmoothScrollParameters) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Duration:")
                    .frame(width: 120, alignment: .leading)

                Slider(value: $parameters.duration, in: 0.1...2.0, step: 0.05)
                    .onChange(of: parameters.duration) { _ in
                        onUpdate(parameters)
                    }

                Text(String(format: "%.2fs", parameters.duration))
                    .frame(width: 50, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Curve:")
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: $parameters.curve) {
                    Text("Linear").tag(InterpolationCurve.linear)
                    Text("Ease In").tag(InterpolationCurve.easeIn)
                    Text("Ease Out").tag(InterpolationCurve.easeOut)
                    Text("Ease In/Out").tag(InterpolationCurve.easeInOut)
                }
                .labelsHidden()
                .onChange(of: parameters.curve) { _ in
                    onUpdate(parameters)
                }
            }

            HStack {
                Text("Distance Multiplier:")
                    .frame(width: 120, alignment: .leading)

                Slider(value: $parameters.distanceMultiplier, in: 0.1...3.0, step: 0.1)
                    .onChange(of: parameters.distanceMultiplier) { _ in
                        onUpdate(parameters)
                    }

                Text(String(format: "%.1fx", parameters.distanceMultiplier))
                    .frame(width: 50, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Minimum Delta:")
                    .frame(width: 120, alignment: .leading)

                Slider(value: $parameters.minimumDelta, in: 0.001...0.1, step: 0.001)
                    .onChange(of: parameters.minimumDelta) { _ in
                        onUpdate(parameters)
                    }

                Text(String(format: "%.3f", parameters.minimumDelta))
                    .frame(width: 50, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
}

// MARK: - Preview

struct ScrollMasterView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollMasterView()
    }
}

import Foundation
import Combine
import MacToolsCore

/// View model for DisplayLayouts UI
@MainActor
public final class DisplayLayoutsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public private(set) var currentConfiguration: DisplayConfiguration?
    @Published public private(set) var presets: [WindowLayoutPreset] = []
    @Published public private(set) var allWindows: [WindowInfo] = []
    @Published public var autoApplyEnabled: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: String?
    @Published public private(set) var lastApplyResult: WindowLayoutBatchResult?

    // MARK: - Dependencies

    private let windowManager: WindowManager
    private let displayEnumerator: DisplayEnumerator
    private let presetManager: WindowLayoutPresetManager
    private let presetCapture: LayoutPresetCapture
    private let automation: LayoutPresetAutomation

    // MARK: - Initialization

    public init(
        windowManager: WindowManager = WindowManager(),
        displayEnumerator: DisplayEnumerator = DisplayEnumerator(),
        presetManager: WindowLayoutPresetManager = WindowLayoutPresetManager(),
        presetCapture: LayoutPresetCapture? = nil,
        automation: LayoutPresetAutomation? = nil
    ) {
        self.windowManager = windowManager
        self.displayEnumerator = displayEnumerator
        self.presetManager = presetManager
        self.presetCapture = presetCapture ?? LayoutPresetCapture(
            windowManager: windowManager,
            displayEnumerator: displayEnumerator
        )
        self.automation = automation ?? LayoutPresetAutomation(
            windowManager: windowManager,
            presetManager: presetManager
        )

        loadCurrentState()
    }

    // MARK: - State Management

    /// Load current display configuration and presets
    public func loadCurrentState() {
        isLoading = true
        error = nil

        do {
            // Get current display configuration
            currentConfiguration = try displayEnumerator.getCurrentConfiguration()

            // Load presets for this configuration
            if let config = currentConfiguration {
                presets = presetManager.presets(for: config.signature)
            }

            // Enumerate windows
            if windowManager.checkAccessibilityPermissions() {
                allWindows = try windowManager.enumerateAllWindows()
            } else {
                allWindows = []
            }

            isLoading = false
        } catch {
            self.error = "Failed to load state: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Refresh all state
    public func refresh() {
        loadCurrentState()
    }

    // MARK: - Preset Management

    /// Create new preset from current window arrangement
    public func createPreset(name: String, filter: ((WindowInfo) -> Bool)? = nil) {
        guard let config = currentConfiguration else {
            error = "No display configuration available"
            return
        }

        do {
            let preset = try presetCapture.captureCurrentLayout(name: name, filter: filter)
            presetManager.store(preset)

            // Reload presets
            presets = presetManager.presets(for: config.signature)
            error = nil
        } catch {
            self.error = "Failed to create preset: \(error.localizedDescription)"
        }
    }

    /// Create preset for specific applications
    public func createPreset(name: String, forApplications bundleIDs: [String]) {
        guard let config = currentConfiguration else {
            error = "No display configuration available"
            return
        }

        do {
            let preset = try presetCapture.captureLayout(
                name: name,
                forApplications: bundleIDs
            )
            presetManager.store(preset)

            presets = presetManager.presets(for: config.signature)
            error = nil
        } catch {
            self.error = "Failed to create preset: \(error.localizedDescription)"
        }
    }

    /// Delete a preset
    public func deletePreset(_ preset: WindowLayoutPreset) {
        guard let config = currentConfiguration else {
            error = "No display configuration available"
            return
        }

        presetManager.remove(presetNamed: preset.name, for: config.signature)
        presets = presetManager.presets(for: config.signature)
    }

    /// Rename a preset
    public func renamePreset(_ preset: WindowLayoutPreset, to newName: String) {
        guard let config = currentConfiguration else {
            error = "No display configuration available"
            return
        }

        // Create new preset with updated name
        var updated = preset
        updated = WindowLayoutPreset(
            name: newName,
            displayConfigSignature: preset.displayConfigSignature,
            layouts: preset.layouts,
            createdAt: preset.createdAt,
            modifiedAt: Date()
        )

        // Remove old and store new
        presetManager.remove(presetNamed: preset.name, for: config.signature)
        presetManager.store(updated)

        presets = presetManager.presets(for: config.signature)
    }

    // MARK: - Preset Application

    /// Apply a preset
    public func applyPreset(_ preset: WindowLayoutPreset) {
        error = nil

        let result = windowManager.applyPreset(preset)
        lastApplyResult = result

        if result.allSucceeded {
            error = nil
        } else {
            error = "Some windows failed to apply: \(result.failureCount) of \(result.results.count)"
        }
    }

    /// Simulate preset application (validate without applying)
    public func simulatePresetApplication(_ preset: WindowLayoutPreset) -> PresetValidation.ValidationResult {
        return PresetValidation.validate(preset: preset, windowManager: windowManager)
    }

    /// Apply preset for current configuration
    public func applyCurrentPreset() {
        guard let config = currentConfiguration else {
            error = "No display configuration available"
            return
        }

        guard let preset = presets.first else {
            error = "No presets available for this configuration"
            return
        }

        applyPreset(preset)
    }

    // MARK: - Automation

    /// Toggle auto-apply
    public func toggleAutoApply() {
        if autoApplyEnabled {
            automation.stopAutomation()
            autoApplyEnabled = false
        } else {
            automation.startAutomation()
            autoApplyEnabled = true
        }
    }

    /// Set auto-apply delay
    public func setAutoApplyDelay(_ delay: TimeInterval) {
        automation.applyDelay = delay
    }

    // MARK: - Window Information

    /// Get windows grouped by application
    public var windowsByApplication: [ApplicationIdentifier: [WindowInfo]] {
        var grouped: [ApplicationIdentifier: [WindowInfo]] = [:]
        for window in allWindows {
            var windows = grouped[window.identifier.application] ?? []
            windows.append(window)
            grouped[window.identifier.application] = windows
        }
        return grouped
    }

    /// Get all unique applications
    public var applications: [ApplicationIdentifier] {
        return Array(windowsByApplication.keys).sorted { $0.name < $1.name }
    }

    // MARK: - Accessibility

    /// Check accessibility permissions
    public func checkAccessibilityPermissions() -> Bool {
        return windowManager.checkAccessibilityPermissions()
    }

    /// Request accessibility permissions
    public func requestAccessibilityPermissions() {
        windowManager.requestAccessibilityPermissions()
    }

    // MARK: - Error Handling

    /// Clear error
    public func clearError() {
        error = nil
    }

    /// Clear last apply result
    public func clearLastResult() {
        lastApplyResult = nil
    }
}

// MARK: - Display Info

extension DisplayLayoutsViewModel {
    /// Get display information for UI
    public struct DisplayInfo: Identifiable {
        public let id: String
        public let name: String
        public let bounds: DisplayBounds
        public let scale: Double
        public let isMain: Bool

        public init(from display: DisplayIdentity) {
            self.id = display.stableID
            self.name = display.name
            self.bounds = display.bounds
            self.scale = display.scale
            self.isMain = display.isMain
        }
    }

    /// Get display info for current configuration
    public var displayInfo: [DisplayInfo] {
        return currentConfiguration?.displays.map { DisplayInfo(from: $0) } ?? []
    }
}

// MARK: - Preset Info

extension DisplayLayoutsViewModel {
    /// Preset information for UI
    public struct PresetInfo: Identifiable {
        public let id: String
        public let name: String
        public let windowCount: Int
        public let createdAt: Date
        public let modifiedAt: Date
        public let validationResult: PresetValidation.ValidationResult?

        public init(from preset: WindowLayoutPreset, validationResult: PresetValidation.ValidationResult? = nil) {
            self.id = preset.name
            self.name = preset.name
            self.windowCount = preset.windowCount
            self.createdAt = preset.createdAt
            self.modifiedAt = preset.modifiedAt
            self.validationResult = validationResult
        }

        public var isValid: Bool {
            return validationResult?.isValid ?? true
        }
    }

    /// Get preset info for UI
    public func getPresetInfo(_ preset: WindowLayoutPreset) -> PresetInfo {
        let validation = simulatePresetApplication(preset)
        return PresetInfo(from: preset, validationResult: validation)
    }
}

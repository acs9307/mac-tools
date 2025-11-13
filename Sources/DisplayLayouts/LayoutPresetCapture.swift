import Foundation
import Logging

/// Captures current window arrangements and creates presets
public final class LayoutPresetCapture {
    private let logger = Logger(label: "com.mactools.presetcapture")
    private let windowManager: WindowManager
    private let displayEnumerator: DisplayEnumerator

    public init(
        windowManager: WindowManager = WindowManager(),
        displayEnumerator: DisplayEnumerator = DisplayEnumerator()
    ) {
        self.windowManager = windowManager
        self.displayEnumerator = displayEnumerator
    }

    // MARK: - Capture

    /// Capture current window arrangement as a preset
    /// - Parameters:
    ///   - name: Name for the preset
    ///   - filter: Optional filter to include only specific windows
    /// - Returns: Window layout preset
    public func captureCurrentLayout(
        name: String,
        filter: ((WindowInfo) -> Bool)? = nil
    ) throws -> WindowLayoutPreset {
        logger.info("Capturing current window layout as preset '\(name)'")

        // Get current display configuration
        let displayConfig = try displayEnumerator.getCurrentConfiguration()
        logger.debug("Current display configuration: \(displayConfig.signature)")

        // Enumerate all windows
        let allWindows = try windowManager.enumerateAllWindows()
        logger.debug("Found \(allWindows.count) windows")

        // Apply filter if provided
        let windowsToCapture = filter.map { allWindows.filter($0) } ?? allWindows

        // Filter out minimized and hidden windows by default
        let visibleWindows = windowsToCapture.filter { !$0.isMinimized && !$0.isHidden }
        logger.debug("Capturing \(visibleWindows.count) visible windows")

        // Create layout specs
        var layouts: [WindowLayoutSpec] = []
        for window in visibleWindows {
            // Determine which display the window is on
            let displayID = findDisplayForWindow(window, in: displayConfig)

            let spec = WindowLayoutSpec(
                windowID: window.identifier,
                targetFrame: window.frame,
                displayID: displayID,
                restoreIfMinimized: true,
                unhideIfHidden: true
            )

            layouts.append(spec)
        }

        logger.info("Created preset '\(name)' with \(layouts.count) window layouts")

        return WindowLayoutPreset(
            name: name,
            displayConfigSignature: displayConfig.signature,
            layouts: layouts
        )
    }

    /// Capture layout for specific applications
    /// - Parameters:
    ///   - name: Name for the preset
    ///   - bundleIdentifiers: Bundle IDs to include
    /// - Returns: Window layout preset
    public func captureLayout(
        name: String,
        forApplications bundleIdentifiers: [String]
    ) throws -> WindowLayoutPreset {
        return try captureCurrentLayout(name: name) { window in
            bundleIdentifiers.contains(window.identifier.application.bundleIdentifier)
        }
    }

    /// Capture layout excluding specific applications
    /// - Parameters:
    ///   - name: Name for the preset
    ///   - bundleIdentifiers: Bundle IDs to exclude
    /// - Returns: Window layout preset
    public func captureLayout(
        name: String,
        excludingApplications bundleIdentifiers: [String]
    ) throws -> WindowLayoutPreset {
        return try captureCurrentLayout(name: name) { window in
            !bundleIdentifiers.contains(window.identifier.application.bundleIdentifier)
        }
    }

    // MARK: - Private Helpers

    private func findDisplayForWindow(
        _ window: WindowInfo,
        in configuration: DisplayConfiguration
    ) -> String? {
        let windowCenter = window.frame.center

        // Find display containing window center
        for display in configuration.displays {
            if display.bounds.cgRect.contains(windowCenter) {
                return display.stableID
            }
        }

        // If center not in any display, find display with most overlap
        var maxOverlap: Double = 0
        var bestDisplay: DisplayIdentity?

        for display in configuration.displays {
            let overlap = calculateOverlap(window.frame.cgRect, with: display.bounds.cgRect)
            if overlap > maxOverlap {
                maxOverlap = overlap
                bestDisplay = display
            }
        }

        return bestDisplay?.stableID
    }

    private func calculateOverlap(_ rect1: CGRect, with rect2: CGRect) -> Double {
        let intersection = rect1.intersection(rect2)
        return intersection.width * intersection.height
    }
}

/// Manages automatic preset application
public final class LayoutPresetAutomation {
    private let logger = Logger(label: "com.mactools.presetautomation")
    private let windowManager: WindowManager
    private let presetManager: WindowLayoutPresetManager
    private let changeListener: DisplayChangeListener

    /// Whether auto-apply is enabled
    public var autoApplyEnabled: Bool = false

    /// Delay before applying preset after display change (seconds)
    public var applyDelay: TimeInterval = 2.0

    private var applyTimer: Timer?
    private var pendingConfiguration: DisplayConfiguration?

    public init(
        windowManager: WindowManager = WindowManager(),
        presetManager: WindowLayoutPresetManager = WindowLayoutPresetManager(),
        changeListener: DisplayChangeListener? = nil
    ) {
        self.windowManager = windowManager
        self.presetManager = presetManager

        // Create change listener if not provided
        if let listener = changeListener {
            self.changeListener = listener
        } else {
            self.changeListener = DisplayChangeListener(handler: DummyHandler())
        }
    }

    // MARK: - Automation Control

    /// Start automatic preset application
    public func startAutomation() {
        guard !changeListener.isActive else {
            logger.debug("Automation already started")
            return
        }

        logger.info("Starting layout preset automation")
        autoApplyEnabled = true

        // Note: In a real implementation, we would set up the listener properly
        // For now, this is a placeholder for the architecture
        changeListener.startListening()
    }

    /// Stop automatic preset application
    public func stopAutomation() {
        logger.info("Stopping layout preset automation")
        autoApplyEnabled = false
        changeListener.stopListening()
        cancelPendingApply()
    }

    /// Manually trigger preset application for current configuration
    public func applyPresetForCurrentConfiguration() throws -> WindowLayoutBatchResult? {
        let enumerator = DisplayEnumerator()
        let config = try enumerator.getCurrentConfiguration()
        return applyPreset(for: config)
    }

    /// Apply preset for a specific display configuration
    public func applyPreset(for configuration: DisplayConfiguration) -> WindowLayoutBatchResult? {
        logger.info("Looking for preset for configuration: \(configuration.signature)")

        let presets = presetManager.presets(for: configuration.signature)
        guard let preset = presets.first else {
            logger.warning("No preset found for configuration \(configuration.signature)")
            return nil
        }

        logger.info("Applying preset '\(preset.name)' with \(preset.windowCount) windows")
        let result = windowManager.applyPreset(preset)

        logger.info("Applied preset: \(result.successCount) succeeded, \(result.failureCount) failed")

        if result.failureCount > 0 {
            for failure in result.failures {
                logger.warning("Failed to apply layout for \(failure.windowID.stableID): \(failure.error?.localizedDescription ?? "unknown error")")
            }
        }

        return result
    }

    // MARK: - Display Change Handling

    /// Handle display configuration change (called by listener)
    public func handleConfigurationChange(_ configuration: DisplayConfiguration) {
        guard autoApplyEnabled else {
            logger.debug("Auto-apply disabled, ignoring configuration change")
            return
        }

        logger.info("Display configuration changed, scheduling preset application")

        // Cancel any pending apply
        cancelPendingApply()

        // Store pending configuration
        pendingConfiguration = configuration

        // Schedule delayed apply
        applyTimer = Timer.scheduledTimer(
            withTimeInterval: applyDelay,
            repeats: false
        ) { [weak self] _ in
            self?.executePendingApply()
        }
    }

    private func executePendingApply() {
        guard let config = pendingConfiguration else { return }

        logger.info("Executing delayed preset application")

        if let result = applyPreset(for: config) {
            if result.allSucceeded {
                logger.info("Successfully applied all window layouts")
            } else {
                logger.warning("Some window layouts failed to apply")
            }
        }

        pendingConfiguration = nil
    }

    private func cancelPendingApply() {
        applyTimer?.invalidate()
        applyTimer = nil
        pendingConfiguration = nil
    }
}

/// Preset validation
public struct PresetValidation {
    /// Validation result
    public enum ValidationResult {
        case valid
        case missingWindows([WindowIdentifier])
        case missingApplications([ApplicationIdentifier])
        case invalidFrames([WindowLayoutSpec])
        case empty

        /// Whether validation passed
        public var isValid: Bool {
            if case .valid = self {
                return true
            }
            return false
        }
    }

    /// Validate a preset against current system state
    /// - Parameter preset: Preset to validate
    /// - Returns: Validation result
    public static func validate(
        preset: WindowLayoutPreset,
        windowManager: WindowManager = WindowManager()
    ) -> ValidationResult {
        // Check if preset is empty
        if preset.layouts.isEmpty {
            return .empty
        }

        var missingWindows: [WindowIdentifier] = []
        var missingApps: Set<ApplicationIdentifier> = []
        var invalidFrames: [WindowLayoutSpec] = []

        for layout in preset.layouts {
            // Check if window exists
            do {
                let windows = try windowManager.findWindows(matching: layout.windowID)
                if windows.isEmpty {
                    missingWindows.append(layout.windowID)
                    missingApps.insert(layout.windowID.application)
                }
            } catch {
                missingApps.insert(layout.windowID.application)
            }

            // Validate frame
            if layout.targetFrame.width <= 0 || layout.targetFrame.height <= 0 {
                invalidFrames.append(layout)
            }
        }

        // Return most specific error
        if !invalidFrames.isEmpty {
            return .invalidFrames(invalidFrames)
        }

        if !missingWindows.isEmpty {
            return .missingWindows(missingWindows)
        }

        if !missingApps.isEmpty {
            return .missingApplications(Array(missingApps))
        }

        return .valid
    }
}

// MARK: - Dummy Handler for Automation

private class DummyHandler: DisplayChangeHandler {
    func displayConfigurationDidChange(_ configuration: DisplayConfiguration) {
        // Placeholder - in real implementation, this would be wired to automation
    }
}

import Foundation
import ApplicationServices
import Cocoa
import Logging

/// Manages window enumeration and manipulation using Accessibility APIs
public final class WindowManager {
    private let logger = Logger(label: "com.mactools.windowmanager")

    public init() {}

    // MARK: - Accessibility Check

    /// Check if accessibility permissions are granted
    public func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Request accessibility permissions (shows system dialog)
    public func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Window Enumeration

    /// Enumerate all windows from all applications
    public func enumerateAllWindows() throws -> [WindowInfo] {
        guard checkAccessibilityPermissions() else {
            throw WindowError.accessibilityNotEnabled
        }

        var allWindows: [WindowInfo] = []

        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard app.activationPolicy == .regular else { continue }

            do {
                let windows = try enumerateWindows(for: app)
                allWindows.append(contentsOf: windows)
            } catch {
                logger.debug("Failed to enumerate windows for \(app.localizedName ?? "unknown"): \(error)")
            }
        }

        return allWindows
    }

    /// Enumerate windows for a specific application
    public func enumerateWindows(for application: NSRunningApplication) throws -> [WindowInfo] {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        let bundleID = application.bundleIdentifier ?? "unknown"
        let appName = application.localizedName ?? "Unknown"
        let appIdentifier = ApplicationIdentifier(
            bundleIdentifier: bundleID,
            name: appName
        )

        var windowInfos: [WindowInfo] = []
        for (index, window) in windows.enumerated() {
            if let info = extractWindowInfo(
                from: window,
                application: appIdentifier,
                processID: application.processIdentifier,
                index: index
            ) {
                windowInfos.append(info)
            }
        }

        return windowInfos
    }

    /// Find windows matching a window identifier
    public func findWindows(matching identifier: WindowIdentifier) throws -> [WindowInfo] {
        let allWindows = try enumerateAllWindows()
        return allWindows.filter { windowInfo in
            windowInfo.identifier.application.bundleIdentifier == identifier.application.bundleIdentifier &&
            windowInfo.identifier.title == identifier.title
        }
    }

    // MARK: - Window Manipulation

    /// Set window frame
    public func setWindowFrame(_ frame: WindowFrame, for window: AXUIElement) throws {
        // Set position
        var position = CGPoint(x: frame.x, y: frame.y)
        let positionValue = AXValueCreate(.cgPoint, &position)!

        var positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )

        // Set size
        var size = CGSize(width: frame.width, height: frame.height)
        let sizeValue = AXValueCreate(.cgSize, &size)!

        var sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        if positionResult != .success || sizeResult != .success {
            throw WindowError.operationFailed("Failed to set window frame")
        }
    }

    /// Apply layout to a window
    public func applyLayout(_ layout: WindowLayoutSpec) throws -> WindowLayoutResult {
        // Find the window
        let windows = try findWindows(matching: layout.windowID)
        guard let windowInfo = windows.first else {
            return WindowLayoutResult(
                windowID: layout.windowID,
                success: false,
                error: WindowError.windowNotFound(layout.windowID)
            )
        }

        // Get AXUIElement for the window
        guard let windowElement = try? getWindowElement(for: windowInfo) else {
            return WindowLayoutResult(
                windowID: layout.windowID,
                success: false,
                error: WindowError.operationFailed("Could not access window element")
            )
        }

        let previousFrame = windowInfo.frame

        // Restore from minimized if needed
        if windowInfo.isMinimized && layout.restoreIfMinimized {
            try? setMinimized(false, for: windowElement)
        }

        // Unhide if needed
        if windowInfo.isHidden && layout.unhideIfHidden {
            // Raise application
            if let app = NSRunningApplication(processIdentifier: windowInfo.processID) {
                app.activate(options: [])
            }
        }

        // Apply the frame
        do {
            try setWindowFrame(layout.targetFrame, for: windowElement)

            return WindowLayoutResult(
                windowID: layout.windowID,
                success: true,
                error: nil,
                previousFrame: previousFrame,
                newFrame: layout.targetFrame
            )
        } catch {
            return WindowLayoutResult(
                windowID: layout.windowID,
                success: false,
                error: error,
                previousFrame: previousFrame,
                newFrame: nil
            )
        }
    }

    /// Apply multiple layouts
    public func applyLayouts(_ layouts: [WindowLayoutSpec]) -> WindowLayoutBatchResult {
        var results: [WindowLayoutResult] = []

        for layout in layouts {
            do {
                let result = try applyLayout(layout)
                results.append(result)
            } catch {
                results.append(WindowLayoutResult(
                    windowID: layout.windowID,
                    success: false,
                    error: error
                ))
            }
        }

        return WindowLayoutBatchResult(results: results)
    }

    /// Apply a preset
    public func applyPreset(_ preset: WindowLayoutPreset) -> WindowLayoutBatchResult {
        logger.info("Applying window layout preset: \(preset.name) (\(preset.windowCount) windows)")
        let result = applyLayouts(preset.layouts)
        logger.info("Applied preset: \(result.successCount) succeeded, \(result.failureCount) failed")
        return result
    }

    // MARK: - Window State

    /// Get current window frame
    public func getWindowFrame(_ window: AXUIElement) -> WindowFrame? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        let posResult = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionRef
        )

        let sizeResult = AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeRef
        )

        guard posResult == .success, sizeResult == .success,
              let posValue = positionRef,
              let sizeValue = sizeRef else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        return WindowFrame(x: position.x, y: position.y, width: size.width, height: size.height)
    }

    /// Set window minimized state
    public func setMinimized(_ minimized: Bool, for window: AXUIElement) throws {
        let result = AXUIElementSetAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            minimized as CFBoolean
        )

        if result != .success {
            throw WindowError.operationFailed("Failed to set minimized state")
        }
    }

    /// Check if window is minimized
    public func isMinimized(_ window: AXUIElement) -> Bool {
        var minimizedRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            &minimizedRef
        )

        guard result == .success, let minimized = minimizedRef as? Bool else {
            return false
        }

        return minimized
    }

    // MARK: - Private Helpers

    private func extractWindowInfo(
        from window: AXUIElement,
        application: ApplicationIdentifier,
        processID: pid_t,
        index: Int
    ) -> WindowInfo? {
        // Get title
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String ?? ""

        // Get role
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
        let roleString = roleRef as? String ?? "AXUnknown"
        let role = WindowRole(rawValue: roleString) ?? .unknown

        // Skip non-standard windows unless they're dialogs
        if role == .unknown && title.isEmpty {
            return nil
        }

        // Get frame
        guard let frame = getWindowFrame(window) else {
            return nil
        }

        // Get minimized state
        let minimized = isMinimized(window)

        // Create identifier
        let identifier = WindowIdentifier(
            application: application,
            title: title,
            role: role,
            index: title.isEmpty ? index : nil
        )

        return WindowInfo(
            identifier: identifier,
            frame: frame,
            processID: processID,
            isMinimized: minimized,
            isHidden: false
        )
    }

    private func getWindowElement(for windowInfo: WindowInfo) throws -> AXUIElement {
        let appElement = AXUIElementCreateApplication(windowInfo.processID)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            throw WindowError.windowNotFound(windowInfo.identifier)
        }

        // Find matching window
        for window in windows {
            if let info = extractWindowInfo(
                from: window,
                application: windowInfo.identifier.application,
                processID: windowInfo.processID,
                index: 0
            ), info.identifier.stableID == windowInfo.identifier.stableID {
                return window
            }
        }

        throw WindowError.windowNotFound(windowInfo.identifier)
    }
}

/// Preset storage manager
public final class WindowLayoutPresetManager {
    private var presets: [String: [WindowLayoutPreset]] = [:] // displaySignature -> [presets]
    private let queue = DispatchQueue(label: "com.mactools.presetmanager", attributes: .concurrent)

    public init() {}

    // MARK: - Storage

    /// Store a preset
    public func store(_ preset: WindowLayoutPreset) {
        queue.async(flags: .barrier) {
            var presetsForConfig = self.presets[preset.displayConfigSignature] ?? []

            // Remove existing preset with same name
            presetsForConfig.removeAll { $0.name == preset.name }

            // Add new preset
            presetsForConfig.append(preset)

            self.presets[preset.displayConfigSignature] = presetsForConfig
        }
    }

    /// Get all presets for a display configuration
    public func presets(for displaySignature: String) -> [WindowLayoutPreset] {
        return queue.sync {
            presets[displaySignature] ?? []
        }
    }

    /// Get a specific preset
    public func preset(named name: String, for displaySignature: String) -> WindowLayoutPreset? {
        return queue.sync {
            presets[displaySignature]?.first { $0.name == name }
        }
    }

    /// Remove a preset
    public func remove(presetNamed name: String, for displaySignature: String) {
        queue.async(flags: .barrier) {
            self.presets[displaySignature]?.removeAll { $0.name == name }
        }
    }

    /// Remove all presets for a display configuration
    public func removeAll(for displaySignature: String) {
        queue.async(flags: .barrier) {
            self.presets.removeValue(forKey: displaySignature)
        }
    }

    /// Get all presets
    public func allPresets() -> [String: [WindowLayoutPreset]] {
        return queue.sync {
            presets
        }
    }

    /// Total number of presets
    public var totalCount: Int {
        return queue.sync {
            presets.values.reduce(0) { $0 + $1.count }
        }
    }
}

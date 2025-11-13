import Foundation
import Logging

/// Manages undo/redo for window layout changes
public final class LayoutUndoManager {
    private let logger = Logger(label: "com.mactools.layoutundo")
    private let windowManager: WindowManager

    /// Maximum number of undo states to keep
    public var maxUndoStates: Int = 10

    /// Stack of previous window states
    private var undoStack: [LayoutSnapshot] = []

    /// Stack of redone states
    private var redoStack: [LayoutSnapshot] = []

    private let queue = DispatchQueue(label: "com.mactools.layoutundo", attributes: .concurrent)

    public init(windowManager: WindowManager = WindowManager()) {
        self.windowManager = windowManager
    }

    // MARK: - Snapshot Management

    /// Capture current window layout as a snapshot
    public func captureSnapshot(name: String = "Auto-snapshot") throws -> LayoutSnapshot {
        logger.debug("Capturing layout snapshot: \(name)")

        let allWindows = try windowManager.enumerateAllWindows()

        let states = allWindows.map { window in
            WindowState(
                identifier: window.identifier,
                frame: window.frame,
                isMinimized: window.isMinimized,
                isHidden: window.isHidden
            )
        }

        return LayoutSnapshot(
            name: name,
            timestamp: Date(),
            windowStates: states
        )
    }

    /// Save current state before applying changes
    public func saveStateBeforeChange(name: String = "Before change") throws {
        let snapshot = try captureSnapshot(name: name)

        queue.async(flags: .barrier) {
            self.undoStack.append(snapshot)

            // Limit stack size
            if self.undoStack.count > self.maxUndoStates {
                self.undoStack.removeFirst()
            }

            // Clear redo stack when new change is made
            self.redoStack.removeAll()
        }

        logger.info("Saved undo state: \(name) (\(snapshot.windowStates.count) windows)")
    }

    /// Apply a snapshot (restore windows to saved state)
    public func applySnapshot(_ snapshot: LayoutSnapshot) -> WindowLayoutBatchResult {
        logger.info("Applying snapshot: \(snapshot.name)")

        var results: [WindowLayoutResult] = []

        for windowState in snapshot.windowStates {
            let spec = WindowLayoutSpec(
                windowID: windowState.identifier,
                targetFrame: windowState.frame,
                displayID: nil,
                restoreIfMinimized: !windowState.isMinimized,
                unhideIfHidden: !windowState.isHidden
            )

            do {
                let result = try windowManager.applyLayout(spec)
                results.append(result)
            } catch {
                results.append(WindowLayoutResult(
                    windowID: windowState.identifier,
                    success: false,
                    error: error
                ))
            }
        }

        return WindowLayoutBatchResult(results: results)
    }

    // MARK: - Undo/Redo

    /// Check if undo is available
    public var canUndo: Bool {
        return queue.sync {
            !undoStack.isEmpty
        }
    }

    /// Check if redo is available
    public var canRedo: Bool {
        return queue.sync {
            !redoStack.isEmpty
        }
    }

    /// Get the name of the next undo action
    public var undoActionName: String? {
        return queue.sync {
            undoStack.last?.name
        }
    }

    /// Get the name of the next redo action
    public var redoActionName: String? {
        return queue.sync {
            redoStack.last?.name
        }
    }

    /// Undo last layout change
    public func undo() throws -> WindowLayoutBatchResult {
        let snapshot = try queue.sync { () -> LayoutSnapshot in
            guard let snapshot = undoStack.popLast() else {
                throw LayoutUndoError.noUndoAvailable
            }
            return snapshot
        }

        logger.info("Undoing: \(snapshot.name)")

        // Capture current state for redo
        let currentState = try captureSnapshot(name: "Redo: \(snapshot.name)")

        // Apply the undo snapshot
        let result = applySnapshot(snapshot)

        // If successful, save to redo stack
        if result.allSucceeded || result.successCount > 0 {
            queue.async(flags: .barrier) {
                self.redoStack.append(currentState)
            }
        }

        return result
    }

    /// Redo last undone change
    public func redo() throws -> WindowLayoutBatchResult {
        let snapshot = try queue.sync { () -> LayoutSnapshot in
            guard let snapshot = redoStack.popLast() else {
                throw LayoutUndoError.noRedoAvailable
            }
            return snapshot
        }

        logger.info("Redoing: \(snapshot.name)")

        // Capture current state for undo
        let currentState = try captureSnapshot(name: "Before redo")

        // Apply the redo snapshot
        let result = applySnapshot(snapshot)

        // If successful, save to undo stack
        if result.allSucceeded || result.successCount > 0 {
            queue.async(flags: .barrier) {
                self.undoStack.append(currentState)
            }
        }

        return result
    }

    // MARK: - Stack Management

    /// Clear undo history
    public func clearUndoHistory() {
        queue.async(flags: .barrier) {
            self.undoStack.removeAll()
        }
        logger.info("Cleared undo history")
    }

    /// Clear redo history
    public func clearRedoHistory() {
        queue.async(flags: .barrier) {
            self.redoStack.removeAll()
        }
        logger.info("Cleared redo history")
    }

    /// Clear all history
    public func clearAll() {
        queue.async(flags: .barrier) {
            self.undoStack.removeAll()
            self.redoStack.removeAll()
        }
        logger.info("Cleared all undo/redo history")
    }

    /// Get number of undo states
    public var undoCount: Int {
        return queue.sync {
            undoStack.count
        }
    }

    /// Get number of redo states
    public var redoCount: Int {
        return queue.sync {
            redoStack.count
        }
    }
}

// MARK: - Layout Snapshot

/// Represents a snapshot of window layout at a point in time
public struct LayoutSnapshot: Codable {
    /// Name/description of this snapshot
    public let name: String

    /// Timestamp when snapshot was taken
    public let timestamp: Date

    /// Window states in this snapshot
    public let windowStates: [WindowState]

    public init(name: String, timestamp: Date, windowStates: [WindowState]) {
        self.name = name
        self.timestamp = timestamp
        self.windowStates = windowStates
    }
}

/// Represents the state of a single window
public struct WindowState: Codable {
    /// Window identifier
    public let identifier: WindowIdentifier

    /// Window frame
    public let frame: WindowFrame

    /// Whether window was minimized
    public let isMinimized: Bool

    /// Whether window was hidden
    public let isHidden: Bool

    public init(
        identifier: WindowIdentifier,
        frame: WindowFrame,
        isMinimized: Bool,
        isHidden: Bool
    ) {
        self.identifier = identifier
        self.frame = frame
        self.isMinimized = isMinimized
        self.isHidden = isHidden
    }
}

// MARK: - Errors

public enum LayoutUndoError: Error, LocalizedError {
    case noUndoAvailable
    case noRedoAvailable
    case snapshotFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noUndoAvailable:
            return "No undo actions available"
        case .noRedoAvailable:
            return "No redo actions available"
        case .snapshotFailed(let reason):
            return "Failed to capture snapshot: \(reason)"
        }
    }
}

// MARK: - Enhanced Automation with Undo

extension LayoutPresetAutomation {
    /// Apply preset with undo support
    public func applyPresetWithUndo(
        _ preset: WindowLayoutPreset,
        undoManager: LayoutUndoManager
    ) -> (result: WindowLayoutBatchResult, undoSaved: Bool) {
        var undoSaved = false

        // Try to save current state for undo
        do {
            try undoManager.saveStateBeforeChange(name: "Before applying '\(preset.name)'")
            undoSaved = true
        } catch {
            // Continue anyway, but note that undo won't be available
        }

        // Apply the preset
        let result = windowManager.applyPreset(preset)

        return (result, undoSaved)
    }

    /// Apply preset for configuration with undo support
    public func applyPresetWithUndo(
        for configuration: DisplayConfiguration,
        undoManager: LayoutUndoManager
    ) -> (result: WindowLayoutBatchResult?, undoSaved: Bool) {
        guard let preset = presetManager.presets(for: configuration.signature).first else {
            return (nil, false)
        }

        return applyPresetWithUndo(preset, undoManager: undoManager)
    }
}

// MARK: - Safety Mechanisms

/// Safety checks for window layout operations
public final class LayoutSafetyChecker {
    private let logger = Logger(label: "com.mactools.layoutsafety")

    public init() {}

    // MARK: - Validation

    /// Check if a frame is safe to apply
    public func isSafeFrame(_ frame: WindowFrame, for displays: [DisplayIdentity]) -> Bool {
        // Check for valid dimensions
        guard frame.width > 0 && frame.height > 0 else {
            logger.warning("Invalid frame dimensions: \(frame.width)x\(frame.height)")
            return false
        }

        // Check for reasonable size (not too small or too large)
        let minSize = 100.0
        let maxSize = 10000.0

        if frame.width < minSize || frame.height < minSize {
            logger.warning("Frame too small: \(frame.width)x\(frame.height)")
            return false
        }

        if frame.width > maxSize || frame.height > maxSize {
            logger.warning("Frame too large: \(frame.width)x\(frame.height)")
            return false
        }

        // Check if frame is within display bounds (at least partially)
        let frameRect = frame.cgRect
        let isVisible = displays.contains { display in
            frameRect.intersects(display.bounds.cgRect)
        }

        if !isVisible {
            logger.warning("Frame not visible on any display")
        }

        return isVisible
    }

    /// Validate preset safety
    public func validatePresetSafety(
        _ preset: WindowLayoutPreset,
        displays: [DisplayIdentity]
    ) -> SafetyValidationResult {
        var unsafeFrames: [WindowLayoutSpec] = []
        var offscreenWindows: [WindowLayoutSpec] = []

        for layout in preset.layouts {
            if !isSafeFrame(layout.targetFrame, for: displays) {
                unsafeFrames.append(layout)
            }

            // Check if completely offscreen
            let isCompletelyOffscreen = displays.allSatisfy { display in
                !display.bounds.cgRect.intersects(layout.targetFrame.cgRect)
            }

            if isCompletelyOffscreen {
                offscreenWindows.append(layout)
            }
        }

        if unsafeFrames.isEmpty {
            return .safe
        } else {
            return .unsafe(unsafeFrames: unsafeFrames, offscreenWindows: offscreenWindows)
        }
    }

    /// Safety validation result
    public enum SafetyValidationResult {
        case safe
        case unsafe(unsafeFrames: [WindowLayoutSpec], offscreenWindows: [WindowLayoutSpec])

        public var isSafe: Bool {
            if case .safe = self {
                return true
            }
            return false
        }
    }

    // MARK: - Auto-correction

    /// Attempt to correct unsafe frames
    public func correctFrame(
        _ frame: WindowFrame,
        for displays: [DisplayIdentity]
    ) -> WindowFrame? {
        guard !displays.isEmpty else { return nil }

        // Find the main display or first display
        let targetDisplay = displays.first { $0.isMain } ?? displays.first!
        let displayBounds = targetDisplay.bounds

        // Ensure minimum size
        var corrected = frame
        corrected = WindowFrame(
            x: corrected.x,
            y: corrected.y,
            width: max(corrected.width, 200),
            height: max(corrected.height, 200)
        )

        // Clamp to display bounds if completely offscreen
        if !displayBounds.cgRect.intersects(corrected.cgRect) {
            // Move window onto display
            var newX = corrected.x
            var newY = corrected.y

            // Ensure window is at least partially on screen
            if newX + corrected.width < displayBounds.x {
                newX = displayBounds.x
            } else if newX > displayBounds.x + displayBounds.width {
                newX = displayBounds.x + displayBounds.width - corrected.width
            }

            if newY + corrected.height < displayBounds.y {
                newY = displayBounds.y
            } else if newY > displayBounds.y + displayBounds.height {
                newY = displayBounds.y + displayBounds.height - corrected.height
            }

            corrected = WindowFrame(
                x: newX,
                y: newY,
                width: corrected.width,
                height: corrected.height
            )
        }

        return corrected
    }
}

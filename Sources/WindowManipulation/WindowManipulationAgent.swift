import Foundation
import MacToolsCore
import ApplicationServices

/// Agent for handling window manipulation operations
public final class WindowManipulationAgent: BaseAgent {
    private var animationsEnabled: Bool = true
    private var animationDuration: TimeInterval = 0.2

    public init() {
        super.init(identifier: "window.manipulation", name: "Window Manipulation")
    }

    override public func performStart() throws {
        logger.info("Starting window manipulation agent")

        // Verify accessibility permissions
        guard PermissionsManager.shared.checkAccessibilityPermissions() else {
            throw AgentError.permissionDenied(
                "Accessibility permissions required for window manipulation. " +
                "Please grant permissions in System Settings > Privacy & Security > Accessibility"
            )
        }

        // Load configuration
        animationsEnabled = Configuration.shared.get(
            "windowManipulation.animations",
            default: true
        )
        animationDuration = Configuration.shared.get(
            "windowManipulation.animationDuration",
            default: 0.2
        )

        logger.info("Window manipulation agent started successfully")
    }

    override public func performStop() throws {
        logger.info("Stopping window manipulation agent")
        logger.info("Window manipulation agent stopped successfully")
    }

    override public func configure(_ config: [String: Any]) async throws {
        try await super.configure(config)

        if let animations = config["animations"] as? Bool {
            animationsEnabled = animations
            logger.info("Animations \(animations ? "enabled" : "disabled")")
        }

        if let duration = config["animationDuration"] as? TimeInterval {
            animationDuration = duration
            logger.info("Animation duration set to \(duration)s")
        }
    }

    // MARK: - Window Operations

    /// Get all visible windows across all applications
    public func getAllWindows() throws -> [Window] {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        let applications = getRunningApplications()
        return applications.flatMap { $0.windows }
    }

    /// Get windows for a specific application
    public func getWindows(forApplication bundleIdentifier: String) throws -> [Window] {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        guard let app = getApplication(bundleIdentifier: bundleIdentifier) else {
            throw AgentError.configurationError("Application not found: \(bundleIdentifier)")
        }

        return app.windows
    }

    /// Get the currently focused window
    public func getFocusedWindow() throws -> Window? {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        // Get the active application
        let workspace = NSWorkspace.shared
        guard let activeApp = workspace.frontmostApplication else {
            return nil
        }

        let app = Application(pid: activeApp.processIdentifier)
        return app.focusedWindow
    }

    /// Move a window to a specific position
    public func moveWindow(_ window: Window, to position: CGPoint) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        var mutableWindow = window
        mutableWindow.position = position
        logger.debug("Moved window \(window.id) to \(position)")
    }

    /// Resize a window to a specific size
    public func resizeWindow(_ window: Window, to size: CGSize) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        var mutableWindow = window
        mutableWindow.size = size
        logger.debug("Resized window \(window.id) to \(size)")
    }

    /// Set a window's frame (position and size)
    public func setWindowFrame(_ window: Window, to frame: CGRect) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        var mutableWindow = window
        mutableWindow.setFrame(frame, animate: animationsEnabled)
        logger.debug("Set window \(window.id) frame to \(frame)")
    }

    /// Focus a specific window
    public func focusWindow(_ window: Window) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        var mutableWindow = window
        guard mutableWindow.focus() else {
            throw AgentError.unsupported("Failed to focus window \(window.id)")
        }

        logger.debug("Focused window \(window.id)")
    }

    /// Minimize a window
    public func minimizeWindow(_ window: Window) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        var mutableWindow = window
        guard mutableWindow.minimize() else {
            throw AgentError.unsupported("Failed to minimize window \(window.id)")
        }

        logger.debug("Minimized window \(window.id)")
    }

    // MARK: - Window Arrangement Presets

    /// Arrange a window to fill the left half of the screen
    public func arrangeWindowLeftHalf(_ window: Window) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        guard let screen = getMainScreen() else {
            throw AgentError.unsupported("Could not get main screen")
        }

        let frame = CGRect(
            x: screen.origin.x,
            y: screen.origin.y,
            width: screen.width / 2,
            height: screen.height
        )

        try setWindowFrame(window, to: frame)
        logger.debug("Arranged window \(window.id) to left half")
    }

    /// Arrange a window to fill the right half of the screen
    public func arrangeWindowRightHalf(_ window: Window) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        guard let screen = getMainScreen() else {
            throw AgentError.unsupported("Could not get main screen")
        }

        let frame = CGRect(
            x: screen.origin.x + screen.width / 2,
            y: screen.origin.y,
            width: screen.width / 2,
            height: screen.height
        )

        try setWindowFrame(window, to: frame)
        logger.debug("Arranged window \(window.id) to right half")
    }

    /// Maximize a window to fill the screen
    public func maximizeWindow(_ window: Window) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        guard let screen = getMainScreen() else {
            throw AgentError.unsupported("Could not get main screen")
        }

        try setWindowFrame(window, to: screen)
        logger.debug("Maximized window \(window.id)")
    }

    /// Center a window on the screen
    public func centerWindow(_ window: Window) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        guard let screen = getMainScreen(),
              let windowSize = window.size else {
            throw AgentError.unsupported("Could not get window or screen dimensions")
        }

        let position = CGPoint(
            x: screen.origin.x + (screen.width - windowSize.width) / 2,
            y: screen.origin.y + (screen.height - windowSize.height) / 2
        )

        try moveWindow(window, to: position)
        logger.debug("Centered window \(window.id)")
    }

    // MARK: - Helper Methods

    private func getMainScreen() -> CGRect? {
        guard let screen = NSScreen.main else {
            return nil
        }

        return screen.visibleFrame
    }
}

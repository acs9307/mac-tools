import Foundation
import ApplicationServices

/// Represents a running application
public struct Application: Equatable {
    /// The process identifier
    public let pid: pid_t

    /// The AXUIElement reference for the application
    internal let axApplication: AXUIElement

    internal init(pid: pid_t) {
        self.pid = pid
        self.axApplication = AXUIElementCreateApplication(pid)
    }

    /// Get the application's name
    public var name: String? {
        let runningApp = NSRunningApplication(processIdentifier: pid)
        return runningApp?.localizedName
    }

    /// Get the application's bundle identifier
    public var bundleIdentifier: String? {
        let runningApp = NSRunningApplication(processIdentifier: pid)
        return runningApp?.bundleIdentifier
    }

    /// Get all windows for this application
    public var windows: [Window] {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            axApplication,
            kAXWindowsAttribute as CFString,
            &value
        )

        guard result == .success,
              let windowList = value as? [AXUIElement] else {
            return []
        }

        return windowList.enumerated().compactMap { index, axWindow in
            // Try to get the window ID
            var windowID: CGWindowID = 0
            let idResult = _AXUIElementGetWindow(axWindow, &windowID)

            // If we can't get the ID, use a synthetic one based on index
            if idResult != .success {
                windowID = CGWindowID(pid * 10000 + index)
            }

            return Window(id: windowID, axWindow: axWindow, application: self)
        }
    }

    /// Get the focused window for this application
    public var focusedWindow: Window? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            axApplication,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        guard result == .success, let axWindow = value else {
            return nil
        }

        var windowID: CGWindowID = 0
        _AXUIElementGetWindow(axWindow as! AXUIElement, &windowID)

        return Window(id: windowID, axWindow: axWindow as! AXUIElement, application: self)
    }

    /// Check if the application is active (frontmost)
    public var isActive: Bool {
        let runningApp = NSRunningApplication(processIdentifier: pid)
        return runningApp?.isActive ?? false
    }

    /// Activate (bring to front) the application
    @discardableResult
    public func activate() -> Bool {
        let runningApp = NSRunningApplication(processIdentifier: pid)
        return runningApp?.activate(options: [.activateIgnoringOtherApps]) ?? false
    }

    /// Hide the application
    @discardableResult
    public func hide() -> Bool {
        let runningApp = NSRunningApplication(processIdentifier: pid)
        return runningApp?.hide() ?? false
    }

    public static func == (lhs: Application, rhs: Application) -> Bool {
        return lhs.pid == rhs.pid
    }
}

/// Get all running applications
public func getRunningApplications() -> [Application] {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    return runningApps.compactMap { app in
        let pid = app.processIdentifier
        guard pid > 0 else { return nil }
        return Application(pid: pid)
    }
}

/// Get an application by bundle identifier
public func getApplication(bundleIdentifier: String) -> Application? {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
        return nil
    }

    return Application(pid: app.processIdentifier)
}

/// Get an application by name
public func getApplication(name: String) -> Application? {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    guard let app = runningApps.first(where: { $0.localizedName == name }) else {
        return nil
    }

    return Application(pid: app.processIdentifier)
}

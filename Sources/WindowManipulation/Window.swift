import Foundation
import ApplicationServices

/// Represents a window on the system
public struct Window: Equatable {
    /// The window identifier
    public let id: CGWindowID

    /// The AXUIElement reference for the window
    internal let axWindow: AXUIElement

    /// The application that owns the window
    public let application: Application

    internal init(id: CGWindowID, axWindow: AXUIElement, application: Application) {
        self.id = id
        self.axWindow = axWindow
        self.application = application
    }

    /// Get the window's title
    public var title: String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &value)

        guard result == .success, let title = value as? String else {
            return nil
        }

        return title
    }

    /// Get the window's position
    public var position: CGPoint? {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &value)

            guard result == .success, let axValue = value else {
                return nil
            }

            var point = CGPoint.zero
            guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else {
                return nil
            }

            return point
        }
        set {
            guard let newValue = newValue else { return }

            var point = newValue
            guard let axValue = AXValueCreate(.cgPoint, &point) else { return }

            AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, axValue)
        }
    }

    /// Get or set the window's size
    public var size: CGSize? {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &value)

            guard result == .success, let axValue = value else {
                return nil
            }

            var size = CGSize.zero
            guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else {
                return nil
            }

            return size
        }
        set {
            guard let newValue = newValue else { return }

            var size = newValue
            guard let axValue = AXValueCreate(.cgSize, &size) else { return }

            AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, axValue)
        }
    }

    /// Get the window's frame (position and size)
    public var frame: CGRect? {
        guard let position = position, let size = size else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    /// Set the window's frame (position and size)
    public func setFrame(_ frame: CGRect, animate: Bool = false) {
        if animate {
            // TODO: Add animation support
            position = frame.origin
            size = frame.size
        } else {
            position = frame.origin
            size = frame.size
        }
    }

    /// Focus the window
    public func focus() -> Bool {
        let result = AXUIElementSetAttributeValue(
            axWindow,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )

        return result == .success
    }

    /// Minimize the window
    public func minimize() -> Bool {
        let result = AXUIElementSetAttributeValue(
            axWindow,
            kAXMinimizedAttribute as CFString,
            kCFBooleanTrue
        )

        return result == .success
    }

    /// Check if the window is minimized
    public var isMinimized: Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            axWindow,
            kAXMinimizedAttribute as CFString,
            &value
        )

        guard result == .success, let minimized = value as? Bool else {
            return false
        }

        return minimized
    }

    /// Check if the window is focused
    public var isFocused: Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            axWindow,
            kAXMainAttribute as CFString,
            &value
        )

        guard result == .success, let focused = value as? Bool else {
            return false
        }

        return focused
    }

    public static func == (lhs: Window, rhs: Window) -> Bool {
        return lhs.id == rhs.id
    }
}

import Foundation
import CoreGraphics
import Logging

/// Errors that can occur during event tap operations
public enum EventTapError: Error, LocalizedError {
    case creationFailed
    case accessibilityPermissionDenied
    case tapDisabled

    public var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Failed to create event tap"
        case .accessibilityPermissionDenied:
            return "Accessibility permissions not granted"
        case .tapDisabled:
            return "Event tap was disabled by the system"
        }
    }
}

/// Manages the lifecycle of a CGEventTap for keyboard event interception
public final class EventTapManager {
    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let callback: (CGEvent) -> CGEvent?
    private let logger: Logger
    private var isEnabled = false

    // MARK: - Initialization

    /// Initialize with an event callback
    /// - Parameters:
    ///   - callback: Closure called for each keyboard event. Return nil to suppress the event, or a modified event to pass through.
    ///   - logger: Logger for debugging and error reporting
    public init(
        callback: @escaping (CGEvent) -> CGEvent?,
        logger: Logger = Logger(label: "com.mactools.eventtap")
    ) {
        self.callback = callback
        self.logger = logger
    }

    deinit {
        stop()
    }

    // MARK: - Public Interface

    /// Start the event tap
    public func start() throws {
        guard !isEnabled else {
            logger.warning("Event tap already running")
            return
        }

        // Check accessibility permissions
        guard checkAccessibilityPermission() else {
            throw EventTapError.accessibilityPermissionDenied
        }

        // Create event mask for keyboard events
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        // Create the event tap
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                // Extract self from refcon
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            logger.error("Failed to create event tap")
            throw EventTapError.creationFailed
        }

        eventTap = tap

        // Create run loop source and add to current run loop
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)
        isEnabled = true

        logger.info("Event tap started successfully")
    }

    /// Stop the event tap
    public func stop() {
        guard isEnabled else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        isEnabled = false
        logger.info("Event tap stopped")
    }

    /// Check if the event tap is currently running
    public var running: Bool {
        isEnabled
    }

    // MARK: - Private Methods

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Handle tap disabled by system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logger.warning("Event tap disabled by system, re-enabling")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Process the event through callback
        if let result = callback(event) {
            return Unmanaged.passUnretained(result)
        } else {
            // Callback returned nil, suppress the event
            return nil
        }
    }

    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrusted(options)
    }
}

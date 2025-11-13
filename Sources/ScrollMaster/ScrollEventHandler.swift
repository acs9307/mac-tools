import Foundation
import CoreGraphics
import Logging

/// Callback type for scroll event processing
public typealias ScrollEventCallback = (ScrollEvent) -> ScrollEvent?

/// Errors that can occur during scroll event handling
public enum ScrollEventHandlerError: Error, LocalizedError {
    case eventTapCreationFailed
    case accessibilityPermissionDenied
    case alreadyRunning
    case notRunning

    public var errorDescription: String? {
        switch self {
        case .eventTapCreationFailed:
            return "Failed to create scroll event tap"
        case .accessibilityPermissionDenied:
            return "Accessibility permissions not granted"
        case .alreadyRunning:
            return "Scroll event handler is already running"
        case .notRunning:
            return "Scroll event handler is not running"
        }
    }
}

/// Handles scroll event interception and transformation
public final class ScrollEventHandler {
    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let callback: ScrollEventCallback
    private let logger: Logger
    private var isRunning = false

    // MARK: - Initialization

    /// Initialize with a scroll event callback
    /// - Parameters:
    ///   - callback: Closure called for each scroll event. Return nil to suppress, or modified event to pass through.
    ///   - logger: Logger for debugging
    public init(
        callback: @escaping ScrollEventCallback,
        logger: Logger = Logger(label: "com.mactools.scroll")
    ) {
        self.callback = callback
        self.logger = logger
    }

    deinit {
        stop()
    }

    // MARK: - Public Interface

    /// Start intercepting scroll events
    public func start() throws {
        guard !isRunning else {
            throw ScrollEventHandlerError.alreadyRunning
        }

        // Check accessibility permissions
        guard checkAccessibilityPermission() else {
            throw ScrollEventHandlerError.accessibilityPermissionDenied
        }

        // Create event mask for scroll wheel events
        let eventMask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)

        // Create the event tap
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                let handler = Unmanaged<ScrollEventHandler>.fromOpaque(refcon!).takeUnretainedValue()
                return handler.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            logger.error("Failed to create scroll event tap")
            throw ScrollEventHandlerError.eventTapCreationFailed
        }

        eventTap = tap

        // Create run loop source and add to current run loop
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true

        logger.info("Scroll event handler started")
    }

    /// Stop intercepting scroll events
    public func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        isRunning = false
        logger.info("Scroll event handler stopped")
    }

    /// Check if the handler is currently running
    public var running: Bool {
        isRunning
    }

    // MARK: - Private Methods

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Handle tap disabled by system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logger.warning("Scroll event tap disabled by system, re-enabling")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        // Extract scroll deltas
        let verticalDelta = Double(event.getDoubleValueField(.scrollWheelEventDeltaAxis1))
        let horizontalDelta = Double(event.getDoubleValueField(.scrollWheelEventDeltaAxis2))

        // Check if continuous (trackpad-style) or discrete (mouse wheel)
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0

        // Try to get device ID (may not always be available)
        // In a real implementation, we'd need to track the source device
        let deviceID: String? = nil // TODO: Map to device identity

        // Create scroll event
        let scrollEvent = ScrollEvent(
            deviceID: deviceID,
            verticalDelta: verticalDelta,
            horizontalDelta: horizontalDelta,
            timestamp: Date.timeIntervalSinceReferenceDate,
            isContinuous: isContinuous
        )

        logger.debug("Scroll event: vertical=\(verticalDelta), horizontal=\(horizontalDelta), continuous=\(isContinuous)")

        // Process through callback
        guard let transformedEvent = callback(scrollEvent) else {
            // Callback returned nil, suppress the event
            logger.debug("Scroll event suppressed")
            return nil
        }

        // Apply transformed deltas back to event
        if transformedEvent.verticalDelta != verticalDelta ||
           transformedEvent.horizontalDelta != horizontalDelta {
            event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: transformedEvent.verticalDelta)
            event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: transformedEvent.horizontalDelta)

            logger.debug("Transformed scroll: vertical=\(transformedEvent.verticalDelta), horizontal=\(transformedEvent.horizontalDelta)")
        }

        return Unmanaged.passUnretained(event)
    }

    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrusted(options)
    }
}

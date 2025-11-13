import Foundation
import Carbon

/// Represents a global hotkey
public final class Hotkey {
    public let identifier: String
    public let keyCode: KeyCode
    public let handler: () -> Void

    private var eventHotKeyRef: EventHotKeyRef?
    private var isRegistered = false

    public init(identifier: String, keyCode: KeyCode, handler: @escaping () -> Void) {
        self.identifier = identifier
        self.keyCode = keyCode
        self.handler = handler
    }

    deinit {
        unregister()
    }

    /// Register the hotkey with the system
    /// - Returns: true if registration succeeded, false otherwise
    public func register() -> Bool {
        guard !isRegistered else { return true }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(identifier.hashValue)
        hotKeyID.id = UInt32(identifier.hashValue)

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        // Convert modifiers to Carbon format
        var carbonModifiers: UInt32 = 0
        if keyCode.modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if keyCode.modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if keyCode.modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if keyCode.modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode.code),
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            eventHotKeyRef = ref
            isRegistered = true
            HotkeyManager.shared.register(self)
            return true
        }

        return false
    }

    /// Unregister the hotkey from the system
    public func unregister() {
        guard isRegistered, let ref = eventHotKeyRef else { return }

        UnregisterEventHotKey(ref)
        eventHotKeyRef = nil
        isRegistered = false
        HotkeyManager.shared.unregister(self)
    }

    internal func trigger() {
        handler()
    }
}

/// Manages all registered hotkeys
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private var hotkeys: [String: Hotkey] = [:]
    private var eventHandler: EventHandlerRef?

    private init() {
        setupEventHandler()
    }

    deinit {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    internal func register(_ hotkey: Hotkey) {
        hotkeys[hotkey.identifier] = hotkey
    }

    internal func unregister(_ hotkey: Hotkey) {
        hotkeys.removeValue(forKey: hotkey.identifier)
    }

    /// Register a new hotkey
    /// - Parameters:
    ///   - identifier: Unique identifier for the hotkey
    ///   - keyCode: The key combination
    ///   - handler: Closure to execute when hotkey is pressed
    /// - Returns: The created Hotkey instance, or nil if registration failed
    @discardableResult
    public func registerHotkey(
        identifier: String,
        keyCode: KeyCode,
        handler: @escaping () -> Void
    ) -> Hotkey? {
        // Unregister existing hotkey with same identifier
        if let existing = hotkeys[identifier] {
            existing.unregister()
        }

        let hotkey = Hotkey(identifier: identifier, keyCode: keyCode, handler: handler)

        guard hotkey.register() else {
            return nil
        }

        return hotkey
    }

    /// Unregister a hotkey by identifier
    /// - Parameter identifier: The hotkey identifier
    public func unregisterHotkey(_ identifier: String) {
        hotkeys[identifier]?.unregister()
    }

    /// Unregister all hotkeys
    public func unregisterAll() {
        for hotkey in hotkeys.values {
            hotkey.unregister()
        }
    }

    private func setupEventHandler() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        let callback: EventHandlerUPP = { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let result = GetEventParameter(
                event,
                UInt32(kEventParamDirectObject),
                UInt32(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard result == noErr else {
                return OSStatus(eventNotHandledErr)
            }

            // Find and trigger the matching hotkey
            for hotkey in HotkeyManager.shared.hotkeys.values {
                if hotkey.identifier.hashValue == Int(hotKeyID.signature) {
                    hotkey.trigger()
                    return noErr
                }
            }

            return OSStatus(eventNotHandledErr)
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }
}

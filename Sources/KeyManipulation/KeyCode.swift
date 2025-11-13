import Foundation
import Carbon

/// Represents a keyboard key with its code and modifiers
public struct KeyCode: Equatable, Hashable, Codable {
    /// The virtual key code
    public let code: Int

    /// Modifier flags
    public let modifiers: ModifierFlags

    public init(code: Int, modifiers: ModifierFlags = []) {
        self.code = code
        self.modifiers = modifiers
    }

    /// Create a KeyCode from a Carbon key code
    public init(carbonKeyCode: CGKeyCode, modifiers: ModifierFlags = []) {
        self.code = Int(carbonKeyCode)
        self.modifiers = modifiers
    }
}

/// Modifier flags for keyboard events
public struct ModifierFlags: OptionSet, Codable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = ModifierFlags(rawValue: 1 << 0)
    public static let shift = ModifierFlags(rawValue: 1 << 1)
    public static let option = ModifierFlags(rawValue: 1 << 2)
    public static let control = ModifierFlags(rawValue: 1 << 3)
    public static let function = ModifierFlags(rawValue: 1 << 4)

    /// Convert to CGEventFlags for use with Core Graphics
    public var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []

        if contains(.command) {
            flags.insert(.maskCommand)
        }
        if contains(.shift) {
            flags.insert(.maskShift)
        }
        if contains(.option) {
            flags.insert(.maskAlternate)
        }
        if contains(.control) {
            flags.insert(.maskControl)
        }
        if contains(.function) {
            flags.insert(.maskSecondaryFn)
        }

        return flags
    }

    /// Create ModifierFlags from CGEventFlags
    public init(cgEventFlags: CGEventFlags) {
        var flags: ModifierFlags = []

        if cgEventFlags.contains(.maskCommand) {
            flags.insert(.command)
        }
        if cgEventFlags.contains(.maskShift) {
            flags.insert(.shift)
        }
        if cgEventFlags.contains(.maskAlternate) {
            flags.insert(.option)
        }
        if cgEventFlags.contains(.maskControl) {
            flags.insert(.control)
        }
        if cgEventFlags.contains(.maskSecondaryFn) {
            flags.insert(.function)
        }

        self = flags
    }
}

// Common key codes
extension KeyCode {
    // Letter keys
    public static let a = KeyCode(code: 0)
    public static let s = KeyCode(code: 1)
    public static let d = KeyCode(code: 2)
    public static let f = KeyCode(code: 3)
    public static let h = KeyCode(code: 4)
    public static let g = KeyCode(code: 5)
    public static let z = KeyCode(code: 6)
    public static let x = KeyCode(code: 7)
    public static let c = KeyCode(code: 8)
    public static let v = KeyCode(code: 9)
    public static let b = KeyCode(code: 11)
    public static let q = KeyCode(code: 12)
    public static let w = KeyCode(code: 13)
    public static let e = KeyCode(code: 14)
    public static let r = KeyCode(code: 15)
    public static let y = KeyCode(code: 16)
    public static let t = KeyCode(code: 17)

    // Number keys
    public static let one = KeyCode(code: 18)
    public static let two = KeyCode(code: 19)
    public static let three = KeyCode(code: 20)
    public static let four = KeyCode(code: 21)
    public static let six = KeyCode(code: 22)
    public static let five = KeyCode(code: 23)
    public static let equal = KeyCode(code: 24)
    public static let nine = KeyCode(code: 25)
    public static let seven = KeyCode(code: 26)
    public static let eight = KeyCode(code: 28)
    public static let zero = KeyCode(code: 29)

    // Special keys
    public static let `return` = KeyCode(code: 36)
    public static let tab = KeyCode(code: 48)
    public static let space = KeyCode(code: 49)
    public static let delete = KeyCode(code: 51)
    public static let escape = KeyCode(code: 53)
    public static let leftArrow = KeyCode(code: 123)
    public static let rightArrow = KeyCode(code: 124)
    public static let downArrow = KeyCode(code: 125)
    public static let upArrow = KeyCode(code: 126)
}

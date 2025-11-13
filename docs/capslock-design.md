# Caps Lock Manipulation Design

## Overview

This document describes the design for manipulating Caps Lock key behavior in macOS to provide reduced press delay and configurable key remapping functionality.

## Goals

- Reduce or eliminate Caps Lock activation delay
- Allow configurable Caps Lock behavior (e.g., remap to Escape, Control, or custom actions)
- Support quick tap vs. long press differentiation
- Integrate seamlessly with the existing MacTools daemon architecture
- Minimal performance impact on system-wide keyboard input

## macOS Keyboard Event APIs

### Available Technologies

#### 1. **CGEventTap (Quartz Event Services)**
- **API**: `CGEventTapCreate()` in Core Graphics
- **Capabilities**:
  - Intercept and modify system-wide keyboard events
  - Access to low-level event stream before apps receive them
  - Can suppress original events and synthesize new ones
  - Event types: key down, key up, flags changed
- **Permissions**: Requires **Accessibility** permissions
- **Performance**: Runs in event callback, must be fast to avoid lag
- **Recommended**: ✅ **Primary choice** for this implementation

#### 2. **IOKit HID (IOHID)**
- **API**: `IOHIDManager` and related APIs
- **Capabilities**:
  - Direct access to HID devices at driver level
  - Very low-level control
  - Can intercept events before they reach the event system
- **Permissions**: May require kernel extensions or DriverKit (complex)
- **Performance**: Excellent, but complex to implement
- **Recommended**: ❌ Too low-level, requires kernel access

#### 3. **NSEvent Monitoring**
- **API**: `NSEvent.addGlobalMonitorForEvents()` and `addLocalMonitorForEvents()`
- **Capabilities**:
  - Monitor keyboard events within an application or globally
  - Cannot suppress events (global monitor is read-only)
  - Limited to application context
- **Permissions**: Input Monitoring for global events
- **Recommended**: ❌ Cannot suppress original Caps Lock behavior

### Selected Approach: CGEventTap

**Rationale**:
- System-wide event interception with modification capability
- Well-documented and stable API
- No kernel extensions required
- Appropriate permission level (Accessibility)
- Proven approach used by similar tools (Karabiner-Elements, Hammerspoon)

## Architecture Design

### Component Structure

```
CapsLockAgent (extends BaseAgent)
  ├── EventTapManager
  │   ├── Creates and manages CGEventTap
  │   ├── Handles event callback lifecycle
  │   └── Processes keyboard events
  │
  ├── KeyStateMachine
  │   ├── Tracks Caps Lock key state (down, up, held)
  │   ├── Implements timing logic for quick tap vs. long press
  │   ├── Decides when to trigger remapped actions
  │   └── State transitions with timestamps
  │
  ├── CapsLockConfiguration
  │   ├── minPressDuration (threshold for quick vs. long)
  │   ├── quickTapAction (e.g., send Escape)
  │   ├── longPressAction (e.g., send Control modifier)
  │   ├── enabled (toggle on/off)
  │   └── Load/save from config file
  │
  └── EventSynthesizer
      ├── Synthesizes replacement key events
      ├── Posts events back to event stream
      └── Handles modifier flag management
```

### Event Flow

```
1. User presses Caps Lock
   ↓
2. CGEventTap callback receives keyDown event
   ↓
3. KeyStateMachine records timestamp, transitions to "pressed" state
   ↓
4. Original Caps Lock event is suppressed (return NULL)
   ↓
5. User releases Caps Lock
   ↓
6. CGEventTap callback receives keyUp event
   ↓
7. KeyStateMachine calculates press duration
   ↓
8. If duration < minPressDuration:
   → Quick tap: Synthesize configured key (e.g., Escape)
   Else:
   → Long press: Synthesize configured modifier or action
   ↓
9. EventSynthesizer posts new event to system
   ↓
10. Original Caps Lock keyUp is suppressed
```

### State Machine

```
States:
- IDLE: No Caps Lock interaction
- PRESSED: Caps Lock is currently held down
- RELEASED: Caps Lock was just released, processing action

Transitions:
IDLE --[keyDown]--> PRESSED
  (record timestamp, suppress event)

PRESSED --[keyUp]--> RELEASED
  (calculate duration, determine action)

RELEASED --[action complete]--> IDLE
  (synthesize event, post to system)

PRESSED --[timeout expired]--> LONG_PRESS
  (trigger long-press action if configured)
```

## Implementation Strategy

### 1. LaunchAgent / Background Service

**Decision**: Implement as an **Agent** within the MacTools daemon architecture

**Characteristics**:
- Runs automatically on user login (via existing daemon infrastructure)
- No dock icon, runs in background
- Integrates with existing DaemonManager
- Uses existing Configuration system
- Leverages existing PermissionsManager for Accessibility requests

### 2. Configuration Model

```swift
public struct CapsLockConfiguration: Codable {
    /// Enable/disable Caps Lock manipulation
    var enabled: Bool = true

    /// Minimum press duration in milliseconds to distinguish tap vs. hold
    var minPressDuration: TimeInterval = 0.2  // 200ms

    /// Action for quick tap (< minPressDuration)
    var quickTapAction: KeyAction = .sendKey(.escape)

    /// Action for long press (>= minPressDuration)
    var longPressAction: KeyAction = .sendModifier(.control)

    /// Whether to completely disable Caps Lock functionality
    var disableCapsLock: Bool = true
}

public enum KeyAction: Codable {
    case sendKey(KeyCode)           // Send a specific key
    case sendModifier(ModifierFlag)  // Act as a modifier
    case disabled                    // Do nothing, just suppress
}
```

### 3. Event Tap Implementation

```swift
class EventTapManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() throws {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                       (1 << CGEventType.keyUp.rawValue) |
                       (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw CapsLockError.eventTapCreationFailed
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
```

### 4. State Machine Logic

```swift
class KeyStateMachine {
    enum State {
        case idle
        case pressed(timestamp: TimeInterval)
        case released
    }

    private var state: State = .idle
    private let config: CapsLockConfiguration

    func handleKeyDown() -> EventAction {
        guard case .idle = state else { return .passThrough }

        state = .pressed(timestamp: Date.timeIntervalSinceReferenceDate)
        return .suppress
    }

    func handleKeyUp() -> (EventAction, KeyAction?) {
        guard case .pressed(let downTime) = state else {
            return (.passThrough, nil)
        }

        let duration = Date.timeIntervalSinceReferenceDate - downTime
        let action = duration < config.minPressDuration
            ? config.quickTapAction
            : config.longPressAction

        state = .idle
        return (.suppress, action)
    }
}

enum EventAction {
    case passThrough  // Let original event through
    case suppress     // Block the event
}
```

## Permission Requirements

### Accessibility Permission

**Required**: ✅ Yes

**Reason**: CGEventTap requires Accessibility permissions to intercept and modify system-wide keyboard events.

**User Experience**:
1. CapsLockAgent attempts to create event tap on first start
2. If permission denied, PermissionsManager detects failure
3. User is prompted via existing permissions flow
4. User grants permission in System Settings > Privacy & Security > Accessibility
5. Agent automatically activates when permission granted

**Check**:
```swift
func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
}
```

### Input Monitoring Permission

**Required**: ❌ No

**Reason**: Not needed for CGEventTap approach. Only required for NSEvent global monitoring.

## Constraints and Limitations

### 1. **System Integrity Protection (SIP)**
- Event taps work with SIP enabled ✅
- No kernel extension required ✅
- User-space solution is sufficient ✅

### 2. **Secure Input Mode**
- When secure input is active (password fields, Terminal secure mode), event taps may be suppressed
- Mitigation: Document this limitation, detect secure input state if possible

### 3. **Performance**
- Event callback runs synchronously in event stream
- Must return quickly (<1ms) to avoid system lag
- Solution: Minimal processing in callback, defer heavy work

### 4. **Event Tap Timeout**
- If callback takes too long, macOS may disable the event tap
- Solution: Re-enable tap if disabled, log warnings

### 5. **Caps Lock LED**
- Hardware LED state is controlled at firmware level
- Cannot be directly controlled via event tap
- Solution: Document that LED behavior may not match remapped functionality

### 6. **Conflicts with Other Tools**
- Other keyboard remapping tools (Karabiner, BetterTouchTool) may conflict
- Solution: Document known conflicts, implement conflict detection if possible

## Testing Strategy

### Unit Tests

1. **State Machine Tests**
   - Test state transitions (idle → pressed → idle)
   - Test duration calculation (quick tap vs. long press)
   - Test edge cases (rapid double-tap, very long hold)
   - Mock time source for deterministic testing

2. **Configuration Tests**
   - Test default configuration values
   - Test serialization/deserialization
   - Test configuration validation
   - Test loading from file

3. **Event Synthesis Tests**
   - Test generation of replacement key events
   - Test modifier flag handling
   - Mock event posting for verification

### Integration Tests

1. **Event Tap Lifecycle**
   - Test creation and destruction of event tap
   - Test enabling/disabling
   - Test permission checks

2. **Agent Integration**
   - Test CapsLockAgent start/stop
   - Test configuration updates during runtime
   - Test daemon manager registration

### Manual Testing Scenarios

1. Quick tap Caps Lock → Verify Escape key behavior
2. Long press Caps Lock → Verify Control modifier behavior
3. Rapid repeated taps → No lost events
4. Hold and release during secure input → Graceful degradation
5. Disable agent → Caps Lock returns to normal behavior

## Future Enhancements

1. **Multiple Action Profiles**
   - Application-specific Caps Lock behavior
   - Switch profiles based on active app

2. **Visual Feedback**
   - Menu bar indicator showing current mode
   - On-screen display for state changes

3. **Advanced Timing**
   - Triple-tap detection
   - Tap-and-hold patterns

4. **Chord Keys**
   - Caps Lock + other key combinations
   - Custom action bindings

## References

- [Apple Documentation: Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz_event_services)
- [Apple Documentation: Accessibility](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrusted)
- [Karabiner-Elements: Open-source keyboard customizer](https://github.com/pqrs-org/Karabiner-Elements)
- [CGEventTap Programming Guide](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzEventServicesConceptual/)

## Conclusion

This design leverages proven macOS APIs (CGEventTap) within the existing MacTools architecture to provide reliable, performant Caps Lock manipulation. The modular design with clear separation between event handling, state management, and configuration ensures maintainability and testability.

**Next Steps**: Implement Issue 1.2 (event interception layer) following this design.

# MacTools Architecture

## Overview

MacTools is a suite of macOS productivity utilities designed to enhance keyboard, mouse, and window management capabilities. The project follows a modular architecture with a central daemon managing multiple independent agents.

## Design Principles

1. **Modularity**: Each feature is implemented as an independent agent that can be enabled/disabled
2. **Safety**: All operations include safeguards and undo capabilities
3. **Privacy**: No data leaves the user's machine; telemetry is opt-in and local-only
4. **Performance**: Event handling runs in the main event loop with minimal overhead
5. **Testability**: Comprehensive test coverage for all components

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        MacTools App                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   DaemonManager                       │  │
│  │  - Agent lifecycle management                         │  │
│  │  - Configuration loading                              │  │
│  │  - Central logging                                    │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                 │
│         ┌──────────────────┼──────────────────┐             │
│         │                  │                  │             │
│    ┌────▼────┐      ┌─────▼──────┐    ┌─────▼──────┐      │
│    │  Caps   │      │   Scroll   │    │  Display   │      │
│    │  Lock   │      │   Master   │    │  Layouts   │      │
│    │  Agent  │      │   Agent    │    │   Agent    │      │
│    └────┬────┘      └─────┬──────┘    └─────┬──────┘      │
│         │                 │                  │             │
└─────────┼─────────────────┼──────────────────┼─────────────┘
          │                 │                  │
          │                 │                  │
     ┌────▼────┐       ┌────▼────┐        ┌───▼────┐
     │ CGEvent │       │ IOKit   │        │  AX    │
     │   Tap   │       │  HID    │        │  API   │
     └─────────┘       └─────────┘        └────────┘
```

## Core Components

### MacToolsCore

The foundation module providing shared infrastructure:

- **DaemonManager**: Central coordinator for all agents
- **Agent Protocol**: Base protocol all feature agents implement
- **Configuration**: JSON-based configuration persistence
- **PermissionsManager**: Centralized permission handling (Accessibility, Input Monitoring, Screen Recording)
- **LogManager**: Unified logging with sensitive data filtering
- **TelemetryManager**: Optional, privacy-respecting usage metrics

**Key Files:**
- `Sources/MacToolsCore/DaemonManager.swift` - Agent lifecycle
- `Sources/MacToolsCore/Agent.swift` - Base protocol
- `Sources/MacToolsCore/Configuration.swift` - Config persistence
- `Sources/MacToolsCore/PermissionsManager.swift` - Permission checks
- `Sources/MacToolsCore/LogManager.swift` - Centralized logging
- `Sources/MacToolsCore/TelemetryManager.swift` - Usage metrics

### CapsLockAgent

Remaps Caps Lock key behavior with configurable timing and actions.

**Architecture:**
```
CapsLockAgent
    │
    ├── EventTapManager (CGEventTap creation)
    ├── KeyStateMachine (Timing logic)
    ├── EventSynthesizer (Key generation)
    └── CapsLockConfiguration (Settings)
```

**Key Features:**
- Intercepts Caps Lock key events via CGEventTap
- State machine tracks press duration
- Configurable quick-tap (< threshold) vs long-press (≥ threshold)
- Synthesizes custom key events or modifiers
- Real-time configuration reload without restart

**Key Files:**
- `Sources/CapsLockAgent/CapsLockAgent.swift` - Main agent
- `Sources/CapsLockAgent/EventTapManager.swift` - Event interception
- `Sources/CapsLockAgent/KeyStateMachine.swift` - Timing logic
- `Sources/CapsLockAgent/EventSynthesizer.swift` - Key synthesis
- `Sources/CapsLockAgent/CapsLockConfiguration.swift` - Settings

**See:** [docs/capslock-design.md](./capslock-design.md) for detailed design

### ScrollMaster

Per-device scroll behavior customization with smooth scrolling.

**Architecture:**
```
ScrollMasterAgent
    │
    ├── DeviceEnumerator (IOKit HID)
    ├── DeviceRegistry (Device tracking)
    ├── ScrollEventHandler (CGEventTap)
    ├── ScrollTransform (Invert/multiply)
    ├── SmoothScrollEngine (Animation)
    └── ScrollConfigurationManager (Persistence)
```

**Key Features:**
- Enumerates input devices via IOKit HID APIs
- Stable device identification (vendor/product ID, serial, location)
- Per-device scroll configuration (invert, multiply, smooth)
- Smooth scrolling with configurable curves (linear, ease-in/out)
- Frame-based animation system
- Global emergency disable

**Key Files:**
- `Sources/ScrollMaster/ScrollMasterAgent.swift` - Main agent
- `Sources/ScrollMaster/DeviceEnumerator.swift` - Device detection
- `Sources/ScrollMaster/DeviceRegistry.swift` - Device tracking
- `Sources/ScrollMaster/ScrollEventHandler.swift` - Event interception
- `Sources/ScrollMaster/ScrollTransform.swift` - Transform logic
- `Sources/ScrollMaster/SmoothScrollEngine.swift` - Animation
- `Sources/ScrollMaster/ScrollConfigurationManager.swift` - Persistence

**See:** [docs/scrollmaster.md](./scrollmaster.md) for detailed documentation

### DisplayLayouts

Automatic window arrangement based on display configuration.

**Architecture:**
```
DisplayLayoutsAgent (Planned)
    │
    ├── DisplayEnumerator (CoreGraphics + IOKit)
    ├── DisplayIdentity (Stable identification)
    ├── DisplayChangeListener (NSNotification)
    ├── WindowManager (Accessibility API)
    ├── LayoutPresetCapture (Snapshot windows)
    ├── LayoutPresetAutomation (Auto-apply)
    ├── LayoutUndoManager (Undo/redo)
    └── LayoutSafetyChecker (Validate frames)
```

**Key Features:**
- Display detection via CGGetActiveDisplayList
- Stable display identification (vendor/model/serial)
- Configuration signature for recognizing setups
- Window enumeration and manipulation via Accessibility API
- Preset capture, storage, and application
- Auto-apply on configuration change
- Undo/redo support with state snapshots
- Safety validation (off-screen detection, frame correction)

**Key Files:**
- `Sources/DisplayLayouts/DisplayIdentity.swift` - Display detection
- `Sources/DisplayLayouts/DisplayChangeListener.swift` - Change detection
- `Sources/DisplayLayouts/WindowManager.swift` - Window manipulation
- `Sources/DisplayLayouts/WindowLayout.swift` - Layout data structures
- `Sources/DisplayLayouts/LayoutPresetCapture.swift` - Capture & automation
- `Sources/DisplayLayouts/LayoutUndo.swift` - Undo/redo & safety
- `Sources/DisplayLayouts/DisplayLayoutsViewModel.swift` - UI logic
- `Sources/DisplayLayouts/DisplayLayoutsView.swift` - SwiftUI interface

**See:** [docs/displayLayouts.md](./displayLayouts.md) for detailed documentation

## Data Flow

### Event Processing

1. **System Event** → CGEventTap/IOKit callback
2. **Agent Handler** → Process event (check config, apply transforms)
3. **Action** → Synthesize new event or modify existing
4. **System** → Forward to application

### Configuration Changes

1. **User Action** → UI or CLI command
2. **ViewModel** → Update model
3. **Configuration Manager** → Persist to JSON
4. **Agent** → Reload configuration
5. **Logging** → Record change event

### Permission Flow

1. **App Launch** → Check permissions via PermissionsManager
2. **Missing Permission** → Show onboarding UI
3. **User Grant** → Polling detects change
4. **Agent Start** → Initialize with permission

## Threading Model

- **Main Thread**: UI updates, SwiftUI views
- **Event Tap Thread**: CGEventTap callbacks (minimal work)
- **Agent Queue**: Concurrent dispatch queue for each agent (barrier flags for writes)
- **File I/O**: Background queue for configuration persistence

### Thread Safety Patterns

```swift
// Concurrent queue with barrier for writes
private let queue = DispatchQueue(
    label: "com.mactools.agent",
    attributes: .concurrent
)

// Reading (concurrent)
public func getValue() -> T {
    return queue.sync { internalValue }
}

// Writing (exclusive)
public func setValue(_ value: T) {
    queue.async(flags: .barrier) {
        self.internalValue = value
    }
}
```

## Configuration System

All configuration is stored in `~/.config/mactools/config.json`:

```json
{
  "capslock": {
    "enabled": true,
    "minPressDuration": 0.2,
    "quickTapAction": {"sendKey": 53},
    "longPressAction": {"sendModifier": "control"}
  },
  "scroll": {
    "defaultTransform": {
      "invertVertical": false,
      "verticalMultiplier": 1.0
    },
    "devices": {
      "0x046D-0xC52B-SERIAL123": {
        "invertVertical": true,
        "smoothEnabled": true
      }
    }
  },
  "layouts": {
    "autoApplyEnabled": false,
    "presets": [...]
  }
}
```

## Logging Architecture

All logging flows through `LogManager`:

```swift
// In agent code
private let logger = Logger(label: "com.mactools.capslock")
logger.info("Caps Lock enabled")

// Automatically categorized, filtered, and persisted
// View logs via LogViewerView
```

**Features:**
- Automatic sensitive data redaction
- Category-based filtering
- Configurable log levels
- Export for troubleshooting
- Real-time viewing via SwiftUI

## Telemetry Architecture

Optional, privacy-respecting usage metrics:

```swift
// Only records if user opted in
TelemetryManager.shared.recordEvent(.capsLockEnabled)

// All data stays local
// No external servers
// User can clear anytime
```

## Permission Requirements

| Feature | Accessibility | Input Monitoring | Screen Recording |
|---------|--------------|------------------|------------------|
| Caps Lock | ✓ | ✓ | - |
| Scroll Master | ✓ | ✓ | - |
| Display Layouts | ✓ | - | - (optional) |

## Testing Strategy

### Unit Tests
- All business logic has unit tests
- Mock system dependencies (event taps, IOKit)
- Test state machines exhaustively
- Cover edge cases (rapid events, out-of-order)

### Integration Tests
- Multi-agent workflows
- Configuration reload scenarios
- Permission state transitions

### UI Tests
- SwiftUI previews for visual validation
- ViewModel logic fully tested
- No UIKit/AppKit testing (requires full app)

**See:** [docs/testing.md](./testing.md) for testing guidelines

## Build System

Swift Package Manager with multiple targets:

```
MacTools/
├── Sources/
│   ├── MacToolsCore/      # Shared infrastructure
│   ├── CapsLockAgent/     # Caps Lock feature
│   ├── ScrollMaster/      # Scroll feature
│   └── DisplayLayouts/    # Window layouts feature
├── Tests/
│   ├── MacToolsCoreTests/
│   ├── CapsLockAgentTests/
│   ├── ScrollMasterTests/
│   └── DisplayLayoutsTests/
└── Package.swift
```

## Future Enhancements

### Planned Features
- Clipboard history manager
- Hot corners customization
- Mouse gesture recognition
- Keyboard macro recorder

### Technical Debt
- Add crash reporting (opt-in)
- Implement configuration migration system
- Add performance profiling hooks
- Create integration test suite with real system APIs

## Resources

- [Caps Lock Design](./capslock-design.md)
- [Scroll Master Documentation](./scrollmaster.md)
- [Display Layouts Documentation](./displayLayouts.md)
- [Testing Guidelines](./testing.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)

## Contact

For architecture questions or contributions, see [CONTRIBUTING.md](../CONTRIBUTING.md).

# Display Layouts

Automatic window arrangement based on display configuration.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Display Detection](#display-detection)
- [Window Management](#window-management)
- [Layout Presets](#layout-presets)
- [Auto-Apply](#auto-apply)
- [Undo/Redo](#undoredo)
- [Safety Features](#safety-features)
- [Configuration](#configuration)
- [CLI Usage](#cli-usage)
- [UI Features](#ui-features)
- [Troubleshooting](#troubleshooting)

## Overview

Display Layouts automatically arranges windows when you connect or disconnect displays. It detects your display configuration and applies saved window layouts.

**Use Cases:**
- Docking laptop → Apply work layout with email, terminal, IDE
- Undocking → Restore laptop-only layout
- Presentations → Apply presentation layout
- Multiple desk setups → Different layouts per location

## Architecture

```
┌────────────────────────────────────────────────┐
│         DisplayLayoutsViewModel                │
│  ┌──────────────────────────────────────────┐ │
│  │  Display Detection                       │ │
│  │  - DisplayEnumerator                     │ │
│  │  - DisplayIdentity (stable IDs)         │ │
│  │  - DisplayConfiguration (signatures)    │ │
│  └──────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────┐ │
│  │  Change Detection                        │ │
│  │  - DisplayChangeListener                 │ │
│  │  - Debouncing (0.5s)                    │ │
│  │  - Change type detection                │ │
│  └──────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────┐ │
│  │  Window Management                       │ │
│  │  - WindowManager (AX API)               │ │
│  │  - WindowLayoutSpec                     │ │
│  │  - Batch application                    │ │
│  └──────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────┐ │
│  │  Layout Presets                          │ │
│  │  - LayoutPresetCapture                   │ │
│  │  - WindowLayoutPresetManager             │ │
│  │  - LayoutPresetAutomation                │ │
│  └──────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────┐ │
│  │  Safety & Undo                           │ │
│  │  - LayoutUndoManager                     │ │
│  │  - LayoutSafetyChecker                   │ │
│  │  - Frame validation                      │ │
│  └──────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

## Display Detection

### Display Identity

Each display is identified by a stable ID combining:
- Vendor ID (manufacturer)
- Model ID (display model)
- Serial number (if available)

**Format:** `0xVVVVVVVV-0xMMMMMMMM[-SERIAL]`

Example: `0x000006B3-0x9CA4-C02QG0YBGTFN`

### Display Configuration

A configuration represents your complete display setup:

```swift
public struct DisplayConfiguration {
    let displays: [DisplayIdentity]
    let signature: String  // Deterministic hash
}
```

**Properties tracked:**
- Number of displays
- Resolution and scale factor
- Relative positions
- Main display designation

### Stable Identification

The system uses stable identifiers instead of transient display IDs:

```swift
// ❌ Bad: Display ID changes
let displayID = 1  // May change on reconnect

// ✅ Good: Stable identification
let stableID = "0x000006B3-0x9CA4-C02QG0YBGTFN"
```

## Window Management

### Accessibility API

Window manipulation uses macOS Accessibility APIs:

```swift
// Get window list
let windows = try windowManager.enumerateAllWindows()

// Apply layout
let result = try windowManager.applyLayout(spec)
```

**Permissions Required:** Accessibility access

### Window Identification

Windows are identified by:

```swift
public struct WindowIdentifier {
    let application: ApplicationIdentifier  // Bundle ID + name + PID
    let title: String                       // Window title
    let role: WindowRole                    // .window, .dialog, etc.
}
```

### Window Layout Spec

```swift
public struct WindowLayoutSpec {
    let windowID: WindowIdentifier
    let targetFrame: WindowFrame           // Position and size
    let displayID: UInt32?                 // Optional display
    let restoreIfMinimized: Bool
    let unhideIfHidden: Bool
}
```

### Batch Application

Apply multiple layouts efficiently:

```swift
let result = windowManager.applyPreset(preset)

// Check results
if result.allSucceeded {
    print("✓ All windows applied")
} else {
    print("⚠ \(result.failureCount) windows failed")
    for failure in result.failures {
        print("  - \(failure.windowID.title): \(failure.error)")
    }
}
```

## Layout Presets

### Creating Presets

Capture current window arrangement:

```swift
let capture = LayoutPresetCapture()
let preset = try capture.captureCurrentLayout(name: "Work Setup")
```

**Features:**
- Captures all visible windows
- Filters minimized/hidden windows (optional)
- Assigns windows to displays
- Stores relative positions

### Preset Storage

Presets are stored per display configuration:

```json
{
  "config_signature_abc123": [
    {
      "name": "Work Setup",
      "layouts": [...]
    }
  ]
}
```

### Preset Filtering

Capture specific windows:

```swift
// Only certain applications
let preset = try capture.captureLayout(
    forApplications: ["com.apple.Terminal", "com.apple.Safari"]
)

// Exclude applications
let preset = try capture.captureLayout(
    excludingApplications: ["com.apple.Music"]
)

// Custom filter
let preset = try capture.captureCurrentLayout(
    name: "Browsers",
    filter: { window in
        window.application.bundleIdentifier.contains("browser")
    }
)
```

## Auto-Apply

### Configuration

```swift
let automation = LayoutPresetAutomation()
automation.autoApplyEnabled = true
automation.applicationDelay = 1.0  // Wait 1s after change
```

### How It Works

1. Display configuration changes (connect/disconnect)
2. Debouncing (0.5s) to avoid rapid changes
3. Delay (configurable) for displays to settle
4. Look up preset for new configuration
5. Apply preset automatically

### Manual Application

```swift
// Apply specific preset
let result = automation.applyPreset(for: currentConfiguration)

// Or via ViewModel
viewModel.applyPreset(preset)
```

## Undo/Redo

### Snapshot System

Before any layout change, the system captures current state:

```swift
let undoManager = LayoutUndoManager()

// Automatic on preset apply
viewModel.applyPreset(preset)  // Saves undo state

// Manual undo
viewModel.undo()

// Redo
viewModel.redo()
```

### Undo Stack

- Configurable maximum states (default: 10)
- Named snapshots: "Before applying 'Work Setup'"
- Preserves window positions, sizes, states

### State Structure

```swift
public struct LayoutSnapshot {
    let name: String
    let timestamp: Date
    let windowStates: [WindowState]
}

public struct WindowState {
    let identifier: WindowIdentifier
    let frame: WindowFrame
    let isMinimized: Bool
    let isHidden: Bool
}
```

## Safety Features

### Frame Validation

Before applying layouts, the system validates safety:

```swift
let safetyChecker = LayoutSafetyChecker()
let result = safetyChecker.validatePresetSafety(preset, displays: displays)

if !result.isSafe {
    print("⚠ Unsafe frames detected")
}
```

**Checks:**
- Minimum size (100x100 pixels)
- Maximum size (10000x10000 pixels)
- Display bounds intersection
- Off-screen detection

### Frame Correction

Attempt to fix unsafe frames:

```swift
if let corrected = safetyChecker.correctFrame(frame, for: displays) {
    // Use corrected frame
} else {
    // Frame cannot be corrected
}
```

**Corrections:**
- Move off-screen windows onto nearest display
- Enlarge too-small windows
- Shrink too-large windows

### Warning Display

UI shows warnings for unsafe presets:

```
⚠ Preset contains unsafe window positions.
  Some windows may be off-screen.
```

## Configuration

### Storage Location

`~/.config/mactools/config.json`:

```json
{
  "layouts": {
    "autoApplyEnabled": false,
    "applicationDelay": 1.0,
    "presets": {
      "config_sig_1": [
        {
          "name": "Work Setup",
          "displayConfigSignature": "config_sig_1",
          "layouts": [
            {
              "windowID": {
                "application": {
                  "bundleIdentifier": "com.apple.Terminal",
                  "name": "Terminal"
                },
                "title": "~",
                "role": "window"
              },
              "targetFrame": {
                "x": 0, "y": 0,
                "width": 1920, "height": 1080
              },
              "restoreIfMinimized": true,
              "unhideIfHidden": true
            }
          ],
          "createdAt": "2024-01-01T12:00:00Z",
          "modifiedAt": "2024-01-01T12:00:00Z"
        }
      ]
    }
  }
}
```

## CLI Usage

### List Display Configuration

```bash
mactools layouts status
# Output:
# Current Display Configuration: 0x000006B3-0x9CA4_0x00000610-0xA032
# Displays: 2
# - Display 1: 2560x1440 @ 2.0x (Main)
# - Display 2: 1920x1080 @ 1.0x
```

### Create Preset

```bash
mactools layouts capture "Work Setup"
# Preset 'Work Setup' created with 12 windows
```

### Apply Preset

```bash
mactools layouts apply "Work Setup"
# Applied preset 'Work Setup'
# ✓ 12/12 windows positioned successfully
```

### List Presets

```bash
mactools layouts list
# Presets for current configuration:
# - Work Setup (12 windows)
# - Presentation Mode (3 windows)
# - Development (8 windows)
```

### Undo/Redo

```bash
mactools layouts undo
# Undid last layout change

mactools layouts redo
# Redid layout change
```

### Auto-Apply

```bash
mactools layouts auto-apply enable
# Auto-apply enabled

mactools layouts auto-apply disable
# Auto-apply disabled
```

## UI Features

### Main Interface

**DisplayLayoutsView** provides:

1. **Display Configuration Section**
   - Current configuration signature
   - Display count and details
   - Resolution, scale, main display

2. **Preset Management**
   - List of presets for current config
   - Create, rename, delete actions
   - Window count per preset
   - Validation status indicators

3. **Undo/Redo Controls**
   - Undo button (with action name tooltip)
   - Redo button (with action name tooltip)
   - Disabled when unavailable

4. **Current Windows Section**
   - All visible windows
   - Grouped by application
   - Window titles and sizes

5. **Settings**
   - Auto-apply toggle
   - Refresh button

### Preset Row

Each preset shows:
- Name and window count
- Validation status (⚠ if unsafe)
- Apply button
- Context menu (rename, delete)
- Expandable details (timestamps, validation)

### Apply Result

After applying:
```
✓ Successfully applied all window layouts

OR

⚠ 10 succeeded, 2 failed
• Chrome - Main Window: Window not found
• Slack: Permission denied
```

## Troubleshooting

### Windows Not Applying

**Problem:** Some windows fail to apply

**Solutions:**
1. Check Accessibility permissions
2. Ensure applications are running
3. Check if windows still exist (not closed)
4. Verify window titles haven't changed

### Windows Off-Screen

**Problem:** Windows placed off visible area

**Solutions:**
1. Check display configuration changed
2. Enable safety validation in settings
3. Use undo to revert
4. Recreate preset for current configuration

### Auto-Apply Not Working

**Problem:** Presets don't apply automatically

**Solutions:**
1. Verify auto-apply is enabled
2. Check preset exists for configuration
3. Increase application delay (displays settling)
4. Check logs for errors

### Preset Not Found

**Problem:** "No preset for configuration"

**Solutions:**
1. Create preset for current configuration
2. Check display signature matches
3. Verify preset wasn't deleted
4. Check configuration file integrity

### Undo Not Available

**Problem:** Undo button disabled

**Solutions:**
1. Apply a preset first (creates undo state)
2. Check undo history wasn't cleared
3. Verify undo manager is initialized

## Performance

### Optimization Tips

1. **Debouncing**: Change listener uses 0.5s debounce to avoid spam
2. **Batch Application**: Windows applied in single batch
3. **Concurrent Queries**: Window enumeration uses concurrent operations
4. **Lazy Loading**: Presets loaded on-demand

### Benchmarks

- Display detection: < 10ms
- Window enumeration: ~50ms for 100 windows
- Layout application: ~5ms per window
- Preset capture: ~100ms for 50 windows

## API Reference

### Key Classes

- `DisplayEnumerator` - Detect displays
- `DisplayIdentity` - Stable display IDs
- `DisplayConfiguration` - Configuration snapshots
- `DisplayChangeListener` - Monitor changes
- `WindowManager` - Window manipulation
- `LayoutPresetCapture` - Capture layouts
- `LayoutPresetAutomation` - Auto-apply
- `LayoutUndoManager` - Undo/redo
- `LayoutSafetyChecker` - Validation
- `DisplayLayoutsViewModel` - UI logic
- `DisplayLayoutsView` - SwiftUI interface

## Future Enhancements

- [ ] Window grouping (save related windows together)
- [ ] Keyboard shortcuts for presets
- [ ] Preset import/export
- [ ] Per-application default layouts
- [ ] Time-based auto-switching
- [ ] Multiple layouts per configuration
- [ ] Virtual desktop support

## Resources

- [Architecture Overview](./architecture.md)
- [Testing Guidelines](./testing.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)

# MacTools User Guide

Complete guide to installing, configuring, and using MacTools.

## Table of Contents

- [What is MacTools?](#what-is-mactools)
- [Installation](#installation)
- [First-Time Setup](#first-time-setup)
- [Permissions Guide](#permissions-guide)
- [Feature Guides](#feature-guides)
  - [Caps Lock Tuner](#caps-lock-tuner)
  - [Scroll Master](#scroll-master)
  - [Display Layouts](#display-layouts)
- [Configuration](#configuration)
- [CLI Reference](#cli-reference)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Uninstallation](#uninstallation)

## What is MacTools?

MacTools is a suite of productivity utilities for macOS that enhance your keyboard, mouse, and window management experience.

**What MacTools Can Do:**
- 🎯 **Remap Caps Lock**: Turn Caps Lock into Escape (quick tap) or Control (hold)
- 🖱️ **Customize Scrolling**: Per-device scroll direction and smooth scrolling
- 🪟 **Auto-Arrange Windows**: Save and restore window layouts when docking/undocking
- 🔒 **Privacy-First**: All data stays on your Mac, no analytics sent anywhere
- ⚡ **Lightweight**: Runs in background with minimal CPU/memory usage

## Installation

### System Requirements

- macOS 13.0 (Ventura) or later
- ~10 MB disk space
- Accessibility permissions

### Quick Installation

1. **Download MacTools**
   ```bash
   git clone https://github.com/acs9307/mac-tools.git
   cd mac-tools
   ```

2. **Run the installer**
   ```bash
   ./scripts/install.sh
   ```

3. **Follow the prompts**
   - The script will build MacTools
   - Install the `mactools` command
   - Set up automatic startup (optional)

4. **Grant permissions** (see [Permissions Guide](#permissions-guide))

### Manual Installation

If you prefer to install manually:

```bash
# Build the project
swift build -c release

# Install the binary
sudo cp .build/release/mactools /usr/local/bin/

# Create configuration directory
mkdir -p ~/.config/mactools

# (Optional) Set up automatic startup
cp configs/com.mactools.daemon.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist
```

### Verifying Installation

```bash
# Check that mactools is installed
which mactools
# Should output: /usr/local/bin/mactools

# Check version
mactools --version
```

## First-Time Setup

### 1. Grant Permissions

MacTools needs special permissions to work. Run:

```bash
mactools permissions --request
```

This will prompt you to grant:
- **Accessibility**: Required for all features
- **Input Monitoring**: Required for Caps Lock and Scroll Master

See [Permissions Guide](#permissions-guide) for detailed instructions.

### 2. Start MacTools

```bash
# Start in foreground (for testing)
mactools daemon --foreground

# Or start as background service
launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist
```

### 3. Verify It's Running

```bash
# Check status
mactools status

# Should show:
# ✓ MacTools Daemon: Running
# ✓ Caps Lock Agent: Active
# ✓ Scroll Master Agent: Active
# ✓ Display Layouts Agent: Active
```

### 4. Configure Features

Enable the features you want:

```bash
# Enable Caps Lock remapping
mactools capslock enable

# Enable smooth scrolling
mactools scroll enable

# Enable auto window layouts
mactools layouts enable
```

## Permissions Guide

MacTools requires special permissions to interact with your system.

### Why Permissions Are Needed

| Permission | Used For | Required By |
|------------|----------|-------------|
| **Accessibility** | Monitor keyboard/mouse, move windows | All features |
| **Input Monitoring** | Intercept keyboard/mouse events | Caps Lock, Scroll Master |
| **Screen Recording** | Read display information (optional) | Display Layouts |

### Granting Permissions

#### Step 1: Request Permissions

```bash
mactools permissions --request
```

#### Step 2: Open System Settings

1. Open **System Settings**
2. Go to **Privacy & Security**
3. Select **Accessibility**

![System Settings > Privacy & Security > Accessibility](screenshots/permissions-accessibility.png)
<!-- Screenshot should show System Settings with Privacy & Security > Accessibility selected -->

#### Step 3: Enable MacTools

1. Click the **🔒 lock icon** and enter your password
2. Find **mactools** in the list
3. Toggle the switch to **ON** (green)
4. If prompted, click **Quit & Reopen**

#### Step 4: Verify Permissions

```bash
mactools permissions

# Should show:
# ✓ Accessibility: Granted
# ✓ Input Monitoring: Granted
# ⚠ Screen Recording: Not granted (optional)
```

### Troubleshooting Permissions

**Problem: mactools not in the list**

1. Run mactools once: `mactools daemon --foreground`
2. Close it (Ctrl+C)
3. Check System Settings again

**Problem: Permission denied errors**

1. Remove and re-add MacTools in System Settings
2. Restart MacTools: `launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist && launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist`

**Problem: Changes not taking effect**

1. Completely quit MacTools
2. Wait 5 seconds
3. Start MacTools again

## Feature Guides

### Caps Lock Tuner

Transform your Caps Lock key into something useful.

#### What It Does

- **Quick Tap** (< 200ms): Sends Escape key
- **Long Press** (≥ 200ms): Acts as Control modifier
- Original Caps Lock functionality disabled

#### Setup

```bash
# Enable Caps Lock remapping
mactools capslock enable

# Check status
mactools capslock status
```

#### Configuration

##### Adjust Timing Threshold

```bash
# Set to 150ms (more sensitive)
mactools capslock set-delay 150

# Set to 300ms (less sensitive)
mactools capslock set-delay 300

# Default is 200ms
```

**Tips:**
- Lower values (100-150ms): Better for Vim users
- Higher values (250-300ms): Better if you type slowly

##### Change Key Actions

Edit `~/.config/mactools/config.json`:

```json
{
  "capslock": {
    "enabled": true,
    "minPressDuration": 0.2,
    "quickTapAction": {
      "sendKey": 53  // 53 = Escape
    },
    "longPressAction": {
      "sendModifier": "control"  // or "command", "option", "shift"
    }
  }
}
```

**Common Configurations:**

```json
// Vim users: Escape on tap, Control on hold
"quickTapAction": {"sendKey": 53},
"longPressAction": {"sendModifier": "control"}

// Emacs users: Control on tap, Command on hold
"quickTapAction": {"sendModifier": "control"},
"longPressAction": {"sendModifier": "command"}

// Delete on tap, Control on hold
"quickTapAction": {"sendKey": 51},  // 51 = Delete
"longPressAction": {"sendModifier": "control"}
```

#### Usage Examples

**Vim Users:**
- Tap Caps Lock → Escape (exit insert mode)
- Hold Caps Lock → Control (Ctrl+W, Ctrl+U, etc.)

**Terminal Users:**
- Hold Caps Lock for Ctrl+C, Ctrl+D, Ctrl+Z
- No more reaching for Control key

**General Typing:**
- Accidentally hit Caps Lock? No problem, it's Escape
- Need Control? Hold Caps Lock

#### Troubleshooting

**Problem: Quick taps not registering**
- Increase threshold: `mactools capslock set-delay 250`
- You may be pressing too slowly

**Problem: Long press not working**
- Decrease threshold: `mactools capslock set-delay 150`
- You may be releasing too quickly

**Problem: Original Caps Lock needed**
- Disable remapping: `mactools capslock disable`
- Or map to Shift+Caps Lock in config

### Scroll Master

Per-device scroll customization with smooth scrolling.

#### What It Does

- **Per-Device Settings**: Different settings for each mouse/trackpad
- **Invert Scroll**: Natural or traditional scrolling per device
- **Smooth Scrolling**: Animated scrolling like macOS trackpad
- **Speed Adjustment**: Multiply scroll speed per device

#### Setup

```bash
# Enable Scroll Master
mactools scroll enable

# List detected devices
mactools scroll list-devices
```

#### Configuration

##### Per-Device Settings

```bash
# Invert scrolling for specific device
mactools scroll set-device <device-id> --invert-vertical

# Enable smooth scrolling
mactools scroll set-device <device-id> --smooth-enabled

# Adjust scroll speed (2.0 = double speed)
mactools scroll set-device <device-id> --speed 2.0
```

##### Default Settings

Configure defaults for unknown devices:

```bash
# Set default smooth scrolling
mactools scroll set-default --smooth-enabled

# Set default scroll multiplier
mactools scroll set-default --speed 1.5
```

##### UI Configuration

For easier configuration, use the UI:

![Scroll Master UI](screenshots/scroll-master-ui.png)
<!-- Screenshot should show Scroll Master settings panel -->

#### Usage Examples

**Mixed Devices Setup:**
```bash
# Trackpad: Natural scrolling, no smoothing (default)
mactools scroll set-device "Built-in Trackpad" --no-invert

# External Mouse: Traditional scrolling, smooth enabled
mactools scroll set-device "Logitech MX Master" --invert-vertical --smooth-enabled

# Old Mouse: Traditional scrolling, 2x speed
mactools scroll set-device "Generic USB Mouse" --invert-vertical --speed 2.0
```

**Presentation Mode:**
```bash
# Temporarily disable smooth scrolling
mactools scroll set-default --no-smooth-enabled
```

#### Troubleshooting

**Problem: Device not detected**
- Unplug and replug the device
- Check: `mactools scroll list-devices`
- Some Bluetooth devices may not be detected immediately

**Problem: Smooth scrolling feels laggy**
- Reduce duration: Edit `config.json`, set `smoothScrollDuration: 0.2`
- Try different curve: `"curve": "easeOut"`

**Problem: Scrolling in wrong direction**
- Toggle invert: `mactools scroll set-device <id> --invert-vertical`

### Display Layouts

Automatically arrange windows when displays change.

#### What It Does

- **Detect Display Changes**: Knows when you dock/undock
- **Save Window Layouts**: Capture current window arrangement
- **Auto-Restore**: Apply saved layout when configuration changes
- **Multi-Monitor Support**: Different layouts for different setups
- **Undo/Redo**: Revert unwanted changes

#### Setup

```bash
# Enable Display Layouts
mactools layouts enable

# Check current display configuration
mactools layouts status
```

#### Creating Layouts

##### 1. Arrange Your Windows

Set up windows exactly how you want them.

##### 2. Capture the Layout

```bash
# Capture all windows
mactools layouts capture "Work Setup"

# Capture specific apps
mactools layouts capture "Coding Setup" --apps "Xcode,Terminal,Safari"

# Exclude apps
mactools layouts capture "Clean Desktop" --exclude "Slack,Discord"
```

##### 3. Verify

```bash
# List layouts for current configuration
mactools layouts list

# Output:
# Layouts for current configuration:
# - Work Setup (12 windows)
# - Coding Setup (3 windows)
```

#### Applying Layouts

##### Manual Application

```bash
# Apply a layout
mactools layouts apply "Work Setup"

# Output:
# ✓ 12/12 windows positioned successfully
```

##### Automatic Application

```bash
# Enable auto-apply
mactools layouts auto-apply enable

# Disable auto-apply
mactools layouts auto-apply disable
```

**How Auto-Apply Works:**
1. You disconnect your external monitor
2. MacTools detects the change
3. Waits 1 second for displays to settle
4. Looks for layout matching new configuration
5. Applies layout automatically

#### Undo/Redo

```bash
# Undo last layout change
mactools layouts undo

# Redo
mactools layouts redo

# Check undo history
mactools layouts undo-history
```

#### Usage Examples

**Docking Station Setup:**

```bash
# At desk with 2 monitors: Capture "Docked Layout"
mactools layouts capture "Docked Layout"

# Undocked (laptop only): Capture "Mobile Layout"
mactools layouts capture "Mobile Layout"

# Enable auto-apply
mactools layouts auto-apply enable

# Now when you dock/undock, layouts apply automatically!
```

**Presentation Setup:**

```bash
# Connect projector, arrange windows
mactools layouts capture "Presentation Mode"

# Apply before presenting
mactools layouts apply "Presentation Mode"

# After presentation, undo
mactools layouts undo
```

**Home Office vs Coffee Shop:**

```bash
# Home: 2 external monitors + laptop
mactools layouts capture "Home Office"

# Coffee shop: Laptop only, compact layout
mactools layouts capture "Mobile Work"

# Auto-apply handles switching between setups
```

#### Troubleshooting

**Problem: Windows not moving**
- Check Accessibility permissions
- Ensure applications are running
- Some apps don't support window manipulation

**Problem: Windows off-screen**
- MacTools should prevent this with safety checks
- If it happens: `mactools layouts undo`
- Recreate layout with current display configuration

**Problem: Auto-apply not working**
- Verify it's enabled: `mactools layouts status`
- Check layout exists for configuration: `mactools layouts list`
- Increase delay: Edit config.json, `"applicationDelay": 2.0`

**Problem: Too many windows**
- Filter by app when capturing: `--apps "App1,App2"`
- Or exclude: `--exclude "App3,App4"`

## Configuration

All configuration is stored in `~/.config/mactools/config.json`.

### Viewing Configuration

```bash
# Show entire configuration
mactools config show

# Show specific value
mactools config get capslock.minPressDuration
```

### Editing Configuration

#### Via CLI

```bash
# Set a value
mactools config set capslock.minPressDuration 0.25

# Reset to defaults
mactools config reset
```

#### Via Text Editor

```bash
# Edit directly
nano ~/.config/mactools/config.json

# Reload after editing
mactools config reload
```

### Configuration File Structure

```json
{
  "capslock": {
    "enabled": true,
    "minPressDuration": 0.2,
    "quickTapAction": {"sendKey": 53},
    "longPressAction": {"sendModifier": "control"}
  },
  "scroll": {
    "enabled": true,
    "defaultTransform": {
      "invertVertical": false,
      "verticalMultiplier": 1.0,
      "smoothEnabled": false
    },
    "smoothScrollDuration": 0.3,
    "smoothScrollCurve": "easeInOut",
    "devices": {
      "0x046D-0xC52B-SERIAL123": {
        "invertVertical": true,
        "smoothEnabled": true
      }
    }
  },
  "layouts": {
    "autoApplyEnabled": false,
    "applicationDelay": 1.0,
    "presets": { /* ... */ }
  },
  "telemetry": {
    "enabled": false
  }
}
```

### Common Configurations

#### Disable All Features

```bash
mactools capslock disable
mactools scroll disable
mactools layouts disable
```

#### Enable Telemetry (Optional)

```bash
mactools telemetry enable

# View collected metrics
mactools telemetry show
```

Telemetry is:
- ✓ **Opt-in** (disabled by default)
- ✓ **Local-only** (never sent anywhere)
- ✓ **Privacy-respecting** (no personal data)
- ✓ **Clearable** anytime

## CLI Reference

### Global Commands

```bash
# Show help
mactools --help
mactools <command> --help

# Show version
mactools --version

# Check status
mactools status

# Reload configuration
mactools reload
```

### Daemon Commands

```bash
# Start daemon (foreground)
mactools daemon --foreground

# Start daemon (background via launchd)
launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist

# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist

# Restart daemon
launchctl kickstart -k gui/$(id -u)/com.mactools.daemon
```

### Caps Lock Commands

```bash
# Show status
mactools capslock status

# Enable/disable
mactools capslock enable
mactools capslock disable

# Set delay (milliseconds)
mactools capslock set-delay <ms>

# Examples
mactools capslock set-delay 150  # Faster
mactools capslock set-delay 300  # Slower
```

### Scroll Commands

```bash
# List devices
mactools scroll list-devices

# Set device config
mactools scroll set-device <id> [options]
  --invert-vertical           # Invert vertical scrolling
  --invert-horizontal         # Invert horizontal scrolling
  --no-invert-vertical        # Don't invert vertical
  --smooth-enabled            # Enable smooth scrolling
  --no-smooth-enabled         # Disable smooth scrolling
  --speed <multiplier>        # Set speed multiplier (0.1-10.0)

# Set default config
mactools scroll set-default [same options as above]

# Enable/disable
mactools scroll enable
mactools scroll disable

# Emergency disable (instant bypass)
mactools scroll emergency-disable
```

### Layout Commands

```bash
# Show current display configuration
mactools layouts status

# List layouts
mactools layouts list

# Capture layout
mactools layouts capture <name> [options]
  --apps <app1,app2>          # Only these apps
  --exclude <app1,app2>       # Exclude these apps

# Apply layout
mactools layouts apply <name>

# Delete layout
mactools layouts delete <name>

# Rename layout
mactools layouts rename <old> <new>

# Undo/redo
mactools layouts undo
mactools layouts redo
mactools layouts undo-history

# Auto-apply
mactools layouts auto-apply enable
mactools layouts auto-apply disable

# Enable/disable
mactools layouts enable
mactools layouts disable
```

### Permission Commands

```bash
# Check permissions
mactools permissions

# Request permissions (prompts user)
mactools permissions --request

# Open System Settings
mactools permissions --open-settings
```

### Configuration Commands

```bash
# Show configuration
mactools config show

# Get value
mactools config get <key>

# Set value
mactools config set <key> <value>

# Reset to defaults
mactools config reset

# Reload from disk
mactools config reload
```

### Telemetry Commands

```bash
# Enable telemetry
mactools telemetry enable

# Disable telemetry
mactools telemetry disable

# Show statistics
mactools telemetry show

# Clear all data
mactools telemetry clear

# Export data
mactools telemetry export <file.json>
```

### Log Commands

```bash
# View logs
mactools logs show [options]
  --level <trace|debug|info|warning|error>  # Minimum level
  --category <capslock|scroll|layouts>      # Filter by category
  --since <date>                            # Since date (YYYY-MM-DD)
  --tail                                    # Follow logs

# Export logs
mactools logs export <file.txt>

# Clear logs
mactools logs clear
```

## Troubleshooting

### General Issues

#### MacTools Won't Start

**Symptoms:** Daemon doesn't start, commands fail

**Solutions:**
1. Check permissions: `mactools permissions`
2. Try foreground mode: `mactools daemon --foreground`
3. Check logs: `mactools logs show --level error`
4. Verify installation: `which mactools`

#### High CPU Usage

**Symptoms:** mactools using high CPU

**Solutions:**
1. Check logs for errors: `mactools logs show --level error`
2. Disable smooth scrolling: `mactools scroll set-default --no-smooth-enabled`
3. Restart daemon: `launchctl kickstart -k gui/$(id -u)/com.mactools.daemon`

#### Configuration Not Loading

**Symptoms:** Changes not taking effect

**Solutions:**
1. Verify config syntax: `cat ~/.config/mactools/config.json | python -m json.tool`
2. Reload: `mactools config reload`
3. Restart daemon

### Caps Lock Issues

#### Keys Not Remapping

**Solutions:**
1. Check if enabled: `mactools capslock status`
2. Check Accessibility permissions
3. Check Input Monitoring permissions
4. Restart daemon

#### Wrong Key Sent

**Solutions:**
1. Check configuration: `mactools config show`
2. Verify key code: See [Key Codes](#key-codes)
3. Edit `config.json` and reload

#### Timing Issues

**Solutions:**
1. Increase threshold: `mactools capslock set-delay 250`
2. Or decrease: `mactools capslock set-delay 150`
3. Find your comfortable setting through experimentation

### Scroll Issues

#### Device Not Detected

**Solutions:**
1. List devices: `mactools scroll list-devices`
2. Unplug and replug device
3. Check USB/Bluetooth connection
4. Some devices aren't recognized by IOKit

#### Scrolling Feels Wrong

**Solutions:**
1. Toggle invert: `mactools scroll set-device <id> --invert-vertical`
2. Adjust speed: `mactools scroll set-device <id> --speed 1.5`
3. Disable smooth scrolling for that device

#### Scroll Lag/Stuttering

**Solutions:**
1. Reduce smooth scroll duration in config.json
2. Try different curve: `"easeOut"` instead of `"easeInOut"`
3. Disable smooth scrolling: `mactools scroll set-device <id> --no-smooth-enabled`

### Layout Issues

#### Windows Not Moving

**Solutions:**
1. Check Accessibility permissions
2. Verify apps are running
3. Check app supports window manipulation (some apps restrict it)
4. Try recreating the layout

#### Windows Off-Screen

**Solutions:**
1. Undo immediately: `mactools layouts undo`
2. Recreate layout with correct display configuration
3. Safety checker should prevent this, but display info can be wrong

#### Auto-Apply Not Working

**Solutions:**
1. Verify enabled: `mactools layouts status`
2. Check layout exists: `mactools layouts list`
3. Increase delay in config: `"applicationDelay": 2.0`
4. Check logs: `mactools logs show --category layouts`

## FAQ

### General Questions

**Q: Is MacTools safe?**
A: Yes. MacTools is open-source, runs locally, and doesn't send data anywhere. However, it requires system permissions to function.

**Q: Does MacTools collect data?**
A: No by default. Telemetry is opt-in, local-only, and can be cleared anytime.

**Q: Will MacTools slow down my Mac?**
A: No. MacTools is lightweight and runs with minimal CPU/memory usage.

**Q: Can I use MacTools with other keyboard/mouse utilities?**
A: Maybe. Conflicts can occur if multiple tools intercept the same events. Test thoroughly.

**Q: How do I completely remove MacTools?**
A: See [Uninstallation](#uninstallation).

### Feature Questions

**Q: Can I use actual Caps Lock?**
A: Yes, but you'll need to disable the remapping: `mactools capslock disable`

**Q: Can I remap keys other than Caps Lock?**
A: Not currently, but it's planned for a future release.

**Q: Does smooth scrolling work with all mice?**
A: Most USB and Bluetooth mice work. Some gaming mice with high-frequency polling may not work perfectly.

**Q: Can I have different layouts for the same display configuration?**
A: Not directly, but you can save multiple layouts and manually switch between them.

**Q: What happens if I grant only some permissions?**
A: Some features won't work. Caps Lock and Scroll Master need both Accessibility and Input Monitoring.

### Technical Questions

**Q: Where are files stored?**
A:
- Binary: `/usr/local/bin/mactools`
- Config: `~/.config/mactools/config.json`
- Logs: `~/Library/Application Support/MacTools/mactools.log`
- LaunchAgent: `~/Library/LaunchAgents/com.mactools.daemon.plist`

**Q: How do I update MacTools?**
A:
```bash
cd mac-tools
git pull
./scripts/install.sh
```

**Q: Can I run MacTools on multiple Macs?**
A: Yes. Each Mac needs its own installation. Configurations aren't synced.

**Q: How do I report a bug?**
A: Open an issue on GitHub with:
- MacTools version: `mactools --version`
- macOS version
- Logs: `mactools logs export bug-report.txt`

## Uninstallation

### Quick Uninstall

```bash
./scripts/uninstall.sh
```

### Manual Uninstall

```bash
# 1. Stop daemon
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist

# 2. Remove files
sudo rm /usr/local/bin/mactools
rm ~/Library/LaunchAgents/com.mactools.daemon.plist

# 3. Remove configuration (optional)
rm -rf ~/.config/mactools

# 4. Remove logs (optional)
rm -rf ~/Library/Application\ Support/MacTools
```

### Remove Permissions

After uninstalling:

1. Open **System Settings** > **Privacy & Security**
2. Select **Accessibility**
3. Find **mactools** and click **-** to remove

## Appendix

### Key Codes

Common key codes for configuration:

| Key | Code | Key | Code |
|-----|------|-----|------|
| Escape | 53 | Return | 36 |
| Tab | 48 | Space | 49 |
| Delete | 51 | Forward Delete | 117 |
| A | 0 | Z | 6 |
| F1 | 122 | F12 | 111 |

Full list: See [Apple's Key Codes](https://developer.apple.com/documentation/)

### Support

- **Documentation**: [docs/](../docs/)
- **Issues**: [GitHub Issues](https://github.com/acs9307/mac-tools/issues)
- **Contributing**: [CONTRIBUTING.md](../CONTRIBUTING.md)

### Credits

MacTools is built with:
- Swift
- macOS Accessibility APIs
- IOKit
- CoreGraphics

---

**Last Updated:** 2024-11-13
**Version:** 1.0.0

# Troubleshooting Guide

Quick solutions to common MacTools problems.

## Quick Diagnostics

Run these commands first:

```bash
# Check if MacTools is running
mactools status

# Check permissions
mactools permissions

# View recent errors
mactools logs show --level error --tail
```

## Common Issues

### Installation & Setup

#### ❌ "command not found: mactools"

**Cause:** MacTools not in PATH or not installed

**Fix:**
```bash
# Check if installed
ls /usr/local/bin/mactools

# If missing, reinstall
cd mac-tools && ./scripts/install.sh

# Add to PATH if needed
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### ❌ Daemon won't start

**Symptoms:**
- `mactools status` shows "Not running"
- Commands fail with "daemon not responding"

**Fix:**
```bash
# Try starting in foreground to see errors
mactools daemon --foreground

# If permission errors, check:
mactools permissions --request

# If "Address already in use":
killall mactools
sleep 2
launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist
```

#### ❌ Installation script fails

**Symptoms:**
- `install.sh` exits with errors
- Build failures

**Fix:**
```bash
# Ensure Xcode CLI tools installed
xcode-select --install

# Ensure Swift available
swift --version  # Should be 5.9+

# Clean and retry
swift package clean
./scripts/install.sh
```

### Permission Issues

#### ❌ "Accessibility permission denied"

**Symptoms:**
- Features don't work
- Permission warnings in logs

**Fix:**
1. Run: `mactools permissions --request`
2. Open **System Settings** > **Privacy & Security** > **Accessibility**
3. Find **mactools**, toggle OFF then ON
4. Restart MacTools:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist
   launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist
   ```

#### ❌ mactools not in Accessibility list

**Fix:**
```bash
# Run once to trigger permission prompt
mactools daemon --foreground
# Press Ctrl+C after it starts
# Now check System Settings
```

#### ❌ Permissions granted but still not working

**Fix:**
```bash
# Remove from Accessibility list in System Settings
# Then re-add:
mactools permissions --request

# Restart macOS (sometimes necessary)
sudo reboot
```

### Caps Lock Issues

#### ❌ Caps Lock not remapping

**Symptoms:**
- Caps Lock still works normally
- Quick tap doesn't send Escape

**Fix:**
```bash
# 1. Check if enabled
mactools capslock status

# 2. Enable if disabled
mactools capslock enable

# 3. Check permissions
mactools permissions

# 4. Restart daemon
launchctl kickstart -k gui/$(id -u)/com.mactools.daemon
```

#### ❌ Wrong key sent

**Symptoms:**
- Quick tap sends wrong key
- Long press doesn't work as expected

**Fix:**
```bash
# Check configuration
mactools config get capslock

# Reset to defaults
mactools config set capslock.quickTapAction.sendKey 53
mactools config set capslock.longPressAction.sendModifier control

# Reload
mactools reload
```

#### ❌ Timing feels wrong

**Symptoms:**
- Quick taps detected as long press
- Long press detected as quick tap

**Fix:**
```bash
# Current threshold
mactools config get capslock.minPressDuration

# Too slow? Increase threshold
mactools capslock set-delay 300

# Too fast? Decrease threshold
mactools capslock set-delay 150

# Find your comfortable value (100-500ms)
```

#### ❌ Caps Lock works in some apps but not others

**Symptoms:**
- Works in Terminal but not in Chrome
- Inconsistent behavior

**Fix:**
```bash
# Some apps capture keys before MacTools can intercept
# Known issues: Chrome in fullscreen, some games

# Workaround: Give those apps Accessibility permissions too
# Or disable MacTools: mactools capslock disable
```

### Scroll Issues

#### ❌ Smooth scrolling not working

**Symptoms:**
- Scrolling still feels "stepped"
- No animation

**Fix:**
```bash
# 1. Check if enabled for device
mactools scroll list-devices
# Note device ID

# 2. Enable smooth scrolling
mactools scroll set-device <device-id> --smooth-enabled

# 3. Verify configuration
mactools config get scroll
```

#### ❌ Device not detected

**Symptoms:**
- `mactools scroll list-devices` doesn't show device
- Settings don't apply to device

**Fix:**
```bash
# 1. Unplug and replug device
# Wait 5 seconds

# 2. Check again
mactools scroll list-devices

# 3. Some devices aren't recognized by IOKit
# Try different USB port
# Bluetooth: Disconnect and reconnect

# 4. Check system recognizes it
ioreg -p IOUSB -l -w0 | grep -i mouse
```

#### ❌ Scrolling in wrong direction

**Symptoms:**
- Scroll wheel moves content opposite direction

**Fix:**
```bash
# Toggle invert
mactools scroll set-device <device-id> --invert-vertical

# Or set explicitly:
# For "natural" scrolling (like trackpad):
mactools scroll set-device <device-id> --no-invert-vertical

# For "traditional" scrolling:
mactools scroll set-device <device-id> --invert-vertical
```

#### ❌ Scroll lag or stuttering

**Symptoms:**
- Scrolling feels delayed
- Stutters or jumps

**Fix:**
```bash
# 1. Reduce smooth scroll duration
# Edit ~/.config/mactools/config.json:
"smoothScrollDuration": 0.2  # Default is 0.3

# 2. Try different curve
"smoothScrollCurve": "easeOut"  # Instead of "easeInOut"

# 3. Disable smooth scrolling for that device
mactools scroll set-device <device-id> --no-smooth-enabled

# 4. Check CPU usage
top -o cpu | grep mactools
# If high, restart daemon
```

#### ❌ Scrolling works for one device but not another

**Fix:**
```bash
# Each device needs individual configuration
# List devices
mactools scroll list-devices

# Configure each device separately
mactools scroll set-device <device-1-id> --smooth-enabled
mactools scroll set-device <device-2-id> --smooth-enabled

# Or set defaults for all unknown devices
mactools scroll set-default --smooth-enabled
```

### Display Layout Issues

#### ❌ Windows not moving

**Symptoms:**
- `mactools layouts apply` succeeds but windows don't move
- "Permission denied" errors

**Fix:**
```bash
# 1. Check Accessibility permissions
mactools permissions

# 2. Check target apps are running
# Windows can't be moved if app isn't running

# 3. Some apps don't support window manipulation
# Known issues: Some games, fullscreen apps

# 4. Try recreating layout
mactools layouts delete "Layout Name"
# Arrange windows manually
mactools layouts capture "Layout Name"
```

#### ❌ Windows placed off-screen

**Symptoms:**
- Windows disappear after applying layout
- Windows in wrong location

**Fix:**
```bash
# 1. Undo immediately
mactools layouts undo

# 2. Check display configuration matches
mactools layouts status

# 3. Safety checks should prevent this
# If it happens, it's a bug - please report

# 4. Recreate layout with current displays
# Make sure displays are connected when capturing
```

#### ❌ Auto-apply not working

**Symptoms:**
- Plug in monitor, windows don't arrange
- Unplug monitor, layout doesn't change

**Fix:**
```bash
# 1. Check auto-apply is enabled
mactools layouts status

# 2. Enable if disabled
mactools layouts auto-apply enable

# 3. Check layout exists for configuration
mactools layouts list

# 4. Create layout if missing
# Connect displays, arrange windows
mactools layouts capture "Docked Setup"

# 5. Increase application delay
# Edit ~/.config/mactools/config.json:
"layouts": {
  "applicationDelay": 2.0  # Wait longer for displays
}

# 6. Check logs
mactools logs show --category layouts
```

#### ❌ Some windows fail to apply

**Symptoms:**
- Some windows move, others don't
- Partial success message

**Fix:**
```bash
# This is normal - some windows may be:
# - Closed since layout was captured
# - Minimized
# - From apps that don't support window manipulation

# Solutions:
# 1. Ensure all apps are running
# 2. Restore minimized windows first
# 3. Filter layout to only apps you need:
mactools layouts capture "Essential Apps" --apps "Terminal,Xcode"
```

#### ❌ Layout applies to wrong windows

**Symptoms:**
- Wrong window gets moved
- Windows swap positions

**Fix:**
```bash
# Windows are matched by:
# - Application bundle ID
# - Window title
# - Window role

# If title changed, window won't match
# Solutions:
# 1. Keep window titles consistent
# 2. Recapture layout with new titles
# 3. Close duplicate windows before applying
```

### Configuration Issues

#### ❌ Changes not taking effect

**Symptoms:**
- Edit config.json but nothing changes
- CLI commands don't work

**Fix:**
```bash
# 1. Reload configuration
mactools reload

# 2. Check JSON syntax
cat ~/.config/mactools/config.json | python3 -m json.tool

# 3. If syntax error, restore backup
cp ~/.config/mactools/config.json.backup ~/.config/mactools/config.json

# 4. Reset to defaults
mactools config reset
```

#### ❌ Config file corrupted

**Symptoms:**
- MacTools won't start
- JSON parse errors in logs

**Fix:**
```bash
# 1. Backup corrupted file
cp ~/.config/mactools/config.json ~/.config/mactools/config.json.broken

# 2. Reset to defaults
mactools config reset

# 3. Or delete and restart
rm ~/.config/mactools/config.json
launchctl kickstart -k gui/$(id -u)/com.mactools.daemon
```

### Performance Issues

#### ❌ High CPU usage

**Symptoms:**
- mactools using >10% CPU
- System feels slow

**Fix:**
```bash
# 1. Check logs for errors
mactools logs show --level error

# 2. Disable smooth scrolling (most CPU-intensive)
mactools scroll set-default --no-smooth-enabled

# 3. Check for event loops in logs
mactools logs show --tail | grep -i "error\|warning"

# 4. Restart daemon
launchctl kickstart -k gui/$(id -u)/com.mactools.daemon

# 5. Report if persists (likely a bug)
```

#### ❌ High memory usage

**Symptoms:**
- mactools using >500MB RAM

**Fix:**
```bash
# 1. Check log size
ls -lh ~/Library/Application\ Support/MacTools/

# 2. Clear logs
mactools logs clear

# 3. Check telemetry data
mactools telemetry show

# 4. Clear telemetry
mactools telemetry clear

# 5. Restart daemon
launchctl kickstart -k gui/$(id -u)/com.mactools.daemon
```

### Conflict Issues

#### ❌ Conflicts with other tools

**Symptoms:**
- Weird behavior when other tools running
- Features stop working intermittently

**Known Conflicts:**
- **Karabiner-Elements**: Both modify keyboard events
- **BetterTouchTool**: Both intercept events
- **Alfred**: Hotkey conflicts possible

**Fix:**
```bash
# Option 1: Use only one tool at a time
mactools capslock disable

# Option 2: Configure to avoid conflicts
# Disable overlapping features in other tools

# Option 3: Change event tap priority (advanced)
# MacTools uses kCGHeadInsertEventTap
# May need to adjust in code
```

## Emergency Recovery

### Complete Reset

If nothing works:

```bash
# 1. Stop everything
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist
killall mactools

# 2. Backup configuration
cp -r ~/.config/mactools ~/.config/mactools.backup

# 3. Remove all data
rm -rf ~/.config/mactools
rm -rf ~/Library/Application\ Support/MacTools

# 4. Remove from Accessibility
# System Settings > Privacy & Security > Accessibility
# Remove mactools

# 5. Reinstall
cd mac-tools
./scripts/uninstall.sh
./scripts/install.sh

# 6. Grant permissions fresh
mactools permissions --request
```

### Safe Mode

Run with minimal features:

```bash
# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist

# Reset config
mactools config reset

# Disable all features
mactools capslock disable
mactools scroll disable
mactools layouts disable

# Start daemon
launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist

# Enable features one by one
mactools capslock enable
# Test...
mactools scroll enable
# Test...
```

## Getting Help

### Before Reporting a Bug

1. **Check this guide** - Common issues listed above
2. **Check logs** - `mactools logs show --level error`
3. **Try safe mode** - Minimal configuration
4. **Update MacTools** - `git pull && ./scripts/install.sh`

### Creating a Bug Report

Include:

```bash
# 1. Version info
mactools --version
sw_vers

# 2. Permission status
mactools permissions

# 3. Configuration
mactools config show > config.txt

# 4. Logs (last 100 lines)
mactools logs show --tail -n 100 > logs.txt

# 5. Steps to reproduce
# Describe what you did
```

Post to: [GitHub Issues](https://github.com/acs9307/mac-tools/issues)

### Emergency Contact

For critical security issues, email: security@mactools.example.com

---

**Last Updated:** 2024-11-13

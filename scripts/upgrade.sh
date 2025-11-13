#!/bin/bash
set -e

# Upgrade MacTools to a new version
# This script handles stopping the daemon, backing up config, and restarting

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_message "$BLUE" "🔄 MacTools Upgrade"
echo ""

# Check if running as root (should NOT be root for LaunchAgent operations)
if [ "$EUID" -eq 0 ]; then
    print_message "$YELLOW" "⚠ This script should not be run as root"
    print_message "$YELLOW" "Run without sudo for proper user configuration"
    echo ""
fi

# Check if MacTools is installed
if ! command -v mactools &> /dev/null; then
    print_message "$RED" "❌ MacTools is not installed"
    print_message "$YELLOW" "Please install MacTools first using install.sh or the installer package"
    exit 1
fi

# Get current version
print_message "$BLUE" "Current installation:"
CURRENT_VERSION=$(mactools --version 2>/dev/null || echo "unknown")
print_message "$BLUE" "  Version: $CURRENT_VERSION"
print_message "$BLUE" "  Binary: $(which mactools)"
echo ""

# Backup configuration
CONFIG_DIR="$HOME/.config/mactools"
BACKUP_DIR="$HOME/.config/mactools.backup.$(date +%Y%m%d-%H%M%S)"

if [ -d "$CONFIG_DIR" ]; then
    print_message "$BLUE" "Backing up configuration..."
    cp -r "$CONFIG_DIR" "$BACKUP_DIR"
    print_message "$GREEN" "✓ Configuration backed up to: $BACKUP_DIR"
else
    print_message "$YELLOW" "⚠ No existing configuration found"
fi

# Stop the daemon
PLIST_PATH="$HOME/Library/LaunchAgents/com.mactools.daemon.plist"

if [ -f "$PLIST_PATH" ]; then
    print_message "$BLUE" "Stopping MacTools daemon..."

    # Check if daemon is loaded
    if launchctl list | grep -q com.mactools.daemon; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        print_message "$GREEN" "✓ Daemon stopped"
    else
        print_message "$YELLOW" "⚠ Daemon was not running"
    fi

    # Give it a moment to shut down
    sleep 1
fi

# Kill any lingering processes
print_message "$BLUE" "Ensuring all processes are stopped..."
pkill -f mactools || true
sleep 1

# If a new binary is provided as an argument, install it
if [ -n "$1" ]; then
    NEW_BINARY="$1"

    if [ ! -f "$NEW_BINARY" ]; then
        print_message "$RED" "❌ Binary not found: $NEW_BINARY"
        exit 1
    fi

    print_message "$BLUE" "Installing new binary..."

    # Backup old binary
    OLD_BINARY=$(which mactools)
    if [ -f "$OLD_BINARY" ]; then
        sudo cp "$OLD_BINARY" "${OLD_BINARY}.backup"
        print_message "$GREEN" "✓ Old binary backed up to: ${OLD_BINARY}.backup"
    fi

    # Install new binary
    sudo cp "$NEW_BINARY" "$OLD_BINARY"
    sudo chmod +x "$OLD_BINARY"

    print_message "$GREEN" "✓ New binary installed"

    # Get new version
    NEW_VERSION=$(mactools --version 2>/dev/null || echo "unknown")
    print_message "$BLUE" "New version: $NEW_VERSION"
fi

echo ""
print_message "$BLUE" "Upgrade steps completed:"
print_message "$GREEN" "  ✓ Configuration backed up"
print_message "$GREEN" "  ✓ Daemon stopped"
if [ -n "$1" ]; then
    print_message "$GREEN" "  ✓ Binary upgraded"
fi
echo ""

# Restart daemon
print_message "$BLUE" "Starting MacTools daemon..."
if [ -f "$PLIST_PATH" ]; then
    launchctl load "$PLIST_PATH"

    # Wait a moment and check if it's running
    sleep 2

    if launchctl list | grep -q com.mactools.daemon; then
        print_message "$GREEN" "✓ Daemon started successfully"
    else
        print_message "$YELLOW" "⚠ Daemon may not have started"
        print_message "$YELLOW" "Check logs: mactools logs show --tail"
    fi
else
    print_message "$YELLOW" "⚠ LaunchAgent not found: $PLIST_PATH"
    print_message "$YELLOW" "You may need to start the daemon manually:"
    print_message "$YELLOW" "  mactools daemon --foreground"
fi

echo ""
print_message "$GREEN" "✅ Upgrade complete!"
echo ""

# Check if permissions are still valid
print_message "$BLUE" "Checking permissions..."
if mactools permissions 2>/dev/null | grep -q "Accessibility: granted"; then
    print_message "$GREEN" "✓ Permissions are still valid"
else
    print_message "$YELLOW" "⚠ You may need to re-grant permissions:"
    print_message "$YELLOW" "  mactools permissions --request"
fi

echo ""
print_message "$BLUE" "Notes:"
print_message "$BLUE" "  • Your configuration has been preserved"
print_message "$BLUE" "  • Backup available at: $BACKUP_DIR"
print_message "$BLUE" "  • To rollback: sudo cp ${OLD_BINARY}.backup $(which mactools)"
echo ""
print_message "$BLUE" "For troubleshooting, see:"
print_message "$BLUE" "  /usr/local/share/mactools/docs/TROUBLESHOOTING.md"
echo ""

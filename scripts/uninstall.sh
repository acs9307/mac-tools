#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🗑️  MacTools Uninstallation Script"
echo "=================================="
echo

# Confirm uninstallation
read -p "Are you sure you want to uninstall MacTools? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled"
    exit 0
fi

# Stop the daemon if running
echo "🛑 Stopping daemon..."
LAUNCH_AGENTS_PATH="$HOME/Library/LaunchAgents"
DAEMON_PLIST="com.mactools.daemon.plist"

if [ -f "$LAUNCH_AGENTS_PATH/$DAEMON_PLIST" ]; then
    launchctl unload "$LAUNCH_AGENTS_PATH/$DAEMON_PLIST" 2>/dev/null || true
    echo -e "${GREEN}✓ Daemon stopped${NC}"
else
    echo "  Daemon not installed"
fi

# Remove daemon configuration
echo "🗑️  Removing daemon configuration..."
rm -f "$LAUNCH_AGENTS_PATH/$DAEMON_PLIST"
echo -e "${GREEN}✓ Daemon configuration removed${NC}"

# Remove binary
echo "🗑️  Removing binary..."
INSTALL_PATH="/usr/local/bin"
BINARY_NAME="mactools"

if [ -f "$INSTALL_PATH/$BINARY_NAME" ]; then
    sudo rm -f "$INSTALL_PATH/$BINARY_NAME"
    echo -e "${GREEN}✓ Binary removed${NC}"
else
    echo "  Binary not found"
fi

# Ask if user wants to remove configuration
echo
read -p "Would you like to remove configuration files as well? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    CONFIG_DIR="$HOME/.config/mactools"
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}✓ Configuration removed${NC}"
    else
        echo "  Configuration directory not found"
    fi
else
    echo "  Configuration preserved at ~/.config/mactools"
fi

echo
echo -e "${GREEN}✓ Uninstallation complete!${NC}"
echo
echo "Thank you for using MacTools!"

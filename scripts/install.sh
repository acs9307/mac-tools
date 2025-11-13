#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 MacTools Installation Script"
echo "================================"
echo

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This tool is only supported on macOS${NC}"
    exit 1
fi

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo -e "${RED}Error: Swift is not installed${NC}"
    echo "Please install Xcode or the Xcode Command Line Tools"
    exit 1
fi

# Build the project
echo "📦 Building MacTools..."
swift build -c release

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo

# Install the binary
echo "📥 Installing binary..."
INSTALL_PATH="/usr/local/bin"
BINARY_NAME="mactools"

sudo mkdir -p "$INSTALL_PATH"
sudo cp ".build/release/$BINARY_NAME" "$INSTALL_PATH/$BINARY_NAME"
sudo chmod +x "$INSTALL_PATH/$BINARY_NAME"

echo -e "${GREEN}✓ Binary installed to $INSTALL_PATH/$BINARY_NAME${NC}"
echo

# Install daemon configuration
echo "⚙️  Installing daemon configuration..."
LAUNCH_AGENTS_PATH="$HOME/Library/LaunchAgents"
DAEMON_PLIST="com.mactools.daemon.plist"

mkdir -p "$LAUNCH_AGENTS_PATH"
cp "configs/$DAEMON_PLIST" "$LAUNCH_AGENTS_PATH/$DAEMON_PLIST"

echo -e "${GREEN}✓ Daemon configuration installed${NC}"
echo

# Create config directory
echo "📁 Creating configuration directory..."
CONFIG_DIR="$HOME/.config/mactools"
mkdir -p "$CONFIG_DIR"

echo -e "${GREEN}✓ Configuration directory created at $CONFIG_DIR${NC}"
echo

# Check permissions
echo "🔐 Checking permissions..."
$BINARY_NAME permissions

echo
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "   MacTools requires Accessibility permissions to function."
echo "   Please grant these permissions in:"
echo "   System Settings > Privacy & Security > Accessibility"
echo
echo "   You can check and request permissions by running:"
echo "   ${GREEN}mactools permissions --request${NC}"
echo

# Ask if user wants to start the daemon
read -p "Would you like to start the daemon now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting daemon..."
    launchctl load "$LAUNCH_AGENTS_PATH/$DAEMON_PLIST"
    echo -e "${GREEN}✓ Daemon started${NC}"
    echo
    echo "To check daemon status, run:"
    echo "  ${GREEN}launchctl list | grep mactools${NC}"
else
    echo "To start the daemon later, run:"
    echo "  ${GREEN}launchctl load ~/Library/LaunchAgents/$DAEMON_PLIST${NC}"
fi

echo
echo -e "${GREEN}✓ Installation complete!${NC}"
echo
echo "Available commands:"
echo "  mactools daemon          - Manage the daemon"
echo "  mactools permissions     - Check/request permissions"
echo "  mactools config          - Manage configuration"
echo "  mactools window          - Window manipulation"
echo "  mactools key             - Key manipulation"
echo
echo "For more information, run: ${GREEN}mactools --help${NC}"

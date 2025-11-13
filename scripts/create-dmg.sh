#!/bin/bash
set -e

# Create a signed .dmg for distribution
# Usage: ./scripts/create-dmg.sh <version> <binary-path>

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

print_message "$BLUE" "🔧 MacTools DMG Creator"
echo ""

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    print_message "$RED" "Usage: $0 <version> <binary-path>"
    print_message "$YELLOW" "Example: $0 v1.0.0 .build/release/mactools"
    exit 1
fi

VERSION="$1"
BINARY_PATH="$2"
DMG_NAME="mactools-${VERSION}-macos.dmg"
VOLUME_NAME="MacTools ${VERSION}"
STAGING_DIR="$(mktemp -d)/mactools-dmg"

print_message "$BLUE" "Version: $VERSION"
print_message "$BLUE" "Binary: $BINARY_PATH"
print_message "$BLUE" "Output: $DMG_NAME"
echo ""

# Verify binary exists
if [ ! -f "$BINARY_PATH" ]; then
    print_message "$RED" "❌ Binary not found: $BINARY_PATH"
    exit 1
fi

# Verify binary is signed (if CODESIGN_IDENTITY is set)
if [ -n "$CODESIGN_IDENTITY" ]; then
    print_message "$BLUE" "Verifying signature..."
    if codesign -dv "$BINARY_PATH" 2>&1 | grep -q "Signature="; then
        print_message "$GREEN" "✓ Binary is signed"
    else
        print_message "$YELLOW" "⚠ Binary is not signed"
    fi
fi

# Create staging directory structure
print_message "$BLUE" "Creating staging directory..."
mkdir -p "$STAGING_DIR"
mkdir -p "$STAGING_DIR/.background"

# Copy binary
cp "$BINARY_PATH" "$STAGING_DIR/mactools"
chmod +x "$STAGING_DIR/mactools"

# Copy supporting files
if [ -f "README.md" ]; then
    cp "README.md" "$STAGING_DIR/"
fi

if [ -f "LICENSE" ]; then
    cp "LICENSE" "$STAGING_DIR/"
fi

# Copy documentation
if [ -d "docs" ]; then
    mkdir -p "$STAGING_DIR/Documentation"
    cp -r docs/* "$STAGING_DIR/Documentation/"
fi

# Copy configs
if [ -d "configs" ]; then
    mkdir -p "$STAGING_DIR/Configs"
    cp -r configs/* "$STAGING_DIR/Configs/"
fi

# Copy scripts (install, uninstall)
if [ -d "scripts" ]; then
    mkdir -p "$STAGING_DIR/Scripts"
    for script in scripts/install.sh scripts/uninstall.sh scripts/upgrade.sh; do
        if [ -f "$script" ]; then
            cp "$script" "$STAGING_DIR/Scripts/"
            chmod +x "$STAGING_DIR/Scripts/$(basename $script)"
        fi
    done
fi

# Create install helper script
cat > "$STAGING_DIR/Install MacTools.command" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
if [ -f "Scripts/install.sh" ]; then
    exec ./Scripts/install.sh
else
    echo "Error: install.sh not found"
    exit 1
fi
EOF
chmod +x "$STAGING_DIR/Install MacTools.command"

# Create README for DMG
cat > "$STAGING_DIR/READ ME.txt" << EOF
MacTools ${VERSION}
==================

Thank you for downloading MacTools!

INSTALLATION
------------
1. Double-click "Install MacTools.command" to install
   OR
2. Manually copy the 'mactools' binary to /usr/local/bin/
   $ sudo cp mactools /usr/local/bin/
   $ sudo chmod +x /usr/local/bin/mactools

3. Grant necessary permissions:
   $ mactools permissions --request
   Follow the on-screen instructions to grant Accessibility permissions.

4. Start the daemon:
   $ mactools daemon --foreground
   OR install the LaunchAgent (see Documentation/user-guide.md)

DOCUMENTATION
-------------
Complete documentation is available in the Documentation/ folder:
- user-guide.md: Complete user guide
- TROUBLESHOOTING.md: Common issues and solutions
- architecture.md: Technical architecture (for developers)

UPGRADE
-------
If upgrading from a previous version, run:
$ ./Scripts/upgrade.sh

UNINSTALL
---------
To uninstall MacTools:
$ ./Scripts/uninstall.sh

SUPPORT
-------
- GitHub: https://github.com/acs9307/mac-tools
- Issues: https://github.com/acs9307/mac-tools/issues

LICENSE
-------
See LICENSE file for details.
EOF

# Calculate size for DMG (add 20% padding)
print_message "$BLUE" "Calculating DMG size..."
SIZE_KB=$(du -sk "$STAGING_DIR" | awk '{print $1}')
SIZE_MB=$(( (SIZE_KB * 120) / 100 / 1024 + 1 ))  # +20% padding, round up
print_message "$BLUE" "DMG size: ${SIZE_MB}MB"

# Create temporary DMG
TEMP_DMG="$(mktemp).dmg"
print_message "$BLUE" "Creating DMG..."

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    -size ${SIZE_MB}m \
    "$TEMP_DMG"

# Mount DMG for customization
print_message "$BLUE" "Mounting DMG for customization..."
MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" | grep "/Volumes/" | awk '{print $3}')

if [ -z "$MOUNT_POINT" ]; then
    print_message "$RED" "❌ Failed to mount DMG"
    exit 1
fi

# Set custom icon positions (if hdiutil supports)
# This is optional and may not work in all environments
if command -v osascript &> /dev/null; then
    print_message "$BLUE" "Setting window properties..."
    osascript << EOF_APPLESCRIPT || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 800, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        close
        open
    end tell
end tell
EOF_APPLESCRIPT
fi

# Unmount
print_message "$BLUE" "Unmounting DMG..."
hdiutil detach "$MOUNT_POINT" -quiet

# Convert to compressed read-only
print_message "$BLUE" "Compressing DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -o "$DMG_NAME"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$STAGING_DIR"

# Sign the DMG if identity is provided
if [ -n "$CODESIGN_IDENTITY" ]; then
    print_message "$BLUE" "Signing DMG..."
    codesign --force \
        --sign "$CODESIGN_IDENTITY" \
        --timestamp \
        "$DMG_NAME"

    print_message "$GREEN" "✓ DMG signed"
fi

# Verify DMG
print_message "$BLUE" "Verifying DMG..."
hdiutil verify "$DMG_NAME"

# Calculate checksum
print_message "$BLUE" "Generating checksum..."
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"

# Print results
echo ""
print_message "$GREEN" "✅ DMG created successfully!"
echo ""
print_message "$BLUE" "Output files:"
print_message "$BLUE" "  - $DMG_NAME"
print_message "$BLUE" "  - ${DMG_NAME}.sha256"
echo ""

# Print file info
DMG_SIZE=$(du -h "$DMG_NAME" | awk '{print $1}')
print_message "$BLUE" "DMG size: $DMG_SIZE"

if [ -f "${DMG_NAME}.sha256" ]; then
    print_message "$BLUE" "Checksum:"
    cat "${DMG_NAME}.sha256" | awk '{print "  " $1}'
fi

echo ""
print_message "$GREEN" "✅ Done!"

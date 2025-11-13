#!/bin/bash
set -e

# Create a signed .pkg installer for distribution
# Usage: ./scripts/create-pkg.sh <version> <binary-path>

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

print_message "$BLUE" "📦 MacTools PKG Creator"
echo ""

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    print_message "$RED" "Usage: $0 <version> <binary-path>"
    print_message "$YELLOW" "Example: $0 v1.0.0 .build/release/mactools"
    exit 1
fi

VERSION="$1"
BINARY_PATH="$2"
PKG_NAME="mactools-${VERSION}-macos.pkg"
PKG_IDENTIFIER="com.acs9307.mactools"
STAGING_DIR="$(mktemp -d)/mactools-pkg"
PAYLOAD_DIR="$STAGING_DIR/payload"
SCRIPTS_DIR="$STAGING_DIR/scripts"

print_message "$BLUE" "Version: $VERSION"
print_message "$BLUE" "Binary: $BINARY_PATH"
print_message "$BLUE" "Output: $PKG_NAME"
echo ""

# Verify binary exists
if [ ! -f "$BINARY_PATH" ]; then
    print_message "$RED" "❌ Binary not found: $BINARY_PATH"
    exit 1
fi

# Verify binary is signed (if CODESIGN_IDENTITY is set)
if [ -n "$CODESIGN_IDENTITY" ]; then
    print_message "$BLUE" "Verifying binary signature..."
    if codesign -dv "$BINARY_PATH" 2>&1 | grep -q "Signature="; then
        print_message "$GREEN" "✓ Binary is signed"
    else
        print_message "$YELLOW" "⚠ Binary is not signed"
    fi
fi

# Create directory structure
print_message "$BLUE" "Creating package structure..."
mkdir -p "$PAYLOAD_DIR/usr/local/bin"
mkdir -p "$PAYLOAD_DIR/usr/local/share/mactools/configs"
mkdir -p "$PAYLOAD_DIR/usr/local/share/mactools/docs"
mkdir -p "$PAYLOAD_DIR/usr/local/share/mactools/scripts"
mkdir -p "$SCRIPTS_DIR"

# Copy binary
cp "$BINARY_PATH" "$PAYLOAD_DIR/usr/local/bin/mactools"
chmod +x "$PAYLOAD_DIR/usr/local/bin/mactools"

# Copy configs
if [ -d "configs" ]; then
    cp -r configs/* "$PAYLOAD_DIR/usr/local/share/mactools/configs/"
fi

# Copy documentation
if [ -d "docs" ]; then
    cp -r docs/* "$PAYLOAD_DIR/usr/local/share/mactools/docs/"
fi

# Copy supporting files
if [ -f "README.md" ]; then
    cp "README.md" "$PAYLOAD_DIR/usr/local/share/mactools/"
fi

if [ -f "LICENSE" ]; then
    cp "LICENSE" "$PAYLOAD_DIR/usr/local/share/mactools/"
fi

# Copy scripts for reference
if [ -d "scripts" ]; then
    for script in scripts/install.sh scripts/uninstall.sh scripts/upgrade.sh; do
        if [ -f "$script" ]; then
            cp "$script" "$PAYLOAD_DIR/usr/local/share/mactools/scripts/"
        fi
    done
fi

# Create postinstall script
cat > "$SCRIPTS_DIR/postinstall" << 'EOF'
#!/bin/bash

# MacTools Post-Installation Script

echo "Configuring MacTools..."

# Create config directory if it doesn't exist
USER_HOME=$(eval echo ~$USER)
CONFIG_DIR="$USER_HOME/.config/mactools"

if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    chown $USER:staff "$CONFIG_DIR"
    echo "Created configuration directory: $CONFIG_DIR"
fi

# Copy default config if it doesn't exist
DEFAULT_CONFIG="/usr/local/share/mactools/configs/default-config.json"
USER_CONFIG="$CONFIG_DIR/config.json"

if [ -f "$DEFAULT_CONFIG" ] && [ ! -f "$USER_CONFIG" ]; then
    cp "$DEFAULT_CONFIG" "$USER_CONFIG"
    chown $USER:staff "$USER_CONFIG"
    echo "Installed default configuration"
fi

# Copy LaunchAgent plist if it doesn't exist
LAUNCHAGENT_SOURCE="/usr/local/share/mactools/configs/com.mactools.daemon.plist"
LAUNCHAGENT_DIR="$USER_HOME/Library/LaunchAgents"
LAUNCHAGENT_DEST="$LAUNCHAGENT_DIR/com.mactools.daemon.plist"

if [ -f "$LAUNCHAGENT_SOURCE" ]; then
    mkdir -p "$LAUNCHAGENT_DIR"
    if [ ! -f "$LAUNCHAGENT_DEST" ]; then
        cp "$LAUNCHAGENT_SOURCE" "$LAUNCHAGENT_DEST"
        chown $USER:staff "$LAUNCHAGENT_DEST"
        echo "Installed LaunchAgent configuration"
    fi
fi

# Print success message
echo ""
echo "✅ MacTools installed successfully!"
echo ""
echo "Next steps:"
echo "1. Grant permissions:"
echo "   $ mactools permissions --request"
echo ""
echo "2. Start the daemon:"
echo "   $ launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist"
echo ""
echo "3. Check status:"
echo "   $ mactools --version"
echo ""
echo "For more information, see:"
echo "  /usr/local/share/mactools/docs/user-guide.md"
echo ""

exit 0
EOF
chmod +x "$SCRIPTS_DIR/postinstall"

# Create preinstall script (for upgrades)
cat > "$SCRIPTS_DIR/preinstall" << 'EOF'
#!/bin/bash

# MacTools Pre-Installation Script

# Stop daemon if running
USER_HOME=$(eval echo ~$USER)
PLIST_PATH="$USER_HOME/Library/LaunchAgents/com.mactools.daemon.plist"

if [ -f "$PLIST_PATH" ]; then
    echo "Stopping MacTools daemon..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true

    # Give it a moment to shut down
    sleep 1
fi

# Kill any running instances
pkill -f mactools || true

echo "Ready for installation"
exit 0
EOF
chmod +x "$SCRIPTS_DIR/preinstall"

# Build component package
COMPONENT_PKG="$STAGING_DIR/mactools-component.pkg"
print_message "$BLUE" "Building component package..."

pkgbuild \
    --root "$PAYLOAD_DIR" \
    --identifier "$PKG_IDENTIFIER" \
    --version "$VERSION" \
    --scripts "$SCRIPTS_DIR" \
    --install-location "/" \
    "$COMPONENT_PKG"

# Create distribution XML
DISTRIBUTION_XML="$STAGING_DIR/distribution.xml"
cat > "$DISTRIBUTION_XML" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>MacTools $VERSION</title>
    <welcome file="welcome.html"/>
    <readme file="readme.html"/>
    <license file="license.html"/>
    <conclusion file="conclusion.html"/>

    <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>

    <domains enable_localSystem="true"/>

    <choices-outline>
        <line choice="default">
            <line choice="mactools"/>
        </line>
    </choices-outline>

    <choice id="default"/>

    <choice id="mactools" visible="false">
        <pkg-ref id="$PKG_IDENTIFIER"/>
    </choice>

    <pkg-ref id="$PKG_IDENTIFIER" version="$VERSION" onConclusion="none">mactools-component.pkg</pkg-ref>
</installer-gui-script>
EOF

# Create resources
RESOURCES_DIR="$STAGING_DIR/resources"
mkdir -p "$RESOURCES_DIR"

# Welcome
cat > "$RESOURCES_DIR/welcome.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
        h1 { color: #007AFF; }
    </style>
</head>
<body>
    <h1>Welcome to MacTools $VERSION</h1>
    <p>This installer will install MacTools on your system.</p>
    <p><strong>MacTools</strong> is a powerful suite of macOS system tools for key and window manipulation.</p>

    <h2>Features</h2>
    <ul>
        <li>Caps Lock Remapping with configurable quick tap and long press actions</li>
        <li>Per-Device Scroll Behavior with smooth scrolling and inversion</li>
        <li>Display Layouts with auto-arrangement based on display configuration</li>
    </ul>

    <h2>Requirements</h2>
    <ul>
        <li>macOS 13.0 or later</li>
        <li>Accessibility permissions (requested after installation)</li>
    </ul>
</body>
</html>
EOF

# README
cat > "$RESOURCES_DIR/readme.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
        h1 { color: #007AFF; }
        code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>Installation Notes</h1>

    <h2>What will be installed</h2>
    <ul>
        <li><code>/usr/local/bin/mactools</code> - Main executable</li>
        <li><code>~/.config/mactools/</code> - Configuration directory</li>
        <li><code>~/Library/LaunchAgents/com.mactools.daemon.plist</code> - LaunchAgent</li>
        <li><code>/usr/local/share/mactools/</code> - Documentation and resources</li>
    </ul>

    <h2>After Installation</h2>
    <p>After installation completes, you'll need to:</p>
    <ol>
        <li>Grant <strong>Accessibility</strong> permissions in System Settings</li>
        <li>Start the MacTools daemon</li>
    </ol>

    <p>Complete instructions will be displayed after installation.</p>

    <h2>Upgrading</h2>
    <p>If you're upgrading from a previous version, the installer will:</p>
    <ul>
        <li>Stop the running daemon</li>
        <li>Replace the binary with the new version</li>
        <li>Preserve your existing configuration</li>
    </ul>
</body>
</html>
EOF

# License
if [ -f "LICENSE" ]; then
    cat > "$RESOURCES_DIR/license.html" << 'EOF_START'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: monospace; white-space: pre-wrap; }
    </style>
</head>
<body>
EOF_START
    cat LICENSE >> "$RESOURCES_DIR/license.html"
    echo "</body></html>" >> "$RESOURCES_DIR/license.html"
else
    # Placeholder license
    cat > "$RESOURCES_DIR/license.html" << EOF
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
<p>See LICENSE file for license details.</p>
</body>
</html>
EOF
fi

# Conclusion
cat > "$RESOURCES_DIR/conclusion.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
        h1 { color: #34C759; }
        code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
        .step { margin: 15px 0; }
    </style>
</head>
<body>
    <h1>Installation Complete!</h1>

    <p>MacTools $VERSION has been successfully installed.</p>

    <h2>Next Steps</h2>

    <div class="step">
        <h3>1. Grant Permissions</h3>
        <p>Open Terminal and run:</p>
        <code>mactools permissions --request</code>
        <p>Follow the instructions to grant <strong>Accessibility</strong> permissions in System Settings.</p>
    </div>

    <div class="step">
        <h3>2. Start the Daemon</h3>
        <p>Load the LaunchAgent:</p>
        <code>launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist</code>
    </div>

    <div class="step">
        <h3>3. Verify Installation</h3>
        <p>Check the version:</p>
        <code>mactools --version</code>
    </div>

    <h2>Documentation</h2>
    <p>Complete documentation is available at:</p>
    <code>/usr/local/share/mactools/docs/</code>

    <h2>Support</h2>
    <p>For help and support:</p>
    <ul>
        <li>User Guide: <code>/usr/local/share/mactools/docs/user-guide.md</code></li>
        <li>Troubleshooting: <code>/usr/local/share/mactools/docs/TROUBLESHOOTING.md</code></li>
        <li>GitHub Issues: <a href="https://github.com/acs9307/mac-tools/issues">github.com/acs9307/mac-tools/issues</a></li>
    </ul>
</body>
</html>
EOF

# Build product archive
print_message "$BLUE" "Building product archive..."

productbuild \
    --distribution "$DISTRIBUTION_XML" \
    --resources "$RESOURCES_DIR" \
    --package-path "$STAGING_DIR" \
    "$PKG_NAME"

# Sign the package if identity is provided
if [ -n "$INSTALLER_IDENTITY" ]; then
    print_message "$BLUE" "Signing package..."
    TEMP_PKG="$PKG_NAME.unsigned"
    mv "$PKG_NAME" "$TEMP_PKG"

    productsign \
        --sign "$INSTALLER_IDENTITY" \
        --timestamp \
        "$TEMP_PKG" \
        "$PKG_NAME"

    rm "$TEMP_PKG"
    print_message "$GREEN" "✓ Package signed"
else
    print_message "$YELLOW" "⚠ Package not signed (INSTALLER_IDENTITY not set)"
fi

# Clean up
rm -rf "$STAGING_DIR"

# Verify package
print_message "$BLUE" "Verifying package..."
pkgutil --check-signature "$PKG_NAME" || true

# Calculate checksum
print_message "$BLUE" "Generating checksum..."
shasum -a 256 "$PKG_NAME" > "${PKG_NAME}.sha256"

# Print results
echo ""
print_message "$GREEN" "✅ PKG created successfully!"
echo ""
print_message "$BLUE" "Output files:"
print_message "$BLUE" "  - $PKG_NAME"
print_message "$BLUE" "  - ${PKG_NAME}.sha256"
echo ""

# Print file info
PKG_SIZE=$(du -h "$PKG_NAME" | awk '{print $1}')
print_message "$BLUE" "PKG size: $PKG_SIZE"

if [ -f "${PKG_NAME}.sha256" ]; then
    print_message "$BLUE" "Checksum:"
    cat "${PKG_NAME}.sha256" | awk '{print "  " $1}'
fi

echo ""
print_message "$GREEN" "✅ Done!"

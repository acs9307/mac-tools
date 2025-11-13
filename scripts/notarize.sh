#!/bin/bash
# Notarization script for MacTools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BINARY_PATH="${1:-.build/release/mactools}"
BUNDLE_ID="${BUNDLE_ID:-com.mactools.cli}"
APPLE_ID="${APPLE_ID}"
TEAM_ID="${TEAM_ID}"
APP_PASSWORD="${NOTARIZATION_PASSWORD}"

echo "=================================================="
echo "MacTools Notarization"
echo "=================================================="
echo ""

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: Binary not found at $BINARY_PATH${NC}"
    exit 1
fi

# Check if running on macOS
if [ "$(uname)" != "Darwin" ]; then
    echo -e "${YELLOW}Warning: Notarization is only available on macOS${NC}"
    echo "Skipping notarization on $(uname)"
    exit 0
fi

# Check for required credentials
if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_PASSWORD" ]; then
    echo -e "${RED}Error: Missing notarization credentials${NC}"
    echo ""
    echo "Required environment variables:"
    echo "  APPLE_ID              - Your Apple ID email"
    echo "  TEAM_ID               - Your Team ID (10-character)"
    echo "  NOTARIZATION_PASSWORD - App-specific password"
    echo ""
    echo "To create an app-specific password:"
    echo "  1. Go to https://appleid.apple.com"
    echo "  2. Sign in with your Apple ID"
    echo "  3. Go to Security > App-Specific Passwords"
    echo "  4. Generate a new password"
    echo ""
    exit 1
fi

# Check if binary is signed
echo "Checking code signature..."
if ! codesign -dv "$BINARY_PATH" 2>/dev/null; then
    echo -e "${RED}Error: Binary is not signed${NC}"
    echo "Sign the binary first: ./scripts/sign.sh $BINARY_PATH"
    exit 1
fi

# Create a zip archive for notarization
ARCHIVE_PATH="/tmp/mactools-$(date +%s).zip"
echo "Creating archive: $ARCHIVE_PATH"
ditto -c -k --keepParent "$BINARY_PATH" "$ARCHIVE_PATH"

# Submit for notarization
echo ""
echo "Submitting for notarization..."
echo "This may take several minutes..."
echo ""

NOTARIZATION_RESPONSE=$(xcrun notarytool submit "$ARCHIVE_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait \
    2>&1)

echo "$NOTARIZATION_RESPONSE"

# Extract submission ID
SUBMISSION_ID=$(echo "$NOTARIZATION_RESPONSE" | grep "id:" | head -1 | awk '{print $2}')

if [ -z "$SUBMISSION_ID" ]; then
    echo -e "${RED}Error: Failed to get submission ID${NC}"
    rm -f "$ARCHIVE_PATH"
    exit 1
fi

echo ""
echo -e "${BLUE}Submission ID: $SUBMISSION_ID${NC}"

# Check if notarization succeeded
if echo "$NOTARIZATION_RESPONSE" | grep -q "status: Accepted"; then
    echo -e "${GREEN}✓ Notarization successful!${NC}"

    # Staple the ticket (optional for command-line tools, but good practice)
    echo ""
    echo "Stapling notarization ticket..."
    if xcrun stapler staple "$BINARY_PATH" 2>&1; then
        echo -e "${GREEN}✓ Ticket stapled successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Could not staple ticket (normal for command-line tools)${NC}"
    fi
else
    echo -e "${RED}✗ Notarization failed${NC}"
    echo ""
    echo "Fetching notarization log..."
    xcrun notarytool log "$SUBMISSION_ID" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD"

    rm -f "$ARCHIVE_PATH"
    exit 1
fi

# Clean up
rm -f "$ARCHIVE_PATH"

# Verify Gatekeeper will accept it
echo ""
echo "Verifying Gatekeeper assessment..."
if spctl -a -vv -t install "$BINARY_PATH" 2>&1 | grep -q "accepted"; then
    echo -e "${GREEN}✓ Binary will be accepted by Gatekeeper${NC}"
else
    echo -e "${YELLOW}Warning: Gatekeeper assessment unclear${NC}"
    echo "This is normal for command-line tools"
fi

echo ""
echo -e "${GREEN}Notarization completed successfully!${NC}"
echo ""
echo "Binary is now notarized and ready for distribution."

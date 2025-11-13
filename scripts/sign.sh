#!/bin/bash
# Code signing script for MacTools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BINARY_PATH="${1:-.build/release/mactools}"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"
ENTITLEMENTS="${2:-configs/entitlements.plist}"

echo "=================================================="
echo "MacTools Code Signing"
echo "=================================================="
echo ""

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: Binary not found at $BINARY_PATH${NC}"
    echo "Build the project first: swift build -c release"
    exit 1
fi

# Check if running on macOS
if [ "$(uname)" != "Darwin" ]; then
    echo -e "${YELLOW}Warning: Code signing is only available on macOS${NC}"
    echo "Skipping signing on $(uname)"
    exit 0
fi

# Check for code signing identity
if [ -z "$CODESIGN_IDENTITY" ]; then
    echo -e "${YELLOW}Warning: CODESIGN_IDENTITY not set${NC}"
    echo "Available identities:"
    security find-identity -v -p codesigning
    echo ""
    echo "Set CODESIGN_IDENTITY environment variable or pass identity as argument"
    echo "Example: CODESIGN_IDENTITY=\"Developer ID Application: Your Name (TEAM_ID)\" $0"
    exit 1
fi

# Display signing information
echo "Binary: $BINARY_PATH"
echo "Identity: $IDENTITY"
echo "Entitlements: $ENTITLEMENTS"
echo ""

# Check current signature
echo "Checking current signature..."
if codesign -dv "$BINARY_PATH" 2>/dev/null; then
    echo -e "${YELLOW}Binary is already signed${NC}"
    read -p "Re-sign? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Remove old signature if exists
echo "Removing old signature..."
codesign --remove-signature "$BINARY_PATH" 2>/dev/null || true

# Sign the binary
echo "Signing binary..."
if [ -f "$ENTITLEMENTS" ]; then
    codesign --force \
        --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$IDENTITY" \
        --timestamp \
        --verbose \
        "$BINARY_PATH"
else
    echo -e "${YELLOW}Warning: Entitlements file not found, signing without entitlements${NC}"
    codesign --force \
        --options runtime \
        --sign "$IDENTITY" \
        --timestamp \
        --verbose \
        "$BINARY_PATH"
fi

# Verify signature
echo ""
echo "Verifying signature..."
if codesign --verify --deep --strict --verbose=2 "$BINARY_PATH" 2>&1; then
    echo -e "${GREEN}✓ Signature valid${NC}"
else
    echo -e "${RED}✗ Signature verification failed${NC}"
    exit 1
fi

# Display signature info
echo ""
echo "Signature information:"
codesign -dvvv "$BINARY_PATH" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier|Timestamp"

echo ""
echo -e "${GREEN}Code signing completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Notarize: ./scripts/notarize.sh $BINARY_PATH"
echo "2. Verify: spctl -a -vv $BINARY_PATH"

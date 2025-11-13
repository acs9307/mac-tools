#!/bin/bash
# Verification script for code signature and notarization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BINARY_PATH="${1:-.build/release/mactools}"

echo "=================================================="
echo "MacTools Signature Verification"
echo "=================================================="
echo ""

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: Binary not found at $BINARY_PATH${NC}"
    exit 1
fi

# Check if running on macOS
if [ "$(uname)" != "Darwin" ]; then
    echo -e "${YELLOW}Warning: Verification is only available on macOS${NC}"
    exit 0
fi

echo "Binary: $BINARY_PATH"
echo ""

# Test 1: Check if signed
echo "Test 1: Checking code signature..."
if codesign -dv "$BINARY_PATH" 2>&1 | grep -q "Signature"; then
    echo -e "${GREEN}✓ Binary is signed${NC}"
else
    echo -e "${RED}✗ Binary is not signed${NC}"
    exit 1
fi

# Test 2: Verify signature
echo ""
echo "Test 2: Verifying signature validity..."
if codesign --verify --deep --strict --verbose=2 "$BINARY_PATH" 2>&1; then
    echo -e "${GREEN}✓ Signature is valid${NC}"
else
    echo -e "${RED}✗ Signature verification failed${NC}"
    exit 1
fi

# Test 3: Check for hardened runtime
echo ""
echo "Test 3: Checking hardened runtime..."
if codesign -dvvv "$BINARY_PATH" 2>&1 | grep -q "flags.*runtime"; then
    echo -e "${GREEN}✓ Hardened runtime enabled${NC}"
else
    echo -e "${YELLOW}⚠ Hardened runtime not enabled${NC}"
fi

# Test 4: Check for timestamp
echo ""
echo "Test 4: Checking timestamp..."
if codesign -dvvv "$BINARY_PATH" 2>&1 | grep -q "Timestamp"; then
    echo -e "${GREEN}✓ Signature includes timestamp${NC}"
else
    echo -e "${YELLOW}⚠ No timestamp found${NC}"
fi

# Test 5: Display signature info
echo ""
echo "Test 5: Signature information:"
echo "---"
codesign -dvvv "$BINARY_PATH" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier|Timestamp|CDHash"
echo "---"

# Test 6: Check notarization
echo ""
echo "Test 6: Checking notarization..."
if spctl -a -vv -t install "$BINARY_PATH" 2>&1 | grep -q "accepted"; then
    echo -e "${GREEN}✓ Binary is notarized (Gatekeeper approved)${NC}"
elif spctl -a -vv -t install "$BINARY_PATH" 2>&1 | grep -q "no usable signature"; then
    echo -e "${YELLOW}⚠ Binary is signed but not notarized${NC}"
    echo "Run: ./scripts/notarize.sh $BINARY_PATH"
else
    echo -e "${YELLOW}⚠ Notarization status unclear (may be normal for CLI tools)${NC}"
fi

# Test 7: Check for stapled ticket
echo ""
echo "Test 7: Checking for stapled ticket..."
if xcrun stapler validate "$BINARY_PATH" 2>&1 | grep -q "is valid"; then
    echo -e "${GREEN}✓ Notarization ticket is stapled${NC}"
else
    echo -e "${YELLOW}⚠ No stapled ticket (normal for command-line tools)${NC}"
fi

# Test 8: Check entitlements
echo ""
echo "Test 8: Checking entitlements..."
if codesign -d --entitlements - "$BINARY_PATH" 2>/dev/null | grep -q "<?xml"; then
    echo -e "${GREEN}✓ Binary has entitlements${NC}"
    echo "Entitlements:"
    codesign -d --entitlements - "$BINARY_PATH" 2>/dev/null | xmllint --format - 2>/dev/null || cat
else
    echo -e "${YELLOW}⚠ No entitlements found${NC}"
fi

# Summary
echo ""
echo "=================================================="
echo "Verification Summary"
echo "=================================================="

# Count passed tests
TESTS_PASSED=0
TESTS_TOTAL=8

if codesign -dv "$BINARY_PATH" 2>&1 | grep -q "Signature"; then
    ((TESTS_PASSED++))
fi

if codesign --verify --deep --strict "$BINARY_PATH" 2>/dev/null; then
    ((TESTS_PASSED++))
fi

if codesign -dvvv "$BINARY_PATH" 2>&1 | grep -q "flags.*runtime"; then
    ((TESTS_PASSED++))
fi

if codesign -dvvv "$BINARY_PATH" 2>&1 | grep -q "Timestamp"; then
    ((TESTS_PASSED++))
fi

# Signature info always passes if signed
((TESTS_PASSED++))

if spctl -a -vv -t install "$BINARY_PATH" 2>&1 | grep -q "accepted"; then
    ((TESTS_PASSED++))
fi

if xcrun stapler validate "$BINARY_PATH" 2>&1 | grep -q "is valid"; then
    ((TESTS_PASSED++))
fi

if codesign -d --entitlements - "$BINARY_PATH" 2>/dev/null | grep -q "<?xml"; then
    ((TESTS_PASSED++))
fi

echo ""
echo "Tests passed: $TESTS_PASSED/$TESTS_TOTAL"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
elif [ $TESTS_PASSED -ge 5 ]; then
    echo -e "${YELLOW}⚠ Some tests failed, but binary should work${NC}"
    exit 0
else
    echo -e "${RED}✗ Multiple tests failed${NC}"
    exit 1
fi

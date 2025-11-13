# Release Guide

Complete guide for packaging, distributing, and upgrading MacTools.

## Table of Contents

- [Release Formats](#release-formats)
- [Creating Releases](#creating-releases)
- [Distribution Channels](#distribution-channels)
- [Upgrade Procedures](#upgrade-procedures)
- [Uninstall Procedures](#uninstall-procedures)
- [Version Management](#version-management)
- [Release Checklist](#release-checklist)

## Release Formats

MacTools is distributed in multiple formats to accommodate different installation preferences:

### 1. Signed DMG (Recommended)

**File:** `mactools-vX.Y.Z-macos.dmg`

**Advantages:**
- Easy drag-and-drop installation
- Includes documentation and scripts
- Signed and notarized for security
- Best for manual installations

**Contents:**
```
MacTools vX.Y.Z.dmg
├── mactools (binary)
├── Install MacTools.command (helper script)
├── READ ME.txt
├── README.md
├── LICENSE
├── Documentation/
│   ├── user-guide.md
│   ├── TROUBLESHOOTING.md
│   ├── architecture.md
│   └── ...
├── Configs/
│   ├── default-config.json
│   └── com.mactools.daemon.plist
└── Scripts/
    ├── install.sh
    ├── upgrade.sh
    └── uninstall.sh
```

**Installation:**
1. Download and mount the DMG
2. Double-click "Install MacTools.command"
   OR drag `mactools` to `/usr/local/bin/`
3. Grant permissions via `mactools permissions --request`

### 2. Signed PKG Installer

**File:** `mactools-vX.Y.Z-macos.pkg`

**Advantages:**
- Native macOS installer experience
- Automated installation process
- Post-install configuration
- Best for enterprise deployment

**Installation:**
1. Download the PKG
2. Double-click to launch Installer
3. Follow the installation wizard
4. Grant permissions when prompted

**What it installs:**
- `/usr/local/bin/mactools` - Main executable
- `~/.config/mactools/` - Configuration directory
- `~/Library/LaunchAgents/com.mactools.daemon.plist` - LaunchAgent
- `/usr/local/share/mactools/` - Documentation and resources

### 3. Source Tarball

**File:** `mactools-vX.Y.Z-macos.tar.gz`

**Advantages:**
- Lightweight distribution
- For users who prefer manual setup
- CI/CD and automation friendly

**Contents:**
- `mactools` binary
- `README.md`, `LICENSE`
- Configuration files
- Installation scripts

**Installation:**
```bash
tar -xzf mactools-vX.Y.Z-macos.tar.gz
cd mactools-vX.Y.Z
sudo cp mactools /usr/local/bin/
chmod +x /usr/local/bin/mactools
```

### 4. GitHub Releases

All formats are published to GitHub Releases with:
- Release notes (generated from commits)
- SHA-256 checksums for verification
- Links to documentation
- Upgrade instructions

## Creating Releases

### Prerequisites

1. **Code Signing Certificate**
   - Apple Developer ID Application certificate
   - Installed in Keychain

2. **Notarization Credentials**
   - Apple ID
   - Team ID
   - App-specific password

3. **Environment Variables**
   ```bash
   export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM123456)"
   export INSTALLER_IDENTITY="Developer ID Installer: Your Name (TEAM123456)"
   export APPLE_ID="your@email.com"
   export TEAM_ID="TEAM123456"
   export NOTARIZATION_PASSWORD="xxxx-xxxx-xxxx-xxxx"
   ```

### Manual Release Process

#### 1. Build Release Binary

```bash
# Clean build
swift package clean

# Build in release mode
swift build -c release

# Verify binary
.build/release/mactools --version
```

#### 2. Sign Binary

```bash
./scripts/sign.sh .build/release/mactools
```

#### 3. Notarize Binary

```bash
./scripts/notarize.sh .build/release/mactools
```

#### 4. Create DMG

```bash
./scripts/create-dmg.sh v1.0.0 .build/release/mactools
```

This creates:
- `mactools-v1.0.0-macos.dmg`
- `mactools-v1.0.0-macos.dmg.sha256`

#### 5. Create PKG

```bash
./scripts/create-pkg.sh v1.0.0 .build/release/mactools
```

This creates:
- `mactools-v1.0.0-macos.pkg`
- `mactools-v1.0.0-macos.pkg.sha256`

#### 6. Verify Releases

```bash
# Verify DMG
hdiutil verify mactools-v1.0.0-macos.dmg

# Verify PKG signature
pkgutil --check-signature mactools-v1.0.0-macos.pkg

# Verify checksums
shasum -a 256 -c mactools-v1.0.0-macos.dmg.sha256
shasum -a 256 -c mactools-v1.0.0-macos.pkg.sha256
```

### Automated Release Process (CI/CD)

Releases are automatically created by GitHub Actions when a version tag is pushed:

#### 1. Tag Release

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0: Feature summary"

# Push tag
git push origin v1.0.0
```

#### 2. CI Pipeline Runs

The `.github/workflows/release.yml` workflow automatically:
1. Builds the release binary
2. Runs all tests
3. Signs the binary
4. Notarizes the binary
5. Creates DMG and PKG
6. Generates checksums
7. Creates GitHub Release with artifacts

#### 3. Release Notes

GitHub automatically generates release notes from commit messages. Edit the release on GitHub to:
- Add upgrade instructions
- Highlight new features
- Document breaking changes
- Link to documentation

## Distribution Channels

### 1. GitHub Releases

**Primary distribution channel**

All releases are published to:
`https://github.com/acs9307/mac-tools/releases`

Users can:
- Download DMG, PKG, or tarball
- View release notes
- Verify checksums
- Browse previous versions

### 2. Direct Download

For automated deployments:

```bash
# Download latest release
VERSION="v1.0.0"
curl -L -O "https://github.com/acs9307/mac-tools/releases/download/${VERSION}/mactools-${VERSION}-macos.dmg"

# Verify checksum
curl -L -O "https://github.com/acs9307/mac-tools/releases/download/${VERSION}/mactools-${VERSION}-macos.dmg.sha256"
shasum -a 256 -c mactools-${VERSION}-macos.dmg.sha256
```

### 3. Homebrew (Future)

Planned Homebrew tap for easy installation:

```bash
brew install acs9307/tap/mactools
```

## Upgrade Procedures

### Upgrading via DMG

1. **Download New Version**
   ```bash
   # Download from GitHub Releases
   ```

2. **Mount DMG**
   ```bash
   open mactools-v1.1.0-macos.dmg
   ```

3. **Run Upgrade Script**
   ```bash
   cd /Volumes/MacTools\ v1.1.0/
   ./Scripts/upgrade.sh
   ```

   The upgrade script:
   - Backs up your configuration
   - Stops the running daemon
   - Replaces the binary
   - Restarts the daemon
   - Preserves all settings

### Upgrading via PKG

1. **Download New PKG**
   ```bash
   # Download from GitHub Releases
   ```

2. **Run Installer**
   ```bash
   open mactools-v1.1.0-macos.pkg
   ```

   The installer:
   - Automatically stops the daemon (preinstall script)
   - Replaces the binary
   - Preserves configuration
   - Reconfigures if needed (postinstall script)

3. **Verify Upgrade**
   ```bash
   mactools --version
   # Should show v1.1.0
   ```

### Upgrading via Script

For automation:

```bash
# Download upgrade script
curl -O https://raw.githubusercontent.com/acs9307/mac-tools/main/scripts/upgrade.sh
chmod +x upgrade.sh

# Download new binary
curl -L -O https://github.com/acs9307/mac-tools/releases/download/v1.1.0/mactools-v1.1.0-macos.tar.gz
tar -xzf mactools-v1.1.0-macos.tar.gz

# Run upgrade
./upgrade.sh ./mactools
```

### Configuration Preservation

During upgrades:
- ✅ `~/.config/mactools/config.json` is **preserved**
- ✅ Backup created at `~/.config/mactools.backup.YYYYMMDD-HHMMSS`
- ✅ LaunchAgent plist is **preserved**
- ✅ Permissions remain granted

### Post-Upgrade Verification

```bash
# Check version
mactools --version

# Check daemon status
launchctl list | grep mactools

# Check permissions
mactools permissions

# Test functionality
mactools capslock status
```

### Rollback

If issues occur, rollback to previous version:

```bash
# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist

# Restore old binary
sudo cp /usr/local/bin/mactools.backup /usr/local/bin/mactools

# Restore configuration (if needed)
rm -rf ~/.config/mactools
cp -r ~/.config/mactools.backup.YYYYMMDD-HHMMSS ~/.config/mactools

# Restart daemon
launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist
```

## Uninstall Procedures

### Complete Uninstall

#### Using Uninstall Script (Recommended)

```bash
# If installed via DMG
cd /Volumes/MacTools\ vX.Y.Z/
./Scripts/uninstall.sh

# If downloaded separately
curl -O https://raw.githubusercontent.com/acs9307/mac-tools/main/scripts/uninstall.sh
chmod +x uninstall.sh
./uninstall.sh
```

The script removes:
- Binary: `/usr/local/bin/mactools`
- LaunchAgent: `~/Library/LaunchAgents/com.mactools.daemon.plist`
- Configuration: `~/.config/mactools/`
- Application Support: `~/Library/Application Support/MacTools/`
- Logs: `~/Library/Logs/MacTools/`

#### Manual Uninstall

```bash
# 1. Stop daemon
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist
killall mactools

# 2. Remove binary
sudo rm /usr/local/bin/mactools

# 3. Remove LaunchAgent
rm ~/Library/LaunchAgents/com.mactools.daemon.plist

# 4. Remove configuration (optional)
rm -rf ~/.config/mactools

# 5. Remove application support (optional)
rm -rf ~/Library/Application\ Support/MacTools

# 6. Remove logs (optional)
rm -rf ~/Library/Logs/MacTools

# 7. Remove from Accessibility
# Go to System Settings > Privacy & Security > Accessibility
# Remove mactools from the list
```

### Partial Uninstall (Keep Configuration)

To remove MacTools but preserve settings:

```bash
# Stop and remove daemon
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist
sudo rm /usr/local/bin/mactools
rm ~/Library/LaunchAgents/com.mactools.daemon.plist

# Configuration remains at ~/.config/mactools/
# Reinstall later to restore settings
```

## Version Management

### Version Numbering

MacTools follows [Semantic Versioning](https://semver.org/):

**Format:** `vMAJOR.MINOR.PATCH`

- **MAJOR**: Incompatible API changes or major feature additions
- **MINOR**: Backwards-compatible functionality additions
- **PATCH**: Backwards-compatible bug fixes

**Examples:**
- `v1.0.0` - Initial stable release
- `v1.1.0` - New feature (ScrollMaster enhancements)
- `v1.1.1` - Bug fix (fixed scroll lag)
- `v2.0.0` - Breaking change (new configuration format)

### Pre-Release Versions

For testing and beta releases:

- **Alpha**: `v1.1.0-alpha.1`
- **Beta**: `v1.1.0-beta.1`
- **Release Candidate**: `v1.1.0-rc.1`

### Version in Code

Update version in `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacTools",
    platforms: [.macOS(.v13)],
    // ...
)
```

And in the CLI:

```swift
// Sources/MacToolsCLI/main.swift
let version = "1.0.0"
```

### Git Tags

Create annotated tags for releases:

```bash
# Good tag message
git tag -a v1.0.0 -m "Release v1.0.0

Major features:
- Caps Lock remapping with configurable actions
- Per-device scroll behavior
- Display layout auto-arrangement

Breaking changes:
- None (initial release)
"

# Push tag
git push origin v1.0.0
```

## Release Checklist

Use this checklist before each release:

### Pre-Release

- [ ] All tests passing
- [ ] Code coverage ≥ 90%
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in code
- [ ] No open critical bugs
- [ ] All PRs merged to main

### Build

- [ ] Clean build successful
- [ ] Binary works on clean macOS
- [ ] All features functional
- [ ] Permissions work correctly
- [ ] Configuration loads/saves
- [ ] Daemon starts/stops cleanly

### Code Signing

- [ ] Binary signed with Developer ID
- [ ] Signature verified
- [ ] Hardened runtime enabled
- [ ] Entitlements correct
- [ ] Binary notarized by Apple
- [ ] Notarization ticket stapled

### Packaging

- [ ] DMG created and verified
- [ ] PKG created and verified
- [ ] Tarball created
- [ ] All checksums generated
- [ ] Installation tested from DMG
- [ ] Installation tested from PKG

### Distribution

- [ ] Git tag created
- [ ] Tag pushed to GitHub
- [ ] CI/CD pipeline completed
- [ ] GitHub Release created
- [ ] Release notes written
- [ ] Artifacts uploaded
- [ ] Checksums posted

### Post-Release

- [ ] Clean install tested
- [ ] Upgrade from previous version tested
- [ ] Documentation links work
- [ ] Download links work
- [ ] Checksums verify correctly
- [ ] Announced on GitHub Discussions
- [ ] Social media announcement (if applicable)

## Troubleshooting Releases

### DMG Creation Fails

**Issue:** `hdiutil: create failed - Resource busy`

**Solution:**
```bash
# Unmount any mounted DMGs
hdiutil detach /Volumes/MacTools* -force

# Retry
./scripts/create-dmg.sh v1.0.0 .build/release/mactools
```

### Notarization Fails

**Issue:** "The binary is not signed"

**Solution:**
```bash
# Sign first
./scripts/sign.sh .build/release/mactools

# Then notarize
./scripts/notarize.sh .build/release/mactools
```

**Issue:** "Could not find the RequestUUID"

**Solution:**
```bash
# Check credentials
echo $APPLE_ID
echo $TEAM_ID
echo $NOTARIZATION_PASSWORD

# Verify app-specific password is correct
# Generate new one at appleid.apple.com if needed
```

### Installation Issues

**Issue:** "mactools is damaged and can't be opened"

**Cause:** Not signed or notarized

**Solution:**
1. Download from official GitHub Releases only
2. Verify checksum matches
3. If building yourself, ensure signing and notarization complete

**Issue:** Package installation fails with "unidentified developer"

**Solution:**
1. Right-click PKG and choose "Open"
2. Click "Open" in the security dialog
3. Or: System Settings > Privacy & Security > Allow

## Support

For release-related issues:
- GitHub Issues: https://github.com/acs9307/mac-tools/issues
- Discussions: https://github.com/acs9307/mac-tools/discussions

For security issues:
- Email: security@mactools.example.com

---

**Last Updated:** 2024-11-13

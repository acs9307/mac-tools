# MacTools

[![CI](https://github.com/acs9307/mac-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/acs9307/mac-tools/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/acs9307/mac-tools/branch/main/graph/badge.svg)](https://codecov.io/gh/acs9307/mac-tools)

A powerful suite of macOS system tools for key and window manipulation, installable as system daemons for seamless background operation.

## Features

- **Key Manipulation**: Global hotkey registration, key event simulation, and text typing
- **Window Manipulation**: Window positioning, resizing, arrangement presets, and multi-monitor support
- **Daemon Architecture**: Lightweight background service with automatic startup
- **Modular Design**: Independent agents that can be enabled/disabled individually
- **Rich CLI**: Comprehensive command-line interface for all operations
- **Full Test Coverage**: Extensive test suite ensuring reliability

## Architecture

MacTools is built with a modular architecture:

- **MacToolsCore**: Core daemon infrastructure and agent management
- **KeyManipulation**: Key event handling and global hotkey system
- **WindowManipulation**: Window management and arrangement operations
- **MacToolsCLI**: Command-line interface

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- Xcode Command Line Tools

## Installation

### Quick Install

```bash
./scripts/install.sh
```

This will:
1. Build the project in release mode
2. Install the `mactools` binary to `/usr/local/bin`
3. Install the daemon configuration
4. Create the configuration directory
5. Optionally start the daemon

### Manual Installation

```bash
# Build the project
swift build -c release

# Install manually using Make
make install

# Or copy the binary yourself
sudo cp .build/release/mactools /usr/local/bin/
```

## Permissions

MacTools requires **Accessibility** permissions to function properly. This is necessary for:
- Monitoring and simulating key events
- Accessing and manipulating window properties
- Detecting focused windows and applications

### Grant Permissions

1. Run the permission check:
   ```bash
   mactools permissions --request
   ```

2. Go to **System Settings** > **Privacy & Security** > **Accessibility**

3. Enable MacTools in the list

## Usage

### Daemon Management

```bash
# Start daemon in foreground
mactools daemon --foreground

# Start daemon with launchd (automatic on login)
launchctl load ~/Library/LaunchAgents/com.mactools.daemon.plist

# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist

# Check daemon status
launchctl list | grep mactools
```

### Window Operations

```bash
# List all windows
mactools window list

# List windows for a specific app
mactools window list --app com.apple.Safari

# Get focused window
mactools window focus

# Maximize focused window
mactools window maximize

# Center focused window
mactools window center
```

### Key Operations

```bash
# Type text (waits 2 seconds before typing)
mactools key type "Hello, World!"
```

### Configuration

```bash
# Show current configuration
mactools config show

# Get a specific value
mactools config get daemon.logLevel

# Set a configuration value
mactools config set daemon.logLevel debug

# Reset to defaults
mactools config reset
```

### Permissions

```bash
# Check permission status
mactools permissions

# Request permissions (prompts user)
mactools permissions --request
```

## Configuration

Configuration files are stored in `~/.config/mactools/config.json`.

### Default Configuration

```json
{
  "daemon": {
    "autoStart": true,
    "logLevel": "info"
  },
  "keyManipulation": {
    "enabled": true,
    "hotkeys": {}
  },
  "windowManipulation": {
    "animationDuration": 0.2,
    "animations": true,
    "enabled": true
  }
}
```

### Hotkey Configuration

Add custom hotkeys in the configuration:

```json
{
  "keyManipulation": {
    "hotkeys": {
      "maximize-window": {
        "keyCode": 3,
        "modifiers": ["command", "control", "shift"]
      }
    }
  }
}
```

## Development

### Building

```bash
# Build in debug mode
swift build

# Build in release mode
swift build -c release

# Using Make
make build
```

### Testing

```bash
# Run all tests
swift test

# Run with coverage
make coverage

# Using Make
make test
```

### Code Quality

```bash
# Run SwiftLint
make lint

# Format code
make format
```

### Project Structure

```
mac-tools/
├── Package.swift                 # Swift Package Manager manifest
├── Makefile                      # Build automation
├── README.md                     # This file
├── Sources/
│   ├── MacToolsCore/            # Core daemon infrastructure
│   │   ├── Agent.swift          # Agent protocol and base class
│   │   ├── DaemonManager.swift  # Agent lifecycle management
│   │   ├── Configuration.swift  # Configuration management
│   │   └── PermissionsManager.swift # System permissions
│   ├── KeyManipulation/         # Key manipulation module
│   │   ├── KeyCode.swift        # Key code definitions
│   │   ├── Hotkey.swift         # Global hotkey registration
│   │   └── KeyManipulationAgent.swift # Key agent
│   ├── WindowManipulation/      # Window manipulation module
│   │   ├── Window.swift         # Window representation
│   │   ├── Application.swift    # Application representation
│   │   └── WindowManipulationAgent.swift # Window agent
│   └── MacToolsCLI/             # CLI application
│       └── main.swift           # Entry point
├── Tests/                       # Test suites
│   ├── MacToolsCoreTests/
│   ├── KeyManipulationTests/
│   └── WindowManipulationTests/
├── configs/                     # Configuration files
│   └── com.mactools.daemon.plist # Launchd configuration
└── scripts/                     # Installation scripts
    ├── install.sh
    └── uninstall.sh
```

## API Documentation

### MacToolsCore

#### Agent Protocol

All agent modules implement the `Agent` protocol:

```swift
public protocol Agent: AnyObject {
    var identifier: String { get }
    var name: String { get }
    var isRunning: Bool { get }

    func start() async throws
    func stop() async throws
    func configure(_ config: [String: Any]) async throws
}
```

#### DaemonManager

Singleton that manages all registered agents:

```swift
let manager = DaemonManager.shared
try manager.register(agent)
try await manager.startAll()
await manager.stopAll()
```

### KeyManipulation

#### KeyCode

Represents keyboard keys with modifiers:

```swift
let keyCode = KeyCode(code: 0, modifiers: [.command, .shift])
// Or use predefined keys
let space = KeyCode.space
let enter = KeyCode.return
```

#### Hotkey Registration

```swift
let agent = KeyManipulationAgent()
try await agent.start()

try agent.registerHotkey(
    identifier: "my-hotkey",
    keyCode: KeyCode(code: 3, modifiers: [.command, .control])
) {
    print("Hotkey triggered!")
}
```

### WindowManipulation

#### Window Operations

```swift
let agent = WindowManipulationAgent()
try await agent.start()

// Get focused window
if let window = try agent.getFocusedWindow() {
    // Maximize
    try agent.maximizeWindow(window)

    // Center
    try agent.centerWindow(window)

    // Custom positioning
    try agent.moveWindow(window, to: CGPoint(x: 100, y: 100))
    try agent.resizeWindow(window, to: CGSize(width: 800, height: 600))
}
```

## Troubleshooting

### Daemon won't start

1. Check permissions: `mactools permissions`
2. Check logs: `cat /tmp/mactools.log`
3. Try running in foreground: `mactools daemon --foreground`

### Hotkeys not working

1. Ensure accessibility permissions are granted
2. Verify hotkey configuration: `mactools config show`
3. Check for key code conflicts with other applications

### Window operations failing

1. Verify accessibility permissions
2. Check that the target application supports accessibility APIs
3. Some applications may restrict window manipulation

## Uninstallation

```bash
./scripts/uninstall.sh
```

Or manually:

```bash
# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.mactools.daemon.plist

# Remove files
sudo rm /usr/local/bin/mactools
rm ~/Library/LaunchAgents/com.mactools.daemon.plist
rm -rf ~/.config/mactools
```

## Contributing

Contributions are welcome! Please ensure:

1. All new code has test coverage
2. Tests pass: `swift test`
3. Code follows Swift style guidelines
4. Documentation is updated

## License

MIT License - see LICENSE file for details

## Security

MacTools requires elevated permissions to function. Please review the source code before installation. Never grant accessibility permissions to software you don't trust.

## Credits

Built with Swift and the macOS Accessibility APIs.

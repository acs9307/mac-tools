# Changelog

All notable changes to MacTools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-11-13

### Added

#### Core Infrastructure
- Agent-based daemon architecture
- DaemonManager for lifecycle management
- BaseAgent class for easy agent implementation
- Configuration management system with JSON persistence
- PermissionsManager for macOS accessibility permissions
- Comprehensive error handling with AgentError types
- Full test coverage for core infrastructure

#### Key Manipulation
- KeyCode representation with modifier support
- Global hotkey registration system
- Key event simulation
- Text typing via key simulation
- KeyManipulationAgent with full daemon integration
- Configuration-based hotkey definitions
- Comprehensive test suite

#### Window Manipulation
- Window and Application abstractions
- Window positioning and resizing
- Window focus and minimize operations
- Window arrangement presets:
  - Maximize to full screen
  - Left/right half
  - Center window
- WindowManipulationAgent with daemon integration
- Animation support for smooth transitions
- Full test coverage

#### CLI Interface
- Command-line tool with subcommands:
  - `daemon` - Daemon management
  - `permissions` - Permission checking and requesting
  - `config` - Configuration management
  - `window` - Window operations
  - `key` - Key manipulation
- Built with Swift Argument Parser
- Rich help and error messages

#### Installation & Configuration
- Automated installation script
- Uninstallation script
- Launchd daemon configuration
- Makefile for common tasks
- SwiftLint configuration
- .gitignore for Swift projects

#### Documentation
- Comprehensive README with examples
- API documentation
- Contributing guidelines
- MIT License
- Changelog

### Dependencies
- Swift 5.9+
- macOS 13.0+
- swift-argument-parser 1.3.0+
- swift-log 1.5.0+

### Requirements
- Accessibility permissions for full functionality
- Xcode Command Line Tools

[Unreleased]: https://github.com/yourusername/mac-tools/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/mac-tools/releases/tag/v0.1.0

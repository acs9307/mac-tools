# Contributing to MacTools

Thank you for your interest in contributing to MacTools! This guide will help you get started.

## Code of Conduct

- Be respectful and constructive
- Welcome newcomers and help them learn
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/mac-tools.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `swift test`
6. Commit your changes: `git commit -m "Description of changes"`
7. Push to your fork: `git push origin feature/your-feature-name`
8. Open a Pull Request

## Development Setup

### Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- Xcode Command Line Tools

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release
```

### Running Tests

```bash
# Run all tests
swift test

# Run with coverage
make coverage

# Run specific test
swift test --filter AgentTests
```

## Coding Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation (no tabs)
- Maximum line length: 120 characters
- Use meaningful variable and function names
- Add documentation comments for public APIs

### Example

```swift
/// Represents a keyboard key with its code and modifiers
public struct KeyCode: Equatable, Hashable {
    /// The virtual key code
    public let code: Int

    /// Modifier flags
    public let modifiers: ModifierFlags

    public init(code: Int, modifiers: ModifierFlags = []) {
        self.code = code
        self.modifiers = modifiers
    }
}
```

### Code Quality

Before submitting a PR:

1. Run SwiftLint: `make lint`
2. Format code: `make format`
3. Ensure all tests pass: `swift test`
4. Check test coverage: `make coverage`

## Testing Requirements

### All Code Must Have Tests

- Write tests for new features
- Update tests for modified code
- Aim for >80% code coverage
- Test both success and failure cases

### Test Structure

```swift
import XCTest
@testable import MacToolsCore

final class YourFeatureTests: XCTestCase {
    var sut: YourFeature!  // System Under Test

    override func setUp() {
        sut = YourFeature()
    }

    override func tearDown() {
        sut = nil
    }

    func testFeatureBehavior() {
        // Arrange
        let input = "test"

        // Act
        let result = sut.process(input)

        // Assert
        XCTAssertEqual(result, "expected")
    }
}
```

## Pull Request Process

### Before Submitting

1. Ensure your code builds without warnings
2. All tests pass
3. Add tests for new functionality
4. Update documentation
5. Follow commit message guidelines

### Commit Messages

Use clear, descriptive commit messages:

```
Add feature to support custom hotkey bindings

- Implement HotkeyManager for global hotkey registration
- Add tests for hotkey registration and triggering
- Update documentation with hotkey examples

Fixes #123
```

Format:
- First line: Brief summary (50 chars or less)
- Blank line
- Detailed description (wrap at 72 chars)
- Reference related issues

### PR Description

Include in your PR:

1. **What**: Brief description of changes
2. **Why**: Motivation and context
3. **How**: Implementation approach
4. **Testing**: How you tested the changes
5. **Screenshots**: If applicable

### Review Process

1. Maintainers will review your PR
2. Address feedback and make requested changes
3. Once approved, your PR will be merged

## Areas for Contribution

### High Priority

- Additional window arrangement presets (quarters, thirds, etc.)
- Multi-monitor support enhancements
- Hotkey conflict detection
- Configuration GUI

### Medium Priority

- Additional key manipulation features
- Window history and undo/redo
- Application-specific configurations
- Custom scripting support

### Documentation

- Improve API documentation
- Add more examples
- Create video tutorials
- Write blog posts

### Testing

- Increase test coverage
- Add integration tests
- Performance benchmarks

## Project Structure

```
mac-tools/
├── Sources/
│   ├── MacToolsCore/          # Core infrastructure
│   ├── KeyManipulation/       # Key manipulation
│   ├── WindowManipulation/    # Window manipulation
│   └── MacToolsCLI/           # CLI interface
├── Tests/                     # Test suites
├── configs/                   # Configuration files
└── scripts/                   # Installation scripts
```

## Adding a New Agent

1. Create agent class extending `BaseAgent`:

```swift
public final class MyAgent: BaseAgent {
    public init() {
        super.init(identifier: "my.agent", name: "My Agent")
    }

    override public func performStart() throws {
        // Initialization logic
    }

    override public func performStop() throws {
        // Cleanup logic
    }
}
```

2. Add tests in `Tests/MyAgentTests/`

3. Register in CLI or daemon

4. Update documentation

## Adding a New CLI Command

1. Add command in `Sources/MacToolsCLI/main.swift`:

```swift
struct MyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Description of command"
    )

    func run() async throws {
        // Implementation
    }
}
```

2. Add to parent command's subcommands

3. Update README with usage examples

## Release Process

1. Update version in `Package.swift`
2. Update CHANGELOG.md
3. Create git tag: `git tag v0.2.0`
4. Push tag: `git push origin v0.2.0`
5. Create GitHub release

## Getting Help

- Open an issue for bugs or feature requests
- Start a discussion for questions
- Check existing issues and PRs

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Credited in release notes
- Given credit in relevant documentation

Thank you for contributing to MacTools! 🎉

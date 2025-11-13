# Testing Guidelines

Comprehensive guide for writing tests in MacTools.

## Table of Contents

- [Overview](#overview)
- [Testing Philosophy](#testing-philosophy)
- [Test Structure](#test-structure)
- [Unit Testing](#unit-testing)
- [Integration Testing](#integration-testing)
- [Test Organization](#test-organization)
- [Common Patterns](#common-patterns)
- [Mocking System APIs](#mocking-system-apis)
- [Running Tests](#running-tests)
- [Code Coverage](#code-coverage)
- [Best Practices](#best-practices)

## Overview

MacTools follows a test-driven development approach with comprehensive test coverage. All new features must include tests before merging.

**Test Statistics:**
- Total Tests: 600+
- Code Coverage: >90%
- Test Execution Time: <30 seconds

## Testing Philosophy

### Definition of Done

Every issue must satisfy:
1. ✓ All tests pass
2. ✓ Code coverage ≥ 80% for new code
3. ✓ Edge cases covered
4. ✓ Documentation updated

### Test Types

```
┌──────────────────────────────────────┐
│          Unit Tests (80%)            │
│  - Pure logic                        │
│  - State machines                    │
│  - Data structures                   │
│  - Algorithms                        │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│      Integration Tests (15%)         │
│  - Multi-component workflows         │
│  - Configuration reload              │
│  - Agent interactions                │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│         UI Tests (5%)                │
│  - ViewModel logic                   │
│  - SwiftUI previews                  │
└──────────────────────────────────────┘
```

## Test Structure

### File Organization

```
Tests/
├── MacToolsCoreTests/
│   ├── AgentTests.swift
│   ├── ConfigurationTests.swift
│   ├── PermissionsTests.swift
│   ├── LoggingTests.swift
│   └── TelemetryTests.swift
├── CapsLockAgentTests/
│   ├── CapsLockAgentTests.swift
│   ├── KeyStateMachineTests.swift
│   ├── EventTapManagerTests.swift
│   └── EventSynthesizerTests.swift
├── ScrollMasterTests/
│   ├── ScrollMasterAgentTests.swift
│   ├── DeviceRegistryTests.swift
│   ├── ScrollTransformTests.swift
│   └── SmoothScrollEngineTests.swift
└── DisplayLayoutsTests/
    ├── DisplayIdentityTests.swift
    ├── WindowLayoutTests.swift
    ├── LayoutPresetTests.swift
    └── LayoutUndoTests.swift
```

### Test Class Template

```swift
import XCTest
@testable import ModuleName

final class ComponentTests: XCTestCase {
    var component: Component!

    override func setUp() {
        super.setUp()
        component = Component()
    }

    override func tearDown() {
        component = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(component)
    }

    // MARK: - Functionality Tests

    func testFeatureA() {
        // Arrange
        let input = "test"

        // Act
        let result = component.process(input)

        // Assert
        XCTAssertEqual(result, "expected")
    }

    // MARK: - Edge Case Tests

    func testEmptyInput() {
        let result = component.process("")
        XCTAssertTrue(result.isEmpty)
    }
}
```

## Unit Testing

### Pure Logic

Test pure functions with no side effects:

```swift
func testScrollTransformInversion() {
    var transform = ScrollTransform()
    transform.invertVertical = true

    let input = ScrollDelta(vertical: 10, horizontal: 0)
    let output = transform.apply(to: input)

    XCTAssertEqual(output.vertical, -10)
    XCTAssertEqual(output.horizontal, 0)
}
```

### State Machines

Test all transitions exhaustively:

```swift
func testKeyStateMachineTransitions() {
    let machine = KeyStateMachine(threshold: 0.2)

    // Initial state
    XCTAssertEqual(machine.state, .idle)

    // Key down
    machine.handleKeyDown(timestamp: 0.0)
    XCTAssertEqual(machine.state, .pressed)

    // Quick release
    machine.handleKeyUp(timestamp: 0.1)
    XCTAssertEqual(machine.state, .quickTap)

    // Reset
    machine.reset()
    XCTAssertEqual(machine.state, .idle)
}
```

### Data Structures

Test serialization, equality, hashing:

```swift
func testDisplayIdentityEquality() {
    let display1 = DisplayIdentity(
        displayID: 1,
        vendorID: 0x1234,
        modelID: 0x5678
    )

    let display2 = DisplayIdentity(
        displayID: 2,  // Different ID
        vendorID: 0x1234,
        modelID: 0x5678
    )

    // Should be equal (stable ID)
    XCTAssertEqual(display1.stableID, display2.stableID)
}

func testDisplayIdentityCodable() throws {
    let display = DisplayIdentity(...)

    let data = try JSONEncoder().encode(display)
    let decoded = try JSONDecoder().decode(DisplayIdentity.self, from: data)

    XCTAssertEqual(decoded, display)
}
```

### Algorithms

Test correctness and edge cases:

```swift
func testSmoothScrollEngine() {
    let engine = SmoothScrollEngine()

    // Add input
    engine.addInput(delta: 10.0)

    // Tick through animation
    var totalOutput = 0.0
    for _ in 0..<30 {  // 30 frames @ 60fps = 0.5s
        totalOutput += engine.tick(deltaTime: 1.0/60.0)
    }

    // Total output should equal input
    XCTAssertEqual(totalOutput, 10.0, accuracy: 0.1)
}
```

## Integration Testing

### Multi-Component Workflows

```swift
func testConfigurationReload() {
    let daemon = DaemonManager()
    let agent = CapsLockAgent()

    // Register agent
    daemon.registerAgent(agent)

    // Modify configuration
    var config = agent.configuration
    config.minPressDuration = 0.5
    try agent.updateConfiguration(config)

    // Reload
    try agent.reloadConfiguration()

    // Verify
    XCTAssertEqual(agent.configuration.minPressDuration, 0.5)
}
```

### Agent Lifecycle

```swift
func testAgentStartStop() {
    let agent = ScrollMasterAgent()

    XCTAssertFalse(agent.isRunning)

    agent.start()
    XCTAssertTrue(agent.isRunning)

    agent.stop()
    XCTAssertFalse(agent.isRunning)
}
```

## Test Organization

### Test Grouping with MARK

```swift
final class ComponentTests: XCTestCase {
    // MARK: - Initialization Tests

    func testDefaultInitialization() { }
    func testCustomInitialization() { }

    // MARK: - Configuration Tests

    func testLoadConfiguration() { }
    func testSaveConfiguration() { }

    // MARK: - Edge Case Tests

    func testEmptyInput() { }
    func testNilInput() { }
    func testLargeInput() { }
}
```

### Descriptive Test Names

```swift
// ❌ Bad
func testConfig() { }
func testError1() { }

// ✅ Good
func testConfigurationLoadsFromDisk() { }
func testInvalidJSONThrowsDecodingError() { }
```

## Common Patterns

### Arrange-Act-Assert

```swift
func testFeature() {
    // Arrange: Set up test data
    let input = "test"
    let expected = "TEST"

    // Act: Perform operation
    let result = component.process(input)

    // Assert: Verify result
    XCTAssertEqual(result, expected)
}
```

### Given-When-Then

```swift
func testFeature() {
    // Given a component with configuration
    component.configuration.enabled = true

    // When processing input
    let result = component.process("test")

    // Then result matches expected
    XCTAssertEqual(result, "expected")
}
```

### Test Fixtures

```swift
final class ComponentTests: XCTestCase {
    // Shared test data
    let testDisplays: [DisplayIdentity] = [
        DisplayIdentity(displayID: 1, vendorID: 0x1234, modelID: 0x5678),
        DisplayIdentity(displayID: 2, vendorID: 0x1234, modelID: 0x5679)
    ]

    func testFeatureA() {
        // Use testDisplays
    }

    func testFeatureB() {
        // Reuse testDisplays
    }
}
```

### Testing Errors

```swift
func testInvalidInputThrowsError() {
    XCTAssertThrowsError(try component.process(invalid)) { error in
        guard let componentError = error as? ComponentError else {
            XCTFail("Wrong error type")
            return
        }

        XCTAssertEqual(componentError, .invalidInput)
    }
}
```

### Testing Async Code

```swift
func testAsyncOperation() {
    let expectation = expectation(description: "Async operation")

    component.performAsync { result in
        XCTAssertNotNil(result)
        expectation.fulfill()
    }

    waitForExpectations(timeout: 5.0)
}
```

## Mocking System APIs

### Mock CGEventTap

```swift
class MockEventTap: EventTapProtocol {
    var capturedEvents: [CGEvent] = []

    func createEventTap(...) -> CFMachPort? {
        // Return mock tap
    }

    func enable() { /* Mock */ }
    func disable() { /* Mock */ }
}

// In tests
func testEventProcessing() {
    let mockTap = MockEventTap()
    let agent = CapsLockAgent(eventTap: mockTap)

    // Simulate events
    mockTap.simulateKeyDown()

    XCTAssertEqual(mockTap.capturedEvents.count, 1)
}
```

### Mock IOKit

```swift
class MockDeviceEnumerator: DeviceEnumeratorProtocol {
    var mockDevices: [DeviceIdentity] = []

    func enumerateDevices() -> [DeviceIdentity] {
        return mockDevices
    }
}

// In tests
func testDeviceDetection() {
    let mock = MockDeviceEnumerator()
    mock.mockDevices = [testDevice1, testDevice2]

    let agent = ScrollMasterAgent(enumerator: mock)
    let devices = agent.detectedDevices

    XCTAssertEqual(devices.count, 2)
}
```

### Mock File System

```swift
func testConfigurationPersistence() throws {
    // Use temporary directory
    let tempDir = FileManager.default.temporaryDirectory
    let configURL = tempDir.appendingPathComponent("test-config.json")

    // Create configuration manager with temp path
    let manager = ConfigurationManager(configURL: configURL)

    // Test
    try manager.save(config)
    let loaded = try manager.load()

    XCTAssertEqual(loaded, config)

    // Cleanup
    try? FileManager.default.removeItem(at: configURL)
}
```

## Running Tests

### Command Line

```bash
# All tests
swift test

# Specific test target
swift test --filter MacToolsCoreTests

# Specific test class
swift test --filter MacToolsCoreTests.ConfigurationTests

# Specific test method
swift test --filter MacToolsCoreTests.ConfigurationTests/testSaveConfiguration

# Parallel execution
swift test --parallel

# Generate code coverage
swift test --enable-code-coverage
```

### Xcode

1. Open Package.swift in Xcode
2. Select test target
3. Cmd+U to run all tests
4. Cmd+Ctrl+Option+G to run last test

### CI (GitHub Actions)

```yaml
- name: Run tests
  run: swift test --parallel --enable-code-coverage
```

## Code Coverage

### Viewing Coverage

```bash
# Generate coverage
swift test --enable-code-coverage

# View report
xcrun llvm-cov show \
  .build/debug/MacToolsPackageTests.xctest/Contents/MacOS/MacToolsPackageTests \
  -instr-profile .build/debug/codecov/default.profdata
```

### Coverage Goals

- Overall: ≥ 90%
- New features: ≥ 80%
- Critical paths: 100%
- UI code: ≥ 60% (ViewModels)

### Excluding Code

```swift
// Exclude from coverage (system-dependent)
// coverage: ignore
func systemSpecificCode() {
    // Won't affect coverage metrics
}
```

## Best Practices

### DO

✓ **Write tests first** (TDD)
✓ **Test one thing** per test method
✓ **Use descriptive names**
✓ **Test edge cases** (empty, nil, large, negative)
✓ **Test error conditions**
✓ **Keep tests independent** (no shared state)
✓ **Use setUp/tearDown** for common initialization
✓ **Mock system dependencies**
✓ **Assert specific values** (not just non-nil)
✓ **Test thread safety** for concurrent code

### DON'T

✗ **Don't test implementation** (test behavior)
✗ **Don't share mutable state** between tests
✗ **Don't depend on execution order**
✗ **Don't test Apple frameworks** (trust they work)
✗ **Don't use sleep()** (use expectations)
✗ **Don't ignore flaky tests** (fix them)
✗ **Don't skip cleanup** in tearDown
✗ **Don't test too much** in one method

### Example: Good vs Bad

```swift
// ❌ Bad: Tests multiple things
func testConfiguration() {
    component.load()
    XCTAssertNotNil(component.config)
    component.save()
    XCTAssertTrue(FileManager.default.fileExists(at: url))
}

// ✅ Good: Focused tests
func testConfigurationLoads() {
    component.load()
    XCTAssertNotNil(component.config)
}

func testConfigurationSavesToDisk() {
    component.save()
    XCTAssertTrue(FileManager.default.fileExists(at: url))
}
```

## Testing Checklist

Before submitting code, verify:

- [ ] All tests pass
- [ ] New code has tests
- [ ] Edge cases covered
- [ ] Error paths tested
- [ ] Code coverage ≥ 80%
- [ ] No flaky tests
- [ ] Tests are independent
- [ ] Cleanup in tearDown
- [ ] Mock system dependencies
- [ ] Descriptive test names

## Common Test Scenarios

### Testing Configuration

```swift
func testConfigurationDefaults() {
    let config = CapsLockConfiguration()
    XCTAssertEqual(config.minPressDuration, 0.2)
}

func testConfigurationCodable() throws {
    let config = CapsLockConfiguration(minPressDuration: 0.5)
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(CapsLockConfiguration.self, from: data)
    XCTAssertEqual(decoded.minPressDuration, 0.5)
}

func testConfigurationValidation() {
    var config = CapsLockConfiguration()
    config.minPressDuration = -1.0
    XCTAssertThrowsError(try config.validate())
}
```

### Testing State Machines

```swift
func testStateMachineHappyPath() {
    let machine = StateMachine()
    XCTAssertEqual(machine.state, .initial)

    machine.transition(to: .active)
    XCTAssertEqual(machine.state, .active)

    machine.transition(to: .complete)
    XCTAssertEqual(machine.state, .complete)
}

func testStateMachineInvalidTransition() {
    let machine = StateMachine()
    XCTAssertThrowsError(try machine.transition(to: .complete))
}
```

### Testing Thread Safety

```swift
func testConcurrentAccess() {
    let registry = DeviceRegistry()
    let expectation = expectation(description: "Concurrent operations")
    expectation.expectedFulfillmentCount = 100

    DispatchQueue.concurrentPerform(iterations: 100) { i in
        registry.register(device: testDevice(id: i))
        expectation.fulfill()
    }

    waitForExpectations(timeout: 5.0)
    XCTAssertEqual(registry.deviceCount, 100)
}
```

## Resources

- [Architecture Overview](./architecture.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [Apple Testing Guide](https://developer.apple.com/documentation/xctest)

## Questions?

For testing questions, see [CONTRIBUTING.md](../CONTRIBUTING.md) or open an issue.

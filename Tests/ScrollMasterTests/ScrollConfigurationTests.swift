import XCTest
@testable import ScrollMaster

final class DeviceScrollConfigurationTests: XCTestCase {
    func testInitialization() {
        let config = DeviceScrollConfiguration(deviceStableID: "device-1")

        XCTAssertEqual(config.deviceStableID, "device-1")
        XCTAssertEqual(config.transform, .identity)
        XCTAssertTrue(config.enabled)
    }

    func testCustomInitialization() {
        let transform = ScrollTransform(invertVertical: true)
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform,
            enabled: false
        )

        XCTAssertEqual(config.deviceStableID, "device-1")
        XCTAssertEqual(config.transform, transform)
        XCTAssertFalse(config.enabled)
    }

    func testEquality() {
        let config1 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )
        let config2 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )

        XCTAssertEqual(config1, config2)
    }

    func testInequality() {
        let config1 = DeviceScrollConfiguration(deviceStableID: "device-1")
        let config2 = DeviceScrollConfiguration(deviceStableID: "device-2")

        XCTAssertNotEqual(config1, config2)
    }

    func testCodable() throws {
        let original = DeviceScrollConfiguration(
            deviceStableID: "device-123",
            transform: ScrollTransform(
                invertVertical: true,
                verticalMultiplier: 1.5
            ),
            enabled: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeviceScrollConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

final class ScrollConfigurationRegistryTests: XCTestCase {
    var registry: ScrollConfigurationRegistry!

    override func setUp() {
        registry = ScrollConfigurationRegistry()
    }

    override func tearDown() {
        registry = nil
    }

    // MARK: - Basic Operations

    func testInitialState() {
        XCTAssertEqual(registry.count, 0)
        XCTAssertEqual(registry.defaultConfiguration, .identity)
    }

    func testSetConfiguration() {
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )

        registry.setConfiguration(config)

        XCTAssertEqual(registry.count, 1)
        let retrieved = registry.configuration(for: "device-1")
        XCTAssertEqual(retrieved, config)
    }

    func testGetNonExistentConfiguration() {
        let config = registry.configuration(for: "nonexistent")
        XCTAssertNil(config)
    }

    func testRemoveConfiguration() {
        let config = DeviceScrollConfiguration(deviceStableID: "device-1")
        registry.setConfiguration(config)

        XCTAssertEqual(registry.count, 1)

        registry.removeConfiguration(for: "device-1")

        XCTAssertEqual(registry.count, 0)
        XCTAssertNil(registry.configuration(for: "device-1"))
    }

    func testRemoveNonExistentConfiguration() {
        registry.removeConfiguration(for: "nonexistent")
        // Should not crash
        XCTAssertEqual(registry.count, 0)
    }

    func testClearAll() {
        let configs = [
            DeviceScrollConfiguration(deviceStableID: "device-1"),
            DeviceScrollConfiguration(deviceStableID: "device-2"),
            DeviceScrollConfiguration(deviceStableID: "device-3")
        ]

        for config in configs {
            registry.setConfiguration(config)
        }

        XCTAssertEqual(registry.count, 3)

        registry.clearAll()

        XCTAssertEqual(registry.count, 0)
    }

    // MARK: - Transform Retrieval

    func testTransformForConfiguredDevice() {
        let transform = ScrollTransform(invertVertical: true, verticalMultiplier: 2.0)
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform
        )

        registry.setConfiguration(config)

        let retrieved = registry.transform(for: "device-1")
        XCTAssertEqual(retrieved, transform)
    }

    func testTransformForUnconfiguredDevice() {
        let transform = registry.transform(for: "nonexistent")
        XCTAssertEqual(transform, registry.defaultConfiguration)
    }

    func testTransformForDisabledDevice() {
        let transform = ScrollTransform(invertVertical: true)
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform,
            enabled: false
        )

        registry.setConfiguration(config)

        // Disabled config should return default
        let retrieved = registry.transform(for: "device-1")
        XCTAssertEqual(retrieved, registry.defaultConfiguration)
        XCTAssertNotEqual(retrieved, transform)
    }

    func testCustomDefaultConfiguration() {
        let customDefault = ScrollTransform(invertHorizontal: true)
        registry.defaultConfiguration = customDefault

        let transform = registry.transform(for: "nonexistent")
        XCTAssertEqual(transform, customDefault)
    }

    // MARK: - Multiple Configurations

    func testMultipleConfigurations() {
        let config1 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )
        let config2 = DeviceScrollConfiguration(
            deviceStableID: "device-2",
            transform: ScrollTransform(invertHorizontal: true)
        )
        let config3 = DeviceScrollConfiguration(
            deviceStableID: "device-3",
            transform: ScrollTransform(verticalMultiplier: 2.0)
        )

        registry.setConfiguration(config1)
        registry.setConfiguration(config2)
        registry.setConfiguration(config3)

        XCTAssertEqual(registry.count, 3)

        XCTAssertEqual(registry.configuration(for: "device-1"), config1)
        XCTAssertEqual(registry.configuration(for: "device-2"), config2)
        XCTAssertEqual(registry.configuration(for: "device-3"), config3)
    }

    func testUpdateExistingConfiguration() {
        let config1 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )

        registry.setConfiguration(config1)
        XCTAssertEqual(registry.count, 1)

        // Update with new configuration for same device
        let config2 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertHorizontal: true)
        )

        registry.setConfiguration(config2)

        // Should still have only 1 configuration
        XCTAssertEqual(registry.count, 1)

        // Should have the updated configuration
        let retrieved = registry.configuration(for: "device-1")
        XCTAssertEqual(retrieved, config2)
        XCTAssertNotEqual(retrieved, config1)
    }

    func testAllConfigurations() {
        let configs = [
            DeviceScrollConfiguration(deviceStableID: "device-1"),
            DeviceScrollConfiguration(deviceStableID: "device-2"),
            DeviceScrollConfiguration(deviceStableID: "device-3")
        ]

        for config in configs {
            registry.setConfiguration(config)
        }

        let all = registry.allConfigurations()
        XCTAssertEqual(all.count, 3)

        // Check that all configs are present
        for config in configs {
            XCTAssertTrue(all.contains(config))
        }
    }

    func testAllConfigurationsEmpty() {
        let all = registry.allConfigurations()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Thread Safety

    func testConcurrentWrites() {
        let expectation = self.expectation(description: "Concurrent writes")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<10 {
            DispatchQueue.global().async {
                let config = DeviceScrollConfiguration(
                    deviceStableID: "device-\(i)",
                    transform: ScrollTransform(verticalMultiplier: Double(i))
                )
                self.registry.setConfiguration(config)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(registry.count, 10)
    }

    func testConcurrentReadWrite() {
        let config = DeviceScrollConfiguration(deviceStableID: "device-1")
        registry.setConfiguration(config)

        let expectation = self.expectation(description: "Concurrent read/write")
        expectation.expectedFulfillmentCount = 20

        for i in 0..<10 {
            // Write
            DispatchQueue.global().async {
                let newConfig = DeviceScrollConfiguration(
                    deviceStableID: "device-\(i + 10)",
                    transform: ScrollTransform(verticalMultiplier: Double(i))
                )
                self.registry.setConfiguration(newConfig)
                expectation.fulfill()
            }

            // Read
            DispatchQueue.global().async {
                _ = self.registry.transform(for: "device-1")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should have original + 10 new configs
        XCTAssertEqual(registry.count, 11)
    }

    // MARK: - Edge Cases

    func testEmptyDeviceID() {
        let config = DeviceScrollConfiguration(deviceStableID: "")
        registry.setConfiguration(config)

        let retrieved = registry.configuration(for: "")
        XCTAssertEqual(retrieved, config)
    }

    func testVeryLongDeviceID() {
        let longID = String(repeating: "A", count: 1000)
        let config = DeviceScrollConfiguration(deviceStableID: longID)

        registry.setConfiguration(config)

        let retrieved = registry.configuration(for: longID)
        XCTAssertEqual(retrieved, config)
    }

    func testSpecialCharactersInDeviceID() {
        let specialID = "device-!@#$%^&*()_+-=[]{}|;:',.<>?/~`"
        let config = DeviceScrollConfiguration(deviceStableID: specialID)

        registry.setConfiguration(config)

        let retrieved = registry.configuration(for: specialID)
        XCTAssertEqual(retrieved, config)
    }

    func testLargeNumberOfConfigurations() {
        for i in 0..<1000 {
            let config = DeviceScrollConfiguration(deviceStableID: "device-\(i)")
            registry.setConfiguration(config)
        }

        XCTAssertEqual(registry.count, 1000)
    }

    // MARK: - Enabled/Disabled Behavior

    func testEnabledConfigurationReturnsTransform() {
        let transform = ScrollTransform(invertVertical: true)
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform,
            enabled: true
        )

        registry.setConfiguration(config)

        let retrieved = registry.transform(for: "device-1")
        XCTAssertEqual(retrieved, transform)
    }

    func testDisabledConfigurationReturnsDefault() {
        let transform = ScrollTransform(invertVertical: true)
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform,
            enabled: false
        )

        registry.setConfiguration(config)

        let retrieved = registry.transform(for: "device-1")
        XCTAssertEqual(retrieved, registry.defaultConfiguration)
    }

    func testToggleEnabled() {
        let transform = ScrollTransform(invertVertical: true)
        var config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform,
            enabled: true
        )

        registry.setConfiguration(config)
        XCTAssertEqual(registry.transform(for: "device-1"), transform)

        // Disable
        config.enabled = false
        registry.setConfiguration(config)
        XCTAssertEqual(registry.transform(for: "device-1"), .identity)

        // Re-enable
        config.enabled = true
        registry.setConfiguration(config)
        XCTAssertEqual(registry.transform(for: "device-1"), transform)
    }
}

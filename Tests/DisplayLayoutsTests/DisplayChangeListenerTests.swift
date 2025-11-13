import XCTest
@testable import DisplayLayouts

final class DisplayConfigurationRegistryTests: XCTestCase {
    var registry: DisplayConfigurationRegistry!

    override func setUp() {
        super.setUp()
        registry = DisplayConfigurationRegistry()
    }

    override func tearDown() {
        registry = nil
        super.tearDown()
    }

    // MARK: - Basic Operations

    func testInitialState() {
        XCTAssertEqual(registry.count, 0)
        XCTAssertTrue(registry.allConfigurations().isEmpty)
    }

    func testStoreAndRetrieve() {
        let display = makeDisplay(vendorID: 0x1234, modelID: 0x5678)
        let config = DisplayConfiguration(displays: [display])

        registry.store(config)

        let retrieved = registry.retrieve(config.signature)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.signature, config.signature)
    }

    func testStoreWithCustomIdentifier() {
        let display = makeDisplay(vendorID: 0x1234, modelID: 0x5678)
        let config = DisplayConfiguration(displays: [display])

        registry.store(config, identifier: "custom-id")

        let retrieved = registry.retrieve("custom-id")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.signature, config.signature)
    }

    func testRetrieveNonExistent() {
        let retrieved = registry.retrieve("nonexistent")
        XCTAssertNil(retrieved)
    }

    func testRemove() {
        let display = makeDisplay(vendorID: 0x1234, modelID: 0x5678)
        let config = DisplayConfiguration(displays: [display])

        registry.store(config)
        XCTAssertEqual(registry.count, 1)

        registry.remove(config.signature)
        XCTAssertEqual(registry.count, 0)
        XCTAssertNil(registry.retrieve(config.signature))
    }

    func testClearAll() {
        let display1 = makeDisplay(vendorID: 0x1234, modelID: 0x5678)
        let display2 = makeDisplay(vendorID: 0xABCD, modelID: 0xEF01)

        registry.store(DisplayConfiguration(displays: [display1]))
        registry.store(DisplayConfiguration(displays: [display2]))
        XCTAssertEqual(registry.count, 2)

        registry.clearAll()
        XCTAssertEqual(registry.count, 0)
    }

    // MARK: - Matching Tests

    func testFindMatchingExactMatch() {
        let display = makeDisplay(vendorID: 0x1234, modelID: 0x5678)
        let config = DisplayConfiguration(displays: [display])

        registry.store(config, identifier: "test-config")

        let found = registry.findMatching(config)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.identifier, "test-config")
    }

    func testFindMatchingFuzzyMatch() {
        let display1 = makeDisplay(
            vendorID: 0x1234,
            modelID: 0x5678,
            width: 1920.0,
            height: 1080.0
        )
        let config1 = DisplayConfiguration(displays: [display1])

        registry.store(config1, identifier: "stored")

        // Create slightly different configuration (within tolerance)
        let display2 = makeDisplay(
            vendorID: 0x1234,
            modelID: 0x5678,
            width: 1920.5,
            height: 1080.5
        )
        let config2 = DisplayConfiguration(displays: [display2])

        let found = registry.findMatching(config2)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.identifier, "stored")
    }

    func testFindMatchingNoMatch() {
        let display1 = makeDisplay(vendorID: 0x1234, modelID: 0x5678)
        let config1 = DisplayConfiguration(displays: [display1])

        registry.store(config1)

        let display2 = makeDisplay(vendorID: 0xABCD, modelID: 0xEF01)
        let config2 = DisplayConfiguration(displays: [display2])

        let found = registry.findMatching(config2)
        XCTAssertNil(found)
    }

    // MARK: - Multiple Configurations

    func testMultipleConfigurations() {
        let display1 = makeDisplay(vendorID: 0x1111, modelID: 0x1111)
        let display2 = makeDisplay(vendorID: 0x2222, modelID: 0x2222)
        let display3 = makeDisplay(vendorID: 0x3333, modelID: 0x3333)

        registry.store(DisplayConfiguration(displays: [display1]), identifier: "config1")
        registry.store(DisplayConfiguration(displays: [display2]), identifier: "config2")
        registry.store(DisplayConfiguration(displays: [display3]), identifier: "config3")

        XCTAssertEqual(registry.count, 3)

        let all = registry.allConfigurations()
        XCTAssertEqual(all.count, 3)
        XCTAssertNotNil(all["config1"])
        XCTAssertNotNil(all["config2"])
        XCTAssertNotNil(all["config3"])
    }

    // MARK: - Thread Safety

    func testConcurrentWrites() {
        let expectation = self.expectation(description: "Concurrent writes")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<10 {
            DispatchQueue.global().async {
                let display = self.makeDisplay(
                    vendorID: UInt32(0x1000 + i),
                    modelID: UInt32(0x2000 + i)
                )
                let config = DisplayConfiguration(displays: [display])
                self.registry.store(config, identifier: "config-\(i)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(registry.count, 10)
    }

    func testConcurrentReadWrite() {
        let display = makeDisplay(vendorID: 0x1234, modelID: 0x5678)
        let config = DisplayConfiguration(displays: [display])
        registry.store(config, identifier: "test")

        let expectation = self.expectation(description: "Concurrent read/write")
        expectation.expectedFulfillmentCount = 20

        for i in 0..<10 {
            // Write
            DispatchQueue.global().async {
                let d = self.makeDisplay(
                    vendorID: UInt32(0x1000 + i),
                    modelID: UInt32(0x2000 + i)
                )
                let c = DisplayConfiguration(displays: [d])
                self.registry.store(c)
                expectation.fulfill()
            }

            // Read
            DispatchQueue.global().async {
                _ = self.registry.retrieve("test")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Helpers

    private func makeDisplay(
        vendorID: UInt32,
        modelID: UInt32,
        width: Double = 1920.0,
        height: Double = 1080.0
    ) -> DisplayIdentity {
        return DisplayIdentity(
            displayID: 1,
            serialNumber: "TEST\(vendorID)-\(modelID)",
            vendorID: vendorID,
            modelID: modelID,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: width, height: height),
            scale: 1.0,
            isMain: false
        )
    }
}

// MARK: - DisplayConfigurationChangeEvent Tests

final class DisplayConfigurationChangeEventTests: XCTestCase {
    func testInitialChangeType() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])

        let event = DisplayConfigurationChangeEvent(
            previousConfiguration: nil,
            newConfiguration: config
        )

        XCTAssertEqual(event.changeType, .initial)
        XCTAssertNil(event.previousConfiguration)
        XCTAssertEqual(event.newConfiguration.signature, config.signature)
    }

    func testDisplayAddedChangeType() {
        let display1 = makeDisplay(vendorID: 0x1234)
        let config1 = DisplayConfiguration(displays: [display1])

        let display2 = makeDisplay(vendorID: 0xABCD)
        let config2 = DisplayConfiguration(displays: [display1, display2])

        let event = DisplayConfigurationChangeEvent(
            previousConfiguration: config1,
            newConfiguration: config2
        )

        XCTAssertEqual(event.changeType, .displayAdded)
    }

    func testDisplayRemovedChangeType() {
        let display1 = makeDisplay(vendorID: 0x1234)
        let display2 = makeDisplay(vendorID: 0xABCD)
        let config1 = DisplayConfiguration(displays: [display1, display2])

        let config2 = DisplayConfiguration(displays: [display1])

        let event = DisplayConfigurationChangeEvent(
            previousConfiguration: config1,
            newConfiguration: config2
        )

        XCTAssertEqual(event.changeType, .displayRemoved)
    }

    func testDisplayChangedChangeType() {
        let display1 = makeDisplay(vendorID: 0x1234, width: 1920, height: 1080)
        let config1 = DisplayConfiguration(displays: [display1])

        let display2 = makeDisplay(vendorID: 0x1234, width: 2560, height: 1440)
        let config2 = DisplayConfiguration(displays: [display2])

        let event = DisplayConfigurationChangeEvent(
            previousConfiguration: config1,
            newConfiguration: config2
        )

        XCTAssertEqual(event.changeType, .displayChanged)
    }

    func testDebugDescription() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])

        let event = DisplayConfigurationChangeEvent(
            previousConfiguration: nil,
            newConfiguration: config
        )

        let description = event.debugDescription
        XCTAssertTrue(description.contains("DisplayConfigurationChangeEvent"))
        XCTAssertTrue(description.contains("initial"))
    }

    // MARK: - Helpers

    private func makeDisplay(
        vendorID: UInt32 = 0x1234,
        width: Double = 1920.0,
        height: Double = 1080.0
    ) -> DisplayIdentity {
        return DisplayIdentity(
            displayID: 1,
            serialNumber: "TEST",
            vendorID: vendorID,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: width, height: height),
            scale: 1.0,
            isMain: false
        )
    }
}

// MARK: - DisplayChangeListener Tests

final class DisplayChangeListenerTests: XCTestCase {
    var listener: DisplayChangeListener!
    var handler: MockDisplayChangeHandler!
    var mockEnumerator: MockDisplayEnumerator!

    override func setUp() {
        super.setUp()
        handler = MockDisplayChangeHandler()
        mockEnumerator = MockDisplayEnumerator()
        listener = DisplayChangeListener(
            handler: handler,
            debounceInterval: 0.1, // Short interval for testing
            enumerator: mockEnumerator
        )
    }

    override func tearDown() {
        listener.stopListening()
        listener = nil
        handler = nil
        mockEnumerator = nil
        super.tearDown()
    }

    // MARK: - Lifecycle Tests

    func testStartListening() {
        XCTAssertFalse(listener.isActive)

        listener.startListening()

        XCTAssertTrue(listener.isActive)
    }

    func testStopListening() {
        listener.startListening()
        XCTAssertTrue(listener.isActive)

        listener.stopListening()

        XCTAssertFalse(listener.isActive)
    }

    func testDoubleStart() {
        listener.startListening()
        XCTAssertTrue(listener.isActive)

        // Should not crash or cause issues
        listener.startListening()
        XCTAssertTrue(listener.isActive)
    }

    func testDoubleStop() {
        listener.startListening()
        listener.stopListening()
        XCTAssertFalse(listener.isActive)

        // Should not crash
        listener.stopListening()
        XCTAssertFalse(listener.isActive)
    }

    // MARK: - Configuration Tests

    func testGetCurrentConfiguration() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockEnumerator.configurationToReturn = config

        let current = listener.getCurrentConfiguration()
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.signature, config.signature)
    }

    func testManualCheck() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockEnumerator.configurationToReturn = config

        let expectation = self.expectation(description: "Configuration change")
        handler.onConfigurationChanged = { newConfig in
            XCTAssertEqual(newConfig.signature, config.signature)
            expectation.fulfill()
        }

        listener.startListening()
        listener.checkConfiguration()

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Debouncing Tests

    func testDebouncing() {
        let display1 = makeDisplay(vendorID: 0x1234)
        let config1 = DisplayConfiguration(displays: [display1])

        let display2 = makeDisplay(vendorID: 0xABCD)
        let config2 = DisplayConfiguration(displays: [display2])

        mockEnumerator.configurationToReturn = config1

        let expectation = self.expectation(description: "Debounced notification")
        var notificationCount = 0

        handler.onConfigurationChanged = { _ in
            notificationCount += 1
            if notificationCount == 1 {
                expectation.fulfill()
            }
        }

        listener.startListening()

        // Trigger multiple rapid changes
        listener.checkConfiguration()
        mockEnumerator.configurationToReturn = config2
        listener.checkConfiguration()
        listener.checkConfiguration()

        // Should only get one notification after debounce
        wait(for: [expectation], timeout: 1.0)

        // Give extra time to ensure no additional notifications
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertEqual(notificationCount, 1)
    }

    func testPendingNotification() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockEnumerator.configurationToReturn = config

        listener.startListening()

        XCTAssertFalse(listener.hasPendingNotification)

        listener.checkConfiguration()

        // Should have pending notification immediately after check
        XCTAssertTrue(listener.hasPendingNotification)

        // Wait for debounce
        Thread.sleep(forTimeInterval: 0.3)

        // Should be cleared after processing
        XCTAssertFalse(listener.hasPendingNotification)
    }

    func testSetDebounceInterval() {
        listener.setDebounceInterval(1.0)

        // Should not crash
        listener.startListening()
        listener.stopListening()
    }

    // MARK: - Change Detection Tests

    func testNoNotificationForSameConfiguration() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockEnumerator.configurationToReturn = config

        var notificationCount = 0
        handler.onConfigurationChanged = { _ in
            notificationCount += 1
        }

        listener.startListening()
        listener.checkConfiguration()

        // Wait for debounce
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertEqual(notificationCount, 1)

        // Check again with same config
        listener.checkConfiguration()

        // Wait for debounce
        Thread.sleep(forTimeInterval: 0.3)

        // Should not get another notification (same config)
        XCTAssertEqual(notificationCount, 1)
    }

    func testNotificationForDifferentConfiguration() {
        let display1 = makeDisplay(vendorID: 0x1234)
        let config1 = DisplayConfiguration(displays: [display1])

        let display2 = makeDisplay(vendorID: 0xABCD)
        let config2 = DisplayConfiguration(displays: [display2])

        mockEnumerator.configurationToReturn = config1

        let expectation = self.expectation(description: "Two configurations")
        expectation.expectedFulfillmentCount = 2

        handler.onConfigurationChanged = { _ in
            expectation.fulfill()
        }

        listener.startListening()
        listener.checkConfiguration()

        // Wait for first debounce
        Thread.sleep(forTimeInterval: 0.3)

        // Change config
        mockEnumerator.configurationToReturn = config2
        listener.checkConfiguration()

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Error Handling

    func testEnumerationFailure() {
        mockEnumerator.shouldThrowError = true

        var notificationCount = 0
        handler.onConfigurationChanged = { _ in
            notificationCount += 1
        }

        listener.startListening()
        listener.checkConfiguration()

        // Wait for debounce
        Thread.sleep(forTimeInterval: 0.3)

        // Should not get notification on error
        XCTAssertEqual(notificationCount, 0)
    }

    // MARK: - Helpers

    private func makeDisplay(vendorID: UInt32 = 0x1234) -> DisplayIdentity {
        return DisplayIdentity(
            displayID: 1,
            serialNumber: "TEST",
            vendorID: vendorID,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: false
        )
    }
}

// MARK: - Mocks

class MockDisplayChangeHandler: DisplayChangeHandler {
    var onConfigurationChanged: ((DisplayConfiguration) -> Void)?

    func displayConfigurationDidChange(_ configuration: DisplayConfiguration) {
        onConfigurationChanged?(configuration)
    }
}

class MockDisplayEnumerator: DisplayEnumerator {
    var configurationToReturn: DisplayConfiguration?
    var shouldThrowError: Bool = false

    override func getCurrentConfiguration() throws -> DisplayConfiguration {
        if shouldThrowError {
            throw DisplayError.noDisplaysFound
        }

        guard let config = configurationToReturn else {
            // Return default single display
            let display = DisplayIdentity(
                displayID: 1,
                serialNumber: nil,
                vendorID: 0x1234,
                modelID: 0x5678,
                name: "Mock Display",
                bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
                scale: 1.0,
                isMain: true
            )
            return DisplayConfiguration(displays: [display])
        }

        return config
    }
}

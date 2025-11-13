import XCTest
@testable import ScrollMaster

final class DeviceRegistryTests: XCTestCase {
    var registry: DeviceRegistry!

    override func setUp() {
        registry = DeviceRegistry()
    }

    override func tearDown() {
        registry = nil
    }

    // MARK: - Registration Tests

    func testRegisterSingleDevice() {
        let device = DeviceIdentity(vendorID: 100, productID: 200)

        registry.register(device)

        XCTAssertEqual(registry.count, 1)
        XCTAssertTrue(registry.isRegistered(stableID: device.stableID))
    }

    func testRegisterMultipleDevices() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 101, productID: 201)
        let device3 = DeviceIdentity(vendorID: 102, productID: 202)

        registry.register(device1)
        registry.register(device2)
        registry.register(device3)

        XCTAssertEqual(registry.count, 3)
        XCTAssertTrue(registry.isRegistered(stableID: device1.stableID))
        XCTAssertTrue(registry.isRegistered(stableID: device2.stableID))
        XCTAssertTrue(registry.isRegistered(stableID: device3.stableID))
    }

    func testRegisterAllDevices() {
        let devices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 101, productID: 201),
            DeviceIdentity(vendorID: 102, productID: 202)
        ]

        registry.registerAll(devices)

        XCTAssertEqual(registry.count, 3)
    }

    func testRegisterDuplicateDevice() {
        let device = DeviceIdentity(vendorID: 100, productID: 200)

        registry.register(device)
        registry.register(device) // Register again

        // Should only have one entry
        XCTAssertEqual(registry.count, 1)
    }

    // MARK: - Retrieval Tests

    func testRetrieveRegisteredDevice() {
        let device = DeviceIdentity(
            vendorID: 100,
            productID: 200,
            productName: "Test Mouse"
        )

        registry.register(device)

        let retrieved = registry.device(withStableID: device.stableID)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.vendorID, 100)
        XCTAssertEqual(retrieved?.productID, 200)
        XCTAssertEqual(retrieved?.productName, "Test Mouse")
    }

    func testRetrieveNonExistentDevice() {
        let retrieved = registry.device(withStableID: "nonexistent")
        XCTAssertNil(retrieved)
    }

    func testGetAllDevices() {
        let devices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 101, productID: 201),
            DeviceIdentity(vendorID: 102, productID: 202)
        ]

        registry.registerAll(devices)

        let allDevices = registry.allDevices()
        XCTAssertEqual(allDevices.count, 3)
    }

    func testGetAllDevicesEmpty() {
        let allDevices = registry.allDevices()
        XCTAssertTrue(allDevices.isEmpty)
    }

    // MARK: - Unregistration Tests

    func testUnregisterDevice() {
        let device = DeviceIdentity(vendorID: 100, productID: 200)

        registry.register(device)
        XCTAssertEqual(registry.count, 1)

        registry.unregister(stableID: device.stableID)
        XCTAssertEqual(registry.count, 0)
        XCTAssertFalse(registry.isRegistered(stableID: device.stableID))
    }

    func testUnregisterNonExistentDevice() {
        registry.unregister(stableID: "nonexistent")
        // Should not crash or error
        XCTAssertEqual(registry.count, 0)
    }

    func testUnregisterOneOfMany() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 101, productID: 201)
        let device3 = DeviceIdentity(vendorID: 102, productID: 202)

        registry.registerAll([device1, device2, device3])
        XCTAssertEqual(registry.count, 3)

        registry.unregister(stableID: device2.stableID)

        XCTAssertEqual(registry.count, 2)
        XCTAssertTrue(registry.isRegistered(stableID: device1.stableID))
        XCTAssertFalse(registry.isRegistered(stableID: device2.stableID))
        XCTAssertTrue(registry.isRegistered(stableID: device3.stableID))
    }

    // MARK: - Clear Tests

    func testClearRegistry() {
        let devices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 101, productID: 201)
        ]

        registry.registerAll(devices)
        XCTAssertEqual(registry.count, 2)

        registry.clear()
        XCTAssertEqual(registry.count, 0)
    }

    func testClearEmptyRegistry() {
        registry.clear()
        // Should not crash
        XCTAssertEqual(registry.count, 0)
    }

    // MARK: - Search Tests

    func testFindDeviceByVendorAndProductID() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 101, productID: 201)

        registry.registerAll([device1, device2])

        let found = registry.findDevice(vendorID: 101, productID: 201)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.vendorID, 101)
        XCTAssertEqual(found?.productID, 201)
    }

    func testFindDeviceNotFound() {
        let device = DeviceIdentity(vendorID: 100, productID: 200)
        registry.register(device)

        let found = registry.findDevice(vendorID: 999, productID: 999)
        XCTAssertNil(found)
    }

    func testFindDevicesMatchingPredicate() {
        let devices = [
            DeviceIdentity(vendorID: 1452, productID: 613, productName: "Magic Mouse"),
            DeviceIdentity(vendorID: 1452, productID: 614, productName: "Magic Trackpad"),
            DeviceIdentity(vendorID: 1133, productID: 100, productName: "Gaming Mouse")
        ]

        registry.registerAll(devices)

        // Find all Apple devices (vendor ID 1452)
        let appleDevices = registry.findDevices { $0.vendorID == 1452 }
        XCTAssertEqual(appleDevices.count, 2)
    }

    func testFindDevicesWithNameContaining() {
        let devices = [
            DeviceIdentity(vendorID: 100, productID: 200, productName: "Magic Mouse"),
            DeviceIdentity(vendorID: 101, productID: 201, productName: "Gaming Mouse"),
            DeviceIdentity(vendorID: 102, productID: 202, productName: "Trackpad")
        ]

        registry.registerAll(devices)

        let mouseDevices = registry.findDevices { device in
            device.productName?.contains("Mouse") ?? false
        }

        XCTAssertEqual(mouseDevices.count, 2)
    }

    // MARK: - Update Tests

    func testUpdateWithNewDevices() {
        let currentDevices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 101, productID: 201)
        ]

        let (added, removed) = registry.updateWith(currentDevices: currentDevices)

        XCTAssertEqual(added.count, 2)
        XCTAssertEqual(removed.count, 0)
        XCTAssertEqual(registry.count, 2)
    }

    func testUpdateWithRemovedDevices() {
        let initialDevices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 101, productID: 201),
            DeviceIdentity(vendorID: 102, productID: 202)
        ]

        registry.registerAll(initialDevices)

        // Update with fewer devices
        let currentDevices = [
            DeviceIdentity(vendorID: 100, productID: 200)
        ]

        let (added, removed) = registry.updateWith(currentDevices: currentDevices)

        XCTAssertEqual(added.count, 0)
        XCTAssertEqual(removed.count, 2)
        XCTAssertEqual(registry.count, 1)
    }

    func testUpdateWithMixedChanges() {
        let initialDevices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 101, productID: 201)
        ]

        registry.registerAll(initialDevices)

        // Remove device 101, add device 102
        let currentDevices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 102, productID: 202)
        ]

        let (added, removed) = registry.updateWith(currentDevices: currentDevices)

        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(registry.count, 2)

        XCTAssertTrue(registry.isRegistered(stableID: "100-200"))
        XCTAssertFalse(registry.isRegistered(stableID: "101-201"))
        XCTAssertTrue(registry.isRegistered(stableID: "102-202"))
    }

    func testUpdateWithNoChanges() {
        let devices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 101, productID: 201)
        ]

        registry.registerAll(devices)

        // Update with same devices
        let (added, removed) = registry.updateWith(currentDevices: devices)

        XCTAssertEqual(added.count, 0)
        XCTAssertEqual(removed.count, 0)
        XCTAssertEqual(registry.count, 2)
    }

    func testUpdateWithEmptyList() {
        let devices = [
            DeviceIdentity(vendorID: 100, productID: 200),
            DeviceIdentity(vendorID: 101, productID: 201)
        ]

        registry.registerAll(devices)

        // Update with empty list
        let (added, removed) = registry.updateWith(currentDevices: [])

        XCTAssertEqual(added.count, 0)
        XCTAssertEqual(removed.count, 2)
        XCTAssertEqual(registry.count, 0)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentRegistration() {
        let expectation = self.expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<10 {
            DispatchQueue.global().async {
                let device = DeviceIdentity(vendorID: i, productID: i * 10)
                self.registry.register(device)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(registry.count, 10)
    }

    func testConcurrentReadWrite() {
        let device = DeviceIdentity(vendorID: 100, productID: 200)
        registry.register(device)

        let expectation = self.expectation(description: "Concurrent reads and writes")
        expectation.expectedFulfillmentCount = 20

        for i in 0..<10 {
            // Write
            DispatchQueue.global().async {
                let newDevice = DeviceIdentity(vendorID: i + 1000, productID: i + 2000)
                self.registry.register(newDevice)
                expectation.fulfill()
            }

            // Read
            DispatchQueue.global().async {
                _ = self.registry.allDevices()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should have original device + 10 new devices
        XCTAssertEqual(registry.count, 11)
    }

    // MARK: - Edge Cases

    func testRegisterDeviceWithSameVendorProductButDifferentSerial() {
        let device1 = DeviceIdentity(
            vendorID: 100,
            productID: 200,
            serialNumber: "SN1"
        )
        let device2 = DeviceIdentity(
            vendorID: 100,
            productID: 200,
            serialNumber: "SN2"
        )

        registry.register(device1)
        registry.register(device2)

        // Different serial numbers mean different stable IDs
        XCTAssertEqual(registry.count, 2)
    }

    func testLargeNumberOfDevices() {
        let devices = (0..<1000).map { i in
            DeviceIdentity(vendorID: i, productID: i * 10)
        }

        registry.registerAll(devices)

        XCTAssertEqual(registry.count, 1000)
    }

    func testIsRegisteredConsistency() {
        let device = DeviceIdentity(vendorID: 100, productID: 200)

        XCTAssertFalse(registry.isRegistered(stableID: device.stableID))

        registry.register(device)
        XCTAssertTrue(registry.isRegistered(stableID: device.stableID))

        registry.unregister(stableID: device.stableID)
        XCTAssertFalse(registry.isRegistered(stableID: device.stableID))
    }
}

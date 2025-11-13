import XCTest
@testable import ScrollMaster
@testable import MacToolsCore

@MainActor
final class ScrollMasterViewModelTests: XCTestCase {
    var viewModel: ScrollMasterViewModel!
    var mockEnumerator: MockDeviceEnumerator!
    var testConfigPath: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary config directory
        let tempDir = NSTemporaryDirectory()
        testConfigPath = (tempDir as NSString).appendingPathComponent("test-config-\(UUID().uuidString).json")

        // Set up test configuration
        Configuration.shared.configPath = testConfigPath

        mockEnumerator = MockDeviceEnumerator()
        viewModel = ScrollMasterViewModel(
            enumerator: mockEnumerator,
            configManager: ScrollConfigurationManager(),
            registry: ScrollConfigurationRegistry()
        )
    }

    override func tearDown() async throws {
        // Clean up test config file
        if FileManager.default.fileExists(atPath: testConfigPath) {
            try? FileManager.default.removeItem(atPath: testConfigPath)
        }

        viewModel = nil
        mockEnumerator = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.defaultTransform, .identity)
        XCTAssertEqual(viewModel.smoothScrollParameters, .default)
    }

    // MARK: - Device Loading Tests

    func testLoadConfigurationWithNoDevices() {
        mockEnumerator.devicesToReturn = []

        viewModel.loadConfiguration()

        XCTAssertTrue(viewModel.devices.isEmpty)
        XCTAssertNil(viewModel.error)
    }

    func testLoadConfigurationWithDevices() {
        let device1 = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        let device2 = DeviceIdentity(
            vendorID: 0xABCD,
            productID: 0xEF01,
            serialNumber: "XYZ789",
            locationID: 456,
            productName: "Test Trackpad",
            transport: "Bluetooth"
        )

        mockEnumerator.devicesToReturn = [device1, device2]

        viewModel.loadConfiguration()

        XCTAssertEqual(viewModel.devices.count, 2)
        XCTAssertEqual(viewModel.devices[0].name, "Test Mouse")
        XCTAssertEqual(viewModel.devices[1].name, "Test Trackpad")
    }

    func testLoadConfigurationWithUnnamedDevice() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: nil,
            locationID: nil,
            productName: nil,
            transport: "USB"
        )

        mockEnumerator.devicesToReturn = [device]

        viewModel.loadConfiguration()

        XCTAssertEqual(viewModel.devices.count, 1)
        XCTAssertEqual(viewModel.devices[0].name, "Unknown Device")
    }

    func testLoadConfigurationWithExistingConfigs() throws {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )

        // Save a config for this device
        let savedConfig = DeviceScrollConfiguration(
            deviceStableID: device.stableID,
            transform: ScrollTransform(invertVertical: true, verticalMultiplier: 2.0),
            enabled: false
        )
        let configManager = ScrollConfigurationManager()
        try configManager.save(savedConfig)

        mockEnumerator.devicesToReturn = [device]

        viewModel.loadConfiguration()

        XCTAssertEqual(viewModel.devices.count, 1)
        XCTAssertEqual(viewModel.devices[0].configuration, savedConfig)
        XCTAssertTrue(viewModel.devices[0].configuration.transform.invertVertical)
        XCTAssertEqual(viewModel.devices[0].configuration.transform.verticalMultiplier, 2.0)
        XCTAssertFalse(viewModel.devices[0].configuration.enabled)
    }

    func testRefreshDevices() {
        mockEnumerator.devicesToReturn = []
        viewModel.loadConfiguration()
        XCTAssertEqual(viewModel.devices.count, 0)

        // Add devices
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]

        viewModel.refreshDevices()

        XCTAssertEqual(viewModel.devices.count, 1)
    }

    // MARK: - Device Update Tests

    func testUpdateDevice() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        let newConfig = DeviceScrollConfiguration(
            deviceStableID: device.stableID,
            transform: ScrollTransform(invertVertical: true),
            enabled: true
        )

        viewModel.updateDevice(device.stableID, configuration: newConfig)

        XCTAssertEqual(viewModel.devices[0].configuration, newConfig)
        XCTAssertNil(viewModel.error)
    }

    func testUpdateNonExistentDevice() {
        viewModel.updateDevice("nonexistent", configuration: DeviceScrollConfiguration(deviceStableID: "nonexistent"))

        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error?.contains("Device not found") ?? false)
    }

    func testToggleInvertVertical() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        let initialValue = viewModel.devices[0].configuration.transform.invertVertical
        viewModel.toggleInvertVertical(for: device.stableID)

        XCTAssertEqual(viewModel.devices[0].configuration.transform.invertVertical, !initialValue)
    }

    func testToggleInvertHorizontal() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        let initialValue = viewModel.devices[0].configuration.transform.invertHorizontal
        viewModel.toggleInvertHorizontal(for: device.stableID)

        XCTAssertEqual(viewModel.devices[0].configuration.transform.invertHorizontal, !initialValue)
    }

    func testToggleSmoothScroll() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        let initialValue = viewModel.devices[0].configuration.transform.smoothScrollEnabled
        viewModel.toggleSmoothScroll(for: device.stableID)

        XCTAssertEqual(viewModel.devices[0].configuration.transform.smoothScrollEnabled, !initialValue)
    }

    func testSetVerticalMultiplier() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        viewModel.setVerticalMultiplier(for: device.stableID, value: 2.5)

        XCTAssertEqual(viewModel.devices[0].configuration.transform.verticalMultiplier, 2.5)
    }

    func testSetHorizontalMultiplier() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        viewModel.setHorizontalMultiplier(for: device.stableID, value: 0.5)

        XCTAssertEqual(viewModel.devices[0].configuration.transform.horizontalMultiplier, 0.5)
    }

    func testToggleEnabled() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        let initialValue = viewModel.devices[0].configuration.enabled
        viewModel.toggleEnabled(for: device.stableID)

        XCTAssertEqual(viewModel.devices[0].configuration.enabled, !initialValue)
    }

    // MARK: - Default Configuration Tests

    func testUpdateDefaultTransform() {
        let newTransform = ScrollTransform(
            invertVertical: true,
            invertHorizontal: true,
            verticalMultiplier: 1.5,
            horizontalMultiplier: 0.8,
            smoothScrollEnabled: true
        )

        viewModel.updateDefaultTransform(newTransform)

        XCTAssertEqual(viewModel.defaultTransform, newTransform)
        XCTAssertNil(viewModel.error)
    }

    func testUpdateSmoothScrollParameters() {
        let newParams = SmoothScrollParameters(
            duration: 0.5,
            curve: .easeInOut,
            distanceMultiplier: 1.2,
            minimumDelta: 0.05
        )

        viewModel.updateSmoothScrollParameters(newParams)

        XCTAssertEqual(viewModel.smoothScrollParameters, newParams)
        XCTAssertNil(viewModel.error)
    }

    // MARK: - Device Reset Tests

    func testResetDevice() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        // Modify device configuration
        viewModel.setVerticalMultiplier(for: device.stableID, value: 3.0)
        viewModel.toggleInvertVertical(for: device.stableID)

        XCTAssertEqual(viewModel.devices[0].configuration.transform.verticalMultiplier, 3.0)
        XCTAssertTrue(viewModel.devices[0].configuration.transform.invertVertical)

        // Reset
        viewModel.resetDevice(device.stableID)

        XCTAssertEqual(viewModel.devices[0].configuration.transform, .identity)
        XCTAssertNil(viewModel.error)
    }

    func testRemoveDevice() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        XCTAssertEqual(viewModel.devices.count, 1)

        viewModel.removeDevice(device.stableID)

        XCTAssertEqual(viewModel.devices.count, 0)
        XCTAssertNil(viewModel.error)
    }

    // MARK: - Error Handling Tests

    func testErrorClearing() {
        viewModel.updateDevice("nonexistent", configuration: DeviceScrollConfiguration(deviceStableID: "nonexistent"))
        XCTAssertNotNil(viewModel.error)

        viewModel.clearError()
        XCTAssertNil(viewModel.error)
    }

    func testLoadConfigurationWithEnumerationError() {
        mockEnumerator.shouldThrowError = true

        viewModel.loadConfiguration()

        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error?.contains("Failed to load configuration") ?? false)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Persistence Tests

    func testConfigurationPersistsAfterViewModelRecreation() throws {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()

        // Modify and save
        viewModel.setVerticalMultiplier(for: device.stableID, value: 2.5)
        viewModel.toggleInvertVertical(for: device.stableID)

        // Create new view model
        let newViewModel = ScrollMasterViewModel(
            enumerator: mockEnumerator,
            configManager: ScrollConfigurationManager(),
            registry: ScrollConfigurationRegistry()
        )

        XCTAssertEqual(newViewModel.devices.count, 1)
        XCTAssertEqual(newViewModel.devices[0].configuration.transform.verticalMultiplier, 2.5)
        XCTAssertTrue(newViewModel.devices[0].configuration.transform.invertVertical)
    }

    // MARK: - Multiple Device Tests

    func testMultipleDeviceManagement() {
        let device1 = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Mouse 1",
            transport: "USB"
        )
        let device2 = DeviceIdentity(
            vendorID: 0xABCD,
            productID: 0xEF01,
            serialNumber: "XYZ789",
            locationID: 456,
            productName: "Mouse 2",
            transport: "Bluetooth"
        )
        let device3 = DeviceIdentity(
            vendorID: 0x9999,
            productID: 0x8888,
            serialNumber: "DEF456",
            locationID: 789,
            productName: "Trackpad",
            transport: "USB"
        )

        mockEnumerator.devicesToReturn = [device1, device2, device3]
        viewModel.loadConfiguration()

        XCTAssertEqual(viewModel.devices.count, 3)

        // Modify each device differently
        viewModel.setVerticalMultiplier(for: device1.stableID, value: 2.0)
        viewModel.setVerticalMultiplier(for: device2.stableID, value: 1.5)
        viewModel.setVerticalMultiplier(for: device3.stableID, value: 0.8)

        XCTAssertEqual(viewModel.devices[0].configuration.transform.verticalMultiplier, 2.0)
        XCTAssertEqual(viewModel.devices[1].configuration.transform.verticalMultiplier, 1.5)
        XCTAssertEqual(viewModel.devices[2].configuration.transform.verticalMultiplier, 0.8)
    }

    func testDeviceDisappearingAndReappearing() {
        let device = DeviceIdentity(
            vendorID: 0x1234,
            productID: 0x5678,
            serialNumber: "ABC123",
            locationID: 123,
            productName: "Test Mouse",
            transport: "USB"
        )

        // Device present
        mockEnumerator.devicesToReturn = [device]
        viewModel.loadConfiguration()
        XCTAssertEqual(viewModel.devices.count, 1)

        // Modify config
        viewModel.setVerticalMultiplier(for: device.stableID, value: 2.5)

        // Device disconnected
        mockEnumerator.devicesToReturn = []
        viewModel.refreshDevices()
        XCTAssertEqual(viewModel.devices.count, 0)

        // Device reconnected - should restore config
        mockEnumerator.devicesToReturn = [device]
        viewModel.refreshDevices()
        XCTAssertEqual(viewModel.devices.count, 1)
        XCTAssertEqual(viewModel.devices[0].configuration.transform.verticalMultiplier, 2.5)
    }

    // MARK: - DeviceInfo Tests

    func testDeviceInfoEquality() {
        let device1 = ScrollMasterViewModel.DeviceInfo(
            id: "test-id",
            name: "Test Device",
            vendorID: 0x1234,
            productID: 0x5678,
            configuration: DeviceScrollConfiguration(deviceStableID: "test-id")
        )

        let device2 = ScrollMasterViewModel.DeviceInfo(
            id: "test-id",
            name: "Test Device",
            vendorID: 0x1234,
            productID: 0x5678,
            configuration: DeviceScrollConfiguration(deviceStableID: "test-id")
        )

        XCTAssertEqual(device1, device2)
    }

    func testDeviceInfoInequality() {
        let device1 = ScrollMasterViewModel.DeviceInfo(
            id: "test-id-1",
            name: "Test Device",
            vendorID: 0x1234,
            productID: 0x5678,
            configuration: DeviceScrollConfiguration(deviceStableID: "test-id-1")
        )

        let device2 = ScrollMasterViewModel.DeviceInfo(
            id: "test-id-2",
            name: "Test Device",
            vendorID: 0x1234,
            productID: 0x5678,
            configuration: DeviceScrollConfiguration(deviceStableID: "test-id-2")
        )

        XCTAssertNotEqual(device1, device2)
    }
}

// MARK: - Mock Device Enumerator

class MockDeviceEnumerator: DeviceEnumerator {
    var devicesToReturn: [DeviceIdentity] = []
    var shouldThrowError: Bool = false

    override func enumeratePointingDevices() throws -> [DeviceIdentity] {
        if shouldThrowError {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return devicesToReturn
    }
}

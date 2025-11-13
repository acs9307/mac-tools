import XCTest
@testable import ScrollMaster
@testable import MacToolsCore

final class ScrollConfigurationManagerTests: XCTestCase {
    var manager: ScrollConfigurationManager!
    var testConfigPath: String!

    override func setUp() {
        super.setUp()

        // Create temporary config directory
        let tempDir = NSTemporaryDirectory()
        testConfigPath = (tempDir as NSString).appendingPathComponent("test-config-\(UUID().uuidString).json")

        // Set up test configuration
        Configuration.shared.configPath = testConfigPath

        manager = ScrollConfigurationManager()
    }

    override func tearDown() {
        // Clean up test config file
        if FileManager.default.fileExists(atPath: testConfigPath) {
            try? FileManager.default.removeItem(atPath: testConfigPath)
        }

        manager = nil
        super.tearDown()
    }

    // MARK: - Loading Tests

    func testLoadAllWithNoConfig() {
        let configs = manager.loadAll()
        XCTAssertTrue(configs.isEmpty)
    }

    func testLoadSpecificDeviceWithNoConfig() {
        let config = manager.load(for: "device-1")
        XCTAssertNil(config)
    }

    func testLoadDefaultWithNoConfig() {
        let transform = manager.loadDefault()
        XCTAssertEqual(transform, .identity)
    }

    func testLoadSmoothScrollParametersWithNoConfig() {
        let params = manager.loadSmoothScrollParameters()
        XCTAssertEqual(params, .default)
    }

    // MARK: - Saving and Loading Device Configs

    func testSaveAndLoadSingleDevice() throws {
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true, verticalMultiplier: 2.0),
            enabled: true
        )

        try manager.save(config)

        let loaded = manager.load(for: "device-1")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, config)
    }

    func testSaveAndLoadMultipleDevices() throws {
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
            transform: ScrollTransform(verticalMultiplier: 1.5)
        )

        try manager.save(config1)
        try manager.save(config2)
        try manager.save(config3)

        let allConfigs = manager.loadAll()
        XCTAssertEqual(allConfigs.count, 3)
        XCTAssertEqual(allConfigs["device-1"], config1)
        XCTAssertEqual(allConfigs["device-2"], config2)
        XCTAssertEqual(allConfigs["device-3"], config3)
    }

    func testSaveOverwritesExistingDevice() throws {
        let config1 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )

        try manager.save(config1)

        let config2 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertHorizontal: true)
        )

        try manager.save(config2)

        let loaded = manager.load(for: "device-1")
        XCTAssertEqual(loaded, config2)
        XCTAssertNotEqual(loaded, config1)

        let allConfigs = manager.loadAll()
        XCTAssertEqual(allConfigs.count, 1)
    }

    func testSaveAllDevices() throws {
        let configs: [String: DeviceScrollConfiguration] = [
            "device-1": DeviceScrollConfiguration(
                deviceStableID: "device-1",
                transform: ScrollTransform(invertVertical: true)
            ),
            "device-2": DeviceScrollConfiguration(
                deviceStableID: "device-2",
                transform: ScrollTransform(invertHorizontal: true)
            ),
            "device-3": DeviceScrollConfiguration(
                deviceStableID: "device-3",
                transform: ScrollTransform(verticalMultiplier: 2.0)
            )
        ]

        try manager.saveAll(configs)

        let loaded = manager.loadAll()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded["device-1"], configs["device-1"])
        XCTAssertEqual(loaded["device-2"], configs["device-2"])
        XCTAssertEqual(loaded["device-3"], configs["device-3"])
    }

    func testSaveAllReplacesExisting() throws {
        let config1 = DeviceScrollConfiguration(deviceStableID: "device-old")
        try manager.save(config1)

        let newConfigs: [String: DeviceScrollConfiguration] = [
            "device-1": DeviceScrollConfiguration(deviceStableID: "device-1"),
            "device-2": DeviceScrollConfiguration(deviceStableID: "device-2")
        ]

        try manager.saveAll(newConfigs)

        let loaded = manager.loadAll()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertNil(loaded["device-old"])
        XCTAssertNotNil(loaded["device-1"])
        XCTAssertNotNil(loaded["device-2"])
    }

    // MARK: - Remove Tests

    func testRemoveDevice() throws {
        let config = DeviceScrollConfiguration(deviceStableID: "device-1")
        try manager.save(config)

        XCTAssertNotNil(manager.load(for: "device-1"))

        try manager.remove(for: "device-1")

        XCTAssertNil(manager.load(for: "device-1"))
    }

    func testRemoveNonExistentDevice() throws {
        // Should not throw
        try manager.remove(for: "nonexistent")
    }

    func testRemoveOneOfMultipleDevices() throws {
        let config1 = DeviceScrollConfiguration(deviceStableID: "device-1")
        let config2 = DeviceScrollConfiguration(deviceStableID: "device-2")
        let config3 = DeviceScrollConfiguration(deviceStableID: "device-3")

        try manager.save(config1)
        try manager.save(config2)
        try manager.save(config3)

        try manager.remove(for: "device-2")

        let loaded = manager.loadAll()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertNotNil(loaded["device-1"])
        XCTAssertNil(loaded["device-2"])
        XCTAssertNotNil(loaded["device-3"])
    }

    // MARK: - Default Configuration Tests

    func testSaveAndLoadDefaultConfiguration() throws {
        let customDefault = ScrollTransform(
            invertVertical: true,
            invertHorizontal: false,
            verticalMultiplier: 1.5,
            horizontalMultiplier: 0.8,
            smoothScrollEnabled: true
        )

        try manager.saveDefault(customDefault)

        let loaded = manager.loadDefault()
        XCTAssertEqual(loaded, customDefault)
    }

    func testDefaultConfigurationPersistsWithDeviceConfigs() throws {
        let customDefault = ScrollTransform(invertVertical: true)
        try manager.saveDefault(customDefault)

        let config = DeviceScrollConfiguration(deviceStableID: "device-1")
        try manager.save(config)

        let loadedDefault = manager.loadDefault()
        XCTAssertEqual(loadedDefault, customDefault)

        let loadedDevice = manager.load(for: "device-1")
        XCTAssertNotNil(loadedDevice)
    }

    // MARK: - Smooth Scroll Parameters Tests

    func testSaveAndLoadSmoothScrollParameters() throws {
        let params = SmoothScrollParameters(
            duration: 0.5,
            curve: .easeInOut,
            distanceMultiplier: 1.2,
            minimumDelta: 0.05
        )

        try manager.saveSmoothScrollParameters(params)

        let loaded = manager.loadSmoothScrollParameters()
        XCTAssertEqual(loaded, params)
    }

    func testSmoothScrollParametersAllCurves() throws {
        for curve in [InterpolationCurve.linear, .easeIn, .easeOut, .easeInOut] {
            let params = SmoothScrollParameters(curve: curve)
            try manager.saveSmoothScrollParameters(params)

            let loaded = manager.loadSmoothScrollParameters()
            XCTAssertEqual(loaded.curve, curve)
        }
    }

    func testSmoothScrollParametersPersistWithOtherConfigs() throws {
        let params = SmoothScrollParameters(duration: 0.4)
        try manager.saveSmoothScrollParameters(params)

        let config = DeviceScrollConfiguration(deviceStableID: "device-1")
        try manager.save(config)

        let customDefault = ScrollTransform(invertVertical: true)
        try manager.saveDefault(customDefault)

        let loadedParams = manager.loadSmoothScrollParameters()
        XCTAssertEqual(loadedParams, params)

        let loadedDevice = manager.load(for: "device-1")
        XCTAssertNotNil(loadedDevice)

        let loadedDefault = manager.loadDefault()
        XCTAssertEqual(loadedDefault, customDefault)
    }

    // MARK: - Complex Transform Tests

    func testComplexTransform() throws {
        let transform = ScrollTransform(
            invertVertical: true,
            invertHorizontal: true,
            verticalMultiplier: 2.5,
            horizontalMultiplier: 0.5,
            smoothScrollEnabled: true
        )

        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform,
            enabled: false
        )

        try manager.save(config)

        let loaded = manager.load(for: "device-1")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.transform.invertVertical, true)
        XCTAssertEqual(loaded?.transform.invertHorizontal, true)
        XCTAssertEqual(loaded?.transform.verticalMultiplier, 2.5)
        XCTAssertEqual(loaded?.transform.horizontalMultiplier, 0.5)
        XCTAssertEqual(loaded?.transform.smoothScrollEnabled, true)
        XCTAssertEqual(loaded?.enabled, false)
    }

    // MARK: - Edge Cases

    func testEmptyDeviceID() throws {
        let config = DeviceScrollConfiguration(deviceStableID: "")
        try manager.save(config)

        let loaded = manager.load(for: "")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, config)
    }

    func testVeryLongDeviceID() throws {
        let longID = String(repeating: "A", count: 1000)
        let config = DeviceScrollConfiguration(deviceStableID: longID)

        try manager.save(config)

        let loaded = manager.load(for: longID)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.deviceStableID, longID)
    }

    func testSpecialCharactersInDeviceID() throws {
        let specialID = "device-!@#$%^&*()_+-=[]{}|;:',.<>?/~`"
        let config = DeviceScrollConfiguration(deviceStableID: specialID)

        try manager.save(config)

        let loaded = manager.load(for: specialID)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.deviceStableID, specialID)
    }

    func testZeroMultipliers() throws {
        let transform = ScrollTransform(
            verticalMultiplier: 0.0,
            horizontalMultiplier: 0.0
        )

        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform
        )

        try manager.save(config)

        let loaded = manager.load(for: "device-1")
        XCTAssertEqual(loaded?.transform.verticalMultiplier, 0.0)
        XCTAssertEqual(loaded?.transform.horizontalMultiplier, 0.0)
    }

    func testNegativeMultipliers() throws {
        let transform = ScrollTransform(
            verticalMultiplier: -1.5,
            horizontalMultiplier: -0.5
        )

        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform
        )

        try manager.save(config)

        let loaded = manager.load(for: "device-1")
        XCTAssertEqual(loaded?.transform.verticalMultiplier, -1.5)
        XCTAssertEqual(loaded?.transform.horizontalMultiplier, -0.5)
    }

    func testVeryLargeMultipliers() throws {
        let transform = ScrollTransform(
            verticalMultiplier: 1000.0,
            horizontalMultiplier: 999.9
        )

        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: transform
        )

        try manager.save(config)

        let loaded = manager.load(for: "device-1")
        XCTAssertEqual(loaded?.transform.verticalMultiplier, 1000.0)
        XCTAssertEqual(loaded?.transform.horizontalMultiplier, 999.9)
    }

    func testVerySmallDurations() throws {
        let params = SmoothScrollParameters(duration: 0.001)
        try manager.saveSmoothScrollParameters(params)

        let loaded = manager.loadSmoothScrollParameters()
        XCTAssertEqual(loaded.duration, 0.001)
    }

    func testVeryLargeDurations() throws {
        let params = SmoothScrollParameters(duration: 10.0)
        try manager.saveSmoothScrollParameters(params)

        let loaded = manager.loadSmoothScrollParameters()
        XCTAssertEqual(loaded.duration, 10.0)
    }

    // MARK: - Persistence Tests

    func testConfigurationPersistsAcrossManagerInstances() throws {
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )

        try manager.save(config)

        // Create new manager instance
        let newManager = ScrollConfigurationManager()
        let loaded = newManager.load(for: "device-1")

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, config)
    }

    func testAllConfigTypesPersistTogether() throws {
        // Save device config
        let deviceConfig = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )
        try manager.save(deviceConfig)

        // Save default
        let defaultTransform = ScrollTransform(invertHorizontal: true)
        try manager.saveDefault(defaultTransform)

        // Save smooth scroll params
        let params = SmoothScrollParameters(duration: 0.5, curve: .easeInOut)
        try manager.saveSmoothScrollParameters(params)

        // Create new manager and verify all persist
        let newManager = ScrollConfigurationManager()

        let loadedDevice = newManager.load(for: "device-1")
        XCTAssertEqual(loadedDevice, deviceConfig)

        let loadedDefault = newManager.loadDefault()
        XCTAssertEqual(loadedDefault, defaultTransform)

        let loadedParams = newManager.loadSmoothScrollParameters()
        XCTAssertEqual(loadedParams, params)
    }

    // MARK: - Multiple Device Management

    func testLargeNumberOfDevices() throws {
        var configs: [String: DeviceScrollConfiguration] = [:]

        for i in 0..<100 {
            let config = DeviceScrollConfiguration(
                deviceStableID: "device-\(i)",
                transform: ScrollTransform(verticalMultiplier: Double(i) / 10.0)
            )
            configs["device-\(i)"] = config
        }

        try manager.saveAll(configs)

        let loaded = manager.loadAll()
        XCTAssertEqual(loaded.count, 100)

        for i in 0..<100 {
            XCTAssertEqual(loaded["device-\(i)"]?.transform.verticalMultiplier, Double(i) / 10.0)
        }
    }

    func testMixedEnabledDisabledDevices() throws {
        let config1 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true),
            enabled: true
        )
        let config2 = DeviceScrollConfiguration(
            deviceStableID: "device-2",
            transform: ScrollTransform(invertHorizontal: true),
            enabled: false
        )
        let config3 = DeviceScrollConfiguration(
            deviceStableID: "device-3",
            transform: ScrollTransform(verticalMultiplier: 2.0),
            enabled: true
        )

        try manager.save(config1)
        try manager.save(config2)
        try manager.save(config3)

        let loaded = manager.loadAll()
        XCTAssertEqual(loaded["device-1"]?.enabled, true)
        XCTAssertEqual(loaded["device-2"]?.enabled, false)
        XCTAssertEqual(loaded["device-3"]?.enabled, true)
    }
}

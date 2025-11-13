import XCTest
@testable import ScrollMaster

final class DeviceIdentityTests: XCTestCase {
    // MARK: - Initialization Tests

    func testBasicInitialization() {
        let device = DeviceIdentity(vendorID: 1234, productID: 5678)

        XCTAssertEqual(device.vendorID, 1234)
        XCTAssertEqual(device.productID, 5678)
        XCTAssertNil(device.serialNumber)
        XCTAssertNil(device.locationID)
        XCTAssertNil(device.productName)
        XCTAssertNil(device.transport)
    }

    func testFullInitialization() {
        let device = DeviceIdentity(
            vendorID: 1452, // Apple
            productID: 613,
            serialNumber: "ABC123XYZ",
            locationID: 123456,
            productName: "Magic Mouse",
            transport: "Bluetooth"
        )

        XCTAssertEqual(device.vendorID, 1452)
        XCTAssertEqual(device.productID, 613)
        XCTAssertEqual(device.serialNumber, "ABC123XYZ")
        XCTAssertEqual(device.locationID, 123456)
        XCTAssertEqual(device.productName, "Magic Mouse")
        XCTAssertEqual(device.transport, "Bluetooth")
    }

    // MARK: - Stable ID Tests

    func testStableIDWithMinimalInfo() {
        let device = DeviceIdentity(vendorID: 1234, productID: 5678)
        let stableID = device.stableID

        XCTAssertEqual(stableID, "1234-5678")
    }

    func testStableIDWithSerialNumber() {
        let device = DeviceIdentity(
            vendorID: 1234,
            productID: 5678,
            serialNumber: "SN123"
        )

        let stableID = device.stableID
        XCTAssertEqual(stableID, "1234-5678-SN123")
    }

    func testStableIDWithLocationID() {
        let device = DeviceIdentity(
            vendorID: 1234,
            productID: 5678,
            serialNumber: nil,
            locationID: 999
        )

        let stableID = device.stableID
        XCTAssertEqual(stableID, "1234-5678-999")
    }

    func testStableIDWithAllInfo() {
        let device = DeviceIdentity(
            vendorID: 1234,
            productID: 5678,
            serialNumber: "SN123",
            locationID: 999
        )

        let stableID = device.stableID
        XCTAssertEqual(stableID, "1234-5678-SN123-999")
    }

    func testStableIDConsistency() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 100, productID: 200)

        XCTAssertEqual(device1.stableID, device2.stableID)
    }

    func testStableIDUniqueness() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 100, productID: 201)
        let device3 = DeviceIdentity(vendorID: 101, productID: 200)

        XCTAssertNotEqual(device1.stableID, device2.stableID)
        XCTAssertNotEqual(device1.stableID, device3.stableID)
        XCTAssertNotEqual(device2.stableID, device3.stableID)
    }

    // MARK: - Description Tests

    func testDescriptionWithProductName() {
        let device = DeviceIdentity(
            vendorID: 1452,
            productID: 613,
            productName: "Magic Mouse"
        )

        let description = device.description
        XCTAssertTrue(description.contains("Magic Mouse"))
        XCTAssertTrue(description.contains("VID:1452"))
        XCTAssertTrue(description.contains("PID:613"))
    }

    func testDescriptionWithoutProductName() {
        let device = DeviceIdentity(vendorID: 1234, productID: 5678)

        let description = device.description
        XCTAssertTrue(description.contains("VID:1234"))
        XCTAssertTrue(description.contains("PID:5678"))
    }

    func testDescriptionWithSerialNumber() {
        let device = DeviceIdentity(
            vendorID: 1234,
            productID: 5678,
            serialNumber: "ABC123"
        )

        let description = device.description
        XCTAssertTrue(description.contains("SN:ABC123"))
    }

    func testDescriptionWithTransport() {
        let device = DeviceIdentity(
            vendorID: 1234,
            productID: 5678,
            transport: "USB"
        )

        let description = device.description
        XCTAssertTrue(description.contains("(USB)"))
    }

    func testDescriptionComplete() {
        let device = DeviceIdentity(
            vendorID: 1452,
            productID: 613,
            serialNumber: "ABC123",
            locationID: 999,
            productName: "Magic Mouse",
            transport: "Bluetooth"
        )

        let description = device.description
        XCTAssertTrue(description.contains("Magic Mouse"))
        XCTAssertTrue(description.contains("VID:1452"))
        XCTAssertTrue(description.contains("PID:613"))
        XCTAssertTrue(description.contains("SN:ABC123"))
        XCTAssertTrue(description.contains("(Bluetooth)"))
    }

    // MARK: - Hashable Tests

    func testHashableEquality() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 100, productID: 200)

        XCTAssertEqual(device1, device2)
    }

    func testHashableInequality() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 100, productID: 201)

        XCTAssertNotEqual(device1, device2)
    }

    func testHashableWithSerialNumber() {
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

        XCTAssertNotEqual(device1, device2)
    }

    func testHashValueConsistency() {
        let device = DeviceIdentity(vendorID: 100, productID: 200)
        let hash1 = device.hashValue
        let hash2 = device.hashValue

        XCTAssertEqual(hash1, hash2)
    }

    func testCanBeUsedInSet() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 100, productID: 200)
        let device3 = DeviceIdentity(vendorID: 100, productID: 201)

        let set: Set<DeviceIdentity> = [device1, device2, device3]

        XCTAssertEqual(set.count, 2) // device1 and device2 are equal
    }

    func testCanBeUsedAsDictionaryKey() {
        let device1 = DeviceIdentity(vendorID: 100, productID: 200)
        let device2 = DeviceIdentity(vendorID: 100, productID: 200)

        var dict: [DeviceIdentity: String] = [:]
        dict[device1] = "First"
        dict[device2] = "Second" // Should overwrite

        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict[device1], "Second")
    }

    // MARK: - Codable Tests

    func testCodableEncoding() throws {
        let device = DeviceIdentity(
            vendorID: 1234,
            productID: 5678,
            serialNumber: "ABC123",
            locationID: 999,
            productName: "Test Mouse",
            transport: "USB"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(device)

        XCTAssertFalse(data.isEmpty)
    }

    func testCodableDecoding() throws {
        let device = DeviceIdentity(
            vendorID: 1234,
            productID: 5678,
            serialNumber: "ABC123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(device)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeviceIdentity.self, from: data)

        XCTAssertEqual(decoded, device)
    }

    func testCodableRoundTrip() throws {
        let original = DeviceIdentity(
            vendorID: 1452,
            productID: 613,
            serialNumber: "SERIAL123",
            locationID: 12345,
            productName: "Magic Mouse 2",
            transport: "Bluetooth"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeviceIdentity.self, from: data)

        XCTAssertEqual(decoded.vendorID, original.vendorID)
        XCTAssertEqual(decoded.productID, original.productID)
        XCTAssertEqual(decoded.serialNumber, original.serialNumber)
        XCTAssertEqual(decoded.locationID, original.locationID)
        XCTAssertEqual(decoded.productName, original.productName)
        XCTAssertEqual(decoded.transport, original.transport)
    }

    // MARK: - Edge Cases

    func testZeroVendorAndProductID() {
        let device = DeviceIdentity(vendorID: 0, productID: 0)

        XCTAssertEqual(device.stableID, "0-0")
    }

    func testLargeVendorAndProductID() {
        let device = DeviceIdentity(vendorID: 65535, productID: 65535)

        XCTAssertEqual(device.stableID, "65535-65535")
    }

    func testEmptySerialNumber() {
        let device = DeviceIdentity(
            vendorID: 100,
            productID: 200,
            serialNumber: ""
        )

        // Empty string should still be included in stable ID
        XCTAssertEqual(device.stableID, "100-200-")
    }

    func testLongSerialNumber() {
        let longSerial = String(repeating: "A", count: 100)
        let device = DeviceIdentity(
            vendorID: 100,
            productID: 200,
            serialNumber: longSerial
        )

        XCTAssertTrue(device.stableID.contains(longSerial))
    }

    func testSpecialCharactersInProductName() {
        let device = DeviceIdentity(
            vendorID: 100,
            productID: 200,
            productName: "Mouse™ 2.0 (Pro)"
        )

        let description = device.description
        XCTAssertTrue(description.contains("Mouse™ 2.0 (Pro)"))
    }
}

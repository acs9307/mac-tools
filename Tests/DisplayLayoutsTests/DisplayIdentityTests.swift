import XCTest
@testable import DisplayLayouts

final class DisplayIdentityTests: XCTestCase {
    // MARK: - DisplayBounds Tests

    func testDisplayBoundsInitialization() {
        let bounds = DisplayBounds(x: 100, y: 200, width: 1920, height: 1080)

        XCTAssertEqual(bounds.x, 100)
        XCTAssertEqual(bounds.y, 200)
        XCTAssertEqual(bounds.width, 1920)
        XCTAssertEqual(bounds.height, 1080)
    }

    func testDisplayBoundsFromCGRect() {
        let rect = CGRect(x: 100, y: 200, width: 1920, height: 1080)
        let bounds = DisplayBounds(rect)

        XCTAssertEqual(bounds.x, 100)
        XCTAssertEqual(bounds.y, 200)
        XCTAssertEqual(bounds.width, 1920)
        XCTAssertEqual(bounds.height, 1080)
    }

    func testDisplayBoundsToCGRect() {
        let bounds = DisplayBounds(x: 100, y: 200, width: 1920, height: 1080)
        let rect = bounds.cgRect

        XCTAssertEqual(rect.origin.x, 100)
        XCTAssertEqual(rect.origin.y, 200)
        XCTAssertEqual(rect.size.width, 1920)
        XCTAssertEqual(rect.size.height, 1080)
    }

    func testDisplayBoundsArea() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(bounds.area, 1920 * 1080)
    }

    func testDisplayBoundsEquality() {
        let bounds1 = DisplayBounds(x: 100, y: 200, width: 1920, height: 1080)
        let bounds2 = DisplayBounds(x: 100, y: 200, width: 1920, height: 1080)

        XCTAssertEqual(bounds1, bounds2)
    }

    func testDisplayBoundsInequality() {
        let bounds1 = DisplayBounds(x: 100, y: 200, width: 1920, height: 1080)
        let bounds2 = DisplayBounds(x: 100, y: 200, width: 2560, height: 1440)

        XCTAssertNotEqual(bounds1, bounds2)
    }

    // MARK: - DisplayIdentity Tests

    func testDisplayIdentityInitialization() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 2.0,
            isMain: true
        )

        XCTAssertEqual(display.displayID, 1)
        XCTAssertEqual(display.serialNumber, "ABC123")
        XCTAssertEqual(display.vendorID, 0x1234)
        XCTAssertEqual(display.modelID, 0x5678)
        XCTAssertEqual(display.name, "Test Display")
        XCTAssertEqual(display.bounds, bounds)
        XCTAssertEqual(display.scale, 2.0)
        XCTAssertTrue(display.isMain)
    }

    func testDisplayIdentityStableIDWithSerial() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        XCTAssertEqual(display.stableID, "0x00001234-0x00005678-ABC123")
    }

    func testDisplayIdentityStableIDWithoutSerial() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: nil,
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        XCTAssertEqual(display.stableID, "0x00001234-0x00005678")
    }

    func testDisplayIdentityStableIDWithEmptySerial() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        XCTAssertEqual(display.stableID, "0x00001234-0x00005678")
    }

    func testDisplayIdentityEquality() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        let display2 = DisplayIdentity(
            displayID: 2, // Different display ID
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 2",  // Different name
            bounds: DisplayBounds(x: 100, y: 100, width: 2560, height: 1440), // Different bounds
            scale: 2.0, // Different scale
            isMain: true // Different main status
        )

        // Should be equal because stable ID is the same
        XCTAssertEqual(display1, display2)
    }

    func testDisplayIdentityInequalityDifferentVendor() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        let display2 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0xABCD, // Different vendor
            modelID: 0x5678,
            name: "Display",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        XCTAssertNotEqual(display1, display2)
    }

    func testDisplayIdentityHashing() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 2",
            bounds: DisplayBounds(x: 100, y: 100, width: 2560, height: 1440),
            scale: 2.0,
            isMain: true
        )

        // Same stable ID should hash the same
        XCTAssertEqual(display1.hashValue, display2.hashValue)
    }

    // MARK: - DisplayConfiguration Tests

    func testDisplayConfigurationInitialization() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let config = DisplayConfiguration(displays: [display])

        XCTAssertEqual(config.count, 1)
        XCTAssertEqual(config.displays.count, 1)
        XCTAssertFalse(config.signature.isEmpty)
    }

    func testDisplayConfigurationSortsDisplays() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ZZZ",
            vendorID: 0xFFFF,
            modelID: 0xFFFF,
            name: "Display Z",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "AAA",
            vendorID: 0x0001,
            modelID: 0x0001,
            name: "Display A",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let config = DisplayConfiguration(displays: [display1, display2])

        // Should be sorted by stable ID
        XCTAssertEqual(config.displays[0].stableID, display2.stableID)
        XCTAssertEqual(config.displays[1].stableID, display1.stableID)
    }

    func testDisplayConfigurationSignatureStability() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let config1 = DisplayConfiguration(displays: [display])
        let config2 = DisplayConfiguration(displays: [display])

        // Same displays should produce same signature
        XCTAssertEqual(config1.signature, config2.signature)
    }

    func testDisplayConfigurationSignatureDifferentOrder() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "AAA",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "BBB",
            vendorID: 0xABCD,
            modelID: 0xEF01,
            name: "Display 2",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        let config1 = DisplayConfiguration(displays: [display1, display2])
        let config2 = DisplayConfiguration(displays: [display2, display1])

        // Different order should produce same signature (sorted internally)
        XCTAssertEqual(config1.signature, config2.signature)
    }

    func testDisplayConfigurationSignatureDifferentResolution() {
        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: true
        )

        let display2 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: 2560, height: 1440),
            scale: 1.0,
            isMain: true
        )

        let config1 = DisplayConfiguration(displays: [display1])
        let config2 = DisplayConfiguration(displays: [display2])

        // Different resolution should produce different signature
        XCTAssertNotEqual(config1.signature, config2.signature)
    }

    func testDisplayConfigurationMainDisplay() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "AAA",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "BBB",
            vendorID: 0xABCD,
            modelID: 0xEF01,
            name: "Display 2",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let config = DisplayConfiguration(displays: [display1, display2])

        XCTAssertNotNil(config.mainDisplay)
        XCTAssertEqual(config.mainDisplay?.displayID, 2)
    }

    func testDisplayConfigurationNoMainDisplay() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "AAA",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        let config = DisplayConfiguration(displays: [display])

        XCTAssertNil(config.mainDisplay)
    }

    func testDisplayConfigurationMatches() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let config1 = DisplayConfiguration(displays: [display])
        let config2 = DisplayConfiguration(displays: [display])

        XCTAssertTrue(config1.matches(config2))
    }

    func testDisplayConfigurationMatchesWithMinorResolutionChange() {
        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920.0, height: 1080.0),
            scale: 1.0,
            isMain: true
        )

        let display2 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920.05, height: 1080.05),
            scale: 1.0,
            isMain: true
        )

        let config1 = DisplayConfiguration(displays: [display1])
        let config2 = DisplayConfiguration(displays: [display2])

        // Should match with default tolerance
        XCTAssertTrue(config1.matches(config2))
    }

    func testDisplayConfigurationDoesNotMatchDifferentCount() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "DEF456",
            vendorID: 0xABCD,
            modelID: 0xEF01,
            name: "Display 2",
            bounds: bounds,
            scale: 1.0,
            isMain: false
        )

        let config1 = DisplayConfiguration(displays: [display1])
        let config2 = DisplayConfiguration(displays: [display1, display2])

        XCTAssertFalse(config1.matches(config2))
    }

    func testDisplayConfigurationDoesNotMatchDifferentDisplays() {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)

        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "DEF456",
            vendorID: 0xABCD,
            modelID: 0xEF01,
            name: "Display 2",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let config1 = DisplayConfiguration(displays: [display1])
        let config2 = DisplayConfiguration(displays: [display2])

        XCTAssertFalse(config1.matches(config2))
    }

    func testDisplayConfigurationTotalArea() {
        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "AAA",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: true
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "BBB",
            vendorID: 0xABCD,
            modelID: 0xEF01,
            name: "Display 2",
            bounds: DisplayBounds(x: 1920, y: 0, width: 2560, height: 1440),
            scale: 1.0,
            isMain: false
        )

        let config = DisplayConfiguration(displays: [display1, display2])

        let expectedArea = (1920.0 * 1080.0) + (2560.0 * 1440.0)
        XCTAssertEqual(config.totalArea, expectedArea)
    }

    func testDisplayConfigurationBoundingRect() {
        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "AAA",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: true
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "BBB",
            vendorID: 0xABCD,
            modelID: 0xEF01,
            name: "Display 2",
            bounds: DisplayBounds(x: 1920, y: 0, width: 2560, height: 1440),
            scale: 1.0,
            isMain: false
        )

        let config = DisplayConfiguration(displays: [display1, display2])
        let bounding = config.boundingRect

        XCTAssertEqual(bounding.x, 0)
        XCTAssertEqual(bounding.y, 0)
        XCTAssertEqual(bounding.width, 1920 + 2560)
        XCTAssertEqual(bounding.height, 1440)
    }

    func testDisplayConfigurationBoundingRectNegativeCoordinates() {
        let display1 = DisplayIdentity(
            displayID: 1,
            serialNumber: "AAA",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Display 1",
            bounds: DisplayBounds(x: -1920, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: false
        )

        let display2 = DisplayIdentity(
            displayID: 2,
            serialNumber: "BBB",
            vendorID: 0xABCD,
            modelID: 0xEF01,
            name: "Display 2",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: true
        )

        let config = DisplayConfiguration(displays: [display1, display2])
        let bounding = config.boundingRect

        XCTAssertEqual(bounding.x, -1920)
        XCTAssertEqual(bounding.y, 0)
        XCTAssertEqual(bounding.width, 1920 + 1920)
        XCTAssertEqual(bounding.height, 1080)
    }

    func testDisplayConfigurationEmpty() {
        let config = DisplayConfiguration(displays: [])

        XCTAssertEqual(config.count, 0)
        XCTAssertNil(config.mainDisplay)
        XCTAssertEqual(config.totalArea, 0)

        let bounding = config.boundingRect
        XCTAssertEqual(bounding.width, 0)
        XCTAssertEqual(bounding.height, 0)
    }

    // MARK: - Codable Tests

    func testDisplayBoundsCodable() throws {
        let original = DisplayBounds(x: 100, y: 200, width: 1920, height: 1080)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DisplayBounds.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testDisplayIdentityCodable() throws {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let original = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 2.0,
            isMain: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DisplayIdentity.self, from: data)

        XCTAssertEqual(decoded.displayID, original.displayID)
        XCTAssertEqual(decoded.serialNumber, original.serialNumber)
        XCTAssertEqual(decoded.vendorID, original.vendorID)
        XCTAssertEqual(decoded.modelID, original.modelID)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.bounds, original.bounds)
        XCTAssertEqual(decoded.scale, original.scale)
        XCTAssertEqual(decoded.isMain, original.isMain)
    }

    func testDisplayConfigurationCodable() throws {
        let bounds = DisplayBounds(x: 0, y: 0, width: 1920, height: 1080)
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "ABC123",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: bounds,
            scale: 1.0,
            isMain: true
        )

        let original = DisplayConfiguration(displays: [display])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DisplayConfiguration.self, from: data)

        XCTAssertEqual(decoded.signature, original.signature)
        XCTAssertEqual(decoded.count, original.count)
    }
}

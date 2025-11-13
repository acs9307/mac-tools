import XCTest
@testable import ScrollMaster

final class ScrollTransformTests: XCTestCase {
    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let transform = ScrollTransform()

        XCTAssertFalse(transform.invertVertical)
        XCTAssertFalse(transform.invertHorizontal)
        XCTAssertEqual(transform.verticalMultiplier, 1.0)
        XCTAssertEqual(transform.horizontalMultiplier, 1.0)
        XCTAssertFalse(transform.smoothScrollEnabled)
    }

    func testIdentityTransform() {
        let transform = ScrollTransform.identity

        XCTAssertEqual(transform, ScrollTransform())
    }

    func testCustomInitialization() {
        let transform = ScrollTransform(
            invertVertical: true,
            invertHorizontal: false,
            verticalMultiplier: 2.0,
            horizontalMultiplier: 0.5,
            smoothScrollEnabled: true
        )

        XCTAssertTrue(transform.invertVertical)
        XCTAssertFalse(transform.invertHorizontal)
        XCTAssertEqual(transform.verticalMultiplier, 2.0)
        XCTAssertEqual(transform.horizontalMultiplier, 0.5)
        XCTAssertTrue(transform.smoothScrollEnabled)
    }

    // MARK: - Apply Transform Tests

    func testIdentityTransformApply() {
        let transform = ScrollTransform.identity
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 5.0)

        XCTAssertEqual(v, 10.0)
        XCTAssertEqual(h, 5.0)
    }

    func testInvertVertical() {
        let transform = ScrollTransform(invertVertical: true)
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 5.0)

        XCTAssertEqual(v, -10.0)
        XCTAssertEqual(h, 5.0)
    }

    func testInvertHorizontal() {
        let transform = ScrollTransform(invertHorizontal: true)
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 5.0)

        XCTAssertEqual(v, 10.0)
        XCTAssertEqual(h, -5.0)
    }

    func testInvertBoth() {
        let transform = ScrollTransform(
            invertVertical: true,
            invertHorizontal: true
        )
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 5.0)

        XCTAssertEqual(v, -10.0)
        XCTAssertEqual(h, -5.0)
    }

    func testVerticalMultiplier() {
        let transform = ScrollTransform(verticalMultiplier: 2.0)
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 5.0)

        XCTAssertEqual(v, 20.0)
        XCTAssertEqual(h, 5.0)
    }

    func testHorizontalMultiplier() {
        let transform = ScrollTransform(horizontalMultiplier: 0.5)
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 6.0)

        XCTAssertEqual(v, 10.0)
        XCTAssertEqual(h, 3.0)
    }

    func testInvertAndMultiply() {
        let transform = ScrollTransform(
            invertVertical: true,
            verticalMultiplier: 2.0
        )
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 5.0)

        XCTAssertEqual(v, -20.0)
        XCTAssertEqual(h, 5.0)
    }

    func testComplexTransform() {
        let transform = ScrollTransform(
            invertVertical: true,
            invertHorizontal: false,
            verticalMultiplier: 1.5,
            horizontalMultiplier: 0.75
        )
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 8.0)

        XCTAssertEqual(v, -15.0)
        XCTAssertEqual(h, 6.0)
    }

    // MARK: - Edge Cases

    func testZeroDeltas() {
        let transform = ScrollTransform(invertVertical: true, verticalMultiplier: 2.0)
        let (v, h) = transform.apply(vertical: 0.0, horizontal: 0.0)

        XCTAssertEqual(v, 0.0)
        XCTAssertEqual(h, 0.0)
    }

    func testNegativeDeltas() {
        let transform = ScrollTransform(invertVertical: true)
        let (v, h) = transform.apply(vertical: -10.0, horizontal: -5.0)

        XCTAssertEqual(v, 10.0) // Inverted negative becomes positive
        XCTAssertEqual(h, -5.0)
    }

    func testVerySmallDeltas() {
        let transform = ScrollTransform(verticalMultiplier: 2.0)
        let (v, h) = transform.apply(vertical: 0.001, horizontal: 0.001)

        XCTAssertEqual(v, 0.002, accuracy: 0.0001)
        XCTAssertEqual(h, 0.001, accuracy: 0.0001)
    }

    func testVeryLargeDeltas() {
        let transform = ScrollTransform(verticalMultiplier: 0.5)
        let (v, h) = transform.apply(vertical: 1000.0, horizontal: 1000.0)

        XCTAssertEqual(v, 500.0)
        XCTAssertEqual(h, 1000.0)
    }

    func testZeroMultiplier() {
        let transform = ScrollTransform(verticalMultiplier: 0.0)
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 5.0)

        XCTAssertEqual(v, 0.0)
        XCTAssertEqual(h, 5.0)
    }

    func testNegativeMultiplier() {
        // Negative multiplier should invert (like invert flag)
        let transform = ScrollTransform(verticalMultiplier: -1.0)
        let (v, h) = transform.apply(vertical: 10.0, horizontal: 5.0)

        XCTAssertEqual(v, -10.0)
        XCTAssertEqual(h, 5.0)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let transform1 = ScrollTransform(invertVertical: true, verticalMultiplier: 2.0)
        let transform2 = ScrollTransform(invertVertical: true, verticalMultiplier: 2.0)

        XCTAssertEqual(transform1, transform2)
    }

    func testInequality() {
        let transform1 = ScrollTransform(invertVertical: true)
        let transform2 = ScrollTransform(invertVertical: false)

        XCTAssertNotEqual(transform1, transform2)
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        let original = ScrollTransform(
            invertVertical: true,
            invertHorizontal: false,
            verticalMultiplier: 1.5,
            horizontalMultiplier: 0.8,
            smoothScrollEnabled: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScrollTransform.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

// MARK: - ScrollEvent Tests

final class ScrollEventTests: XCTestCase {
    func testScrollEventInitialization() {
        let event = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 10.0,
            horizontalDelta: 5.0
        )

        XCTAssertEqual(event.deviceID, "device-1")
        XCTAssertEqual(event.verticalDelta, 10.0)
        XCTAssertEqual(event.horizontalDelta, 5.0)
        XCTAssertFalse(event.isContinuous)
    }

    func testScrollEventWithNilDevice() {
        let event = ScrollEvent(
            deviceID: nil,
            verticalDelta: 10.0,
            horizontalDelta: 5.0
        )

        XCTAssertNil(event.deviceID)
    }

    func testScrollEventContinuous() {
        let event = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 10.0,
            horizontalDelta: 5.0,
            isContinuous: true
        )

        XCTAssertTrue(event.isContinuous)
    }

    func testApplyingTransform() {
        let event = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 10.0,
            horizontalDelta: 5.0
        )

        let transform = ScrollTransform(
            invertVertical: true,
            verticalMultiplier: 2.0
        )

        let transformed = event.applying(transform)

        XCTAssertEqual(transformed.deviceID, "device-1")
        XCTAssertEqual(transformed.verticalDelta, -20.0)
        XCTAssertEqual(transformed.horizontalDelta, 5.0)
        XCTAssertEqual(transformed.timestamp, event.timestamp)
        XCTAssertEqual(transformed.isContinuous, event.isContinuous)
    }

    func testApplyingIdentityTransform() {
        let event = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 10.0,
            horizontalDelta: 5.0
        )

        let transformed = event.applying(.identity)

        XCTAssertEqual(transformed.verticalDelta, event.verticalDelta)
        XCTAssertEqual(transformed.horizontalDelta, event.horizontalDelta)
    }

    func testScrollEventEquality() {
        let event1 = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 10.0,
            horizontalDelta: 5.0,
            timestamp: 1000.0
        )

        let event2 = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 10.0,
            horizontalDelta: 5.0,
            timestamp: 1000.0
        )

        XCTAssertEqual(event1, event2)
    }

    func testScrollEventInequality() {
        let event1 = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 10.0,
            horizontalDelta: 5.0
        )

        let event2 = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 11.0,
            horizontalDelta: 5.0
        )

        XCTAssertNotEqual(event1, event2)
    }

    func testNegativeDeltas() {
        let event = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: -10.0,
            horizontalDelta: -5.0
        )

        let transform = ScrollTransform(invertVertical: true)
        let transformed = event.applying(transform)

        XCTAssertEqual(transformed.verticalDelta, 10.0)
        XCTAssertEqual(transformed.horizontalDelta, -5.0)
    }

    func testZeroDeltas() {
        let event = ScrollEvent(
            deviceID: "device-1",
            verticalDelta: 0.0,
            horizontalDelta: 0.0
        )

        let transform = ScrollTransform(invertVertical: true, verticalMultiplier: 2.0)
        let transformed = event.applying(transform)

        XCTAssertEqual(transformed.verticalDelta, 0.0)
        XCTAssertEqual(transformed.horizontalDelta, 0.0)
    }
}

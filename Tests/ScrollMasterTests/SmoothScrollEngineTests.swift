import XCTest
@testable import ScrollMaster

final class InterpolationCurveTests: XCTestCase {
    func testLinearCurve() {
        let curve = InterpolationCurve.linear

        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(0.25), 0.25, accuracy: 0.001)
        XCTAssertEqual(curve.apply(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(curve.apply(0.75), 0.75, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testEaseInCurve() {
        let curve = InterpolationCurve.easeIn

        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertLessThan(curve.apply(0.5), 0.5) // Slower at start
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testEaseOutCurve() {
        let curve = InterpolationCurve.easeOut

        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertGreaterThan(curve.apply(0.5), 0.5) // Faster at start
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testEaseInOutCurve() {
        let curve = InterpolationCurve.easeInOut

        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testCurveClamping() {
        let curve = InterpolationCurve.linear

        // Values outside 0-1 should be clamped
        XCTAssertEqual(curve.apply(-0.5), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.5), 1.0, accuracy: 0.001)
    }

    func testAllCurvesStartAndEnd() {
        let curves: [InterpolationCurve] = [.linear, .easeIn, .easeOut, .easeInOut]

        for curve in curves {
            XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001, "Curve \(curve) should start at 0")
            XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001, "Curve \(curve) should end at 1")
        }
    }

    func testAllCurvesMonotonic() {
        let curves: [InterpolationCurve] = [.linear, .easeIn, .easeOut, .easeInOut]

        for curve in curves {
            var prev = 0.0
            for i in 0...100 {
                let t = Double(i) / 100.0
                let value = curve.apply(t)
                XCTAssertGreaterThanOrEqual(value, prev, "Curve \(curve) should be monotonically increasing")
                prev = value
            }
        }
    }
}

final class SmoothScrollParametersTests: XCTestCase {
    func testDefaultParameters() {
        let params = SmoothScrollParameters.default

        XCTAssertEqual(params.duration, 0.3)
        XCTAssertEqual(params.curve, .easeOut)
        XCTAssertEqual(params.distanceMultiplier, 1.0)
        XCTAssertEqual(params.minimumDelta, 0.01)
    }

    func testCustomParameters() {
        let params = SmoothScrollParameters(
            duration: 0.5,
            curve: .linear,
            distanceMultiplier: 2.0,
            minimumDelta: 0.1
        )

        XCTAssertEqual(params.duration, 0.5)
        XCTAssertEqual(params.curve, .linear)
        XCTAssertEqual(params.distanceMultiplier, 2.0)
        XCTAssertEqual(params.minimumDelta, 0.1)
    }

    func testEquatable() {
        let params1 = SmoothScrollParameters(duration: 0.3, curve: .easeOut)
        let params2 = SmoothScrollParameters(duration: 0.3, curve: .easeOut)

        XCTAssertEqual(params1, params2)
    }

    func testCodable() throws {
        let original = SmoothScrollParameters(
            duration: 0.4,
            curve: .easeInOut,
            distanceMultiplier: 1.5,
            minimumDelta: 0.05
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SmoothScrollParameters.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

final class SmoothScrollEngineTests: XCTestCase {
    var engine: SmoothScrollEngine!
    var currentTime: TimeInterval!

    override func setUp() {
        currentTime = 0.0
        engine = SmoothScrollEngine(
            parameters: .default,
            timeProvider: { [unowned self] in self.currentTime }
        )
    }

    override func tearDown() {
        engine = nil
        currentTime = nil
    }

    func advanceTime(by interval: TimeInterval) {
        currentTime += interval
    }

    // MARK: - Basic Functionality

    func testInitialState() {
        XCTAssertFalse(engine.hasActiveAnimations)
        XCTAssertEqual(engine.activeAnimationCount, 0)

        let (v, h) = engine.tick()
        XCTAssertEqual(v, 0.0)
        XCTAssertEqual(h, 0.0)
    }

    func testSingleInput() {
        engine.addInput(vertical: 10.0, horizontal: 0.0)

        XCTAssertTrue(engine.hasActiveAnimations)
        XCTAssertEqual(engine.activeAnimationCount, 1)
    }

    func testInputAndTick() {
        engine.addInput(vertical: 10.0, horizontal: 0.0)

        // First tick should return some delta
        let (v1, _) = engine.tick()
        XCTAssertGreaterThan(v1, 0.0)
        XCTAssertLessThan(v1, 10.0) // Should not return all at once
    }

    func testAnimationCompletion() {
        engine.addInput(vertical: 10.0, horizontal: 0.0)

        var totalV = 0.0

        // Tick through the entire animation
        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        // Should have scrolled the full amount (within tolerance)
        XCTAssertEqual(totalV, 10.0, accuracy: 0.1)

        // Animation should be complete
        XCTAssertFalse(engine.hasActiveAnimations)
    }

    func testMultipleInputs() {
        engine.addInput(vertical: 10.0, horizontal: 0.0)
        engine.addInput(vertical: 5.0, horizontal: 0.0)

        XCTAssertEqual(engine.activeAnimationCount, 2)
    }

    func testMultipleInputsAccumulate() {
        engine.addInput(vertical: 10.0, horizontal: 0.0)
        advanceTime(by: 0.05)
        engine.addInput(vertical: 10.0, horizontal: 0.0)

        var totalV = 0.0

        // Tick through both animations
        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        // Should have scrolled both amounts
        XCTAssertEqual(totalV, 20.0, accuracy: 0.2)
    }

    // MARK: - Horizontal Scrolling

    func testHorizontalScrolling() {
        engine.addInput(vertical: 0.0, horizontal: 10.0)

        var totalH = 0.0

        for _ in 0...100 {
            let (_, h) = engine.tick()
            totalH += h
            advanceTime(by: 0.01)
        }

        XCTAssertEqual(totalH, 10.0, accuracy: 0.1)
    }

    func testBothDirections() {
        engine.addInput(vertical: 10.0, horizontal: 5.0)

        var totalV = 0.0
        var totalH = 0.0

        for _ in 0...100 {
            let (v, h) = engine.tick()
            totalV += v
            totalH += h
            advanceTime(by: 0.01)
        }

        XCTAssertEqual(totalV, 10.0, accuracy: 0.1)
        XCTAssertEqual(totalH, 5.0, accuracy: 0.1)
    }

    // MARK: - Parameter Effects

    func testDistanceMultiplier() {
        let params = SmoothScrollParameters(
            duration: 0.3,
            curve: .linear,
            distanceMultiplier: 2.0
        )
        engine.updateParameters(params)

        engine.addInput(vertical: 10.0, horizontal: 0.0)

        var totalV = 0.0

        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        // Should be multiplied by 2
        XCTAssertEqual(totalV, 20.0, accuracy: 0.2)
    }

    func testMinimumDeltaFiltering() {
        let params = SmoothScrollParameters(
            duration: 0.3,
            curve: .linear,
            minimumDelta: 1.0 // Filter out anything below 1.0
        )
        engine.updateParameters(params)

        engine.addInput(vertical: 0.5, horizontal: 0.0) // Below threshold

        XCTAssertFalse(engine.hasActiveAnimations) // Should be filtered out
    }

    func testMinimumDeltaPassthrough() {
        let params = SmoothScrollParameters(
            duration: 0.3,
            curve: .linear,
            minimumDelta: 1.0
        )
        engine.updateParameters(params)

        engine.addInput(vertical: 2.0, horizontal: 0.0) // Above threshold

        XCTAssertTrue(engine.hasActiveAnimations) // Should pass through
    }

    func testDifferentDuration() {
        let params = SmoothScrollParameters(
            duration: 0.1, // Shorter duration
            curve: .linear
        )
        engine.updateParameters(params)

        engine.addInput(vertical: 10.0, horizontal: 0.0)

        // Should complete faster
        advanceTime(by: 0.15)
        _ = engine.tick()

        XCTAssertFalse(engine.hasActiveAnimations)
    }

    func testDifferentCurves() {
        let curves: [InterpolationCurve] = [.linear, .easeIn, .easeOut, .easeInOut]

        for curve in curves {
            setUp() // Reset

            let params = SmoothScrollParameters(duration: 0.3, curve: curve)
            engine.updateParameters(params)

            engine.addInput(vertical: 10.0, horizontal: 0.0)

            var totalV = 0.0

            for _ in 0...100 {
                let (v, _) = engine.tick()
                totalV += v
                advanceTime(by: 0.01)
            }

            // All curves should reach the same total
            XCTAssertEqual(totalV, 10.0, accuracy: 0.1, "Curve \(curve) should reach target")
        }
    }

    // MARK: - Edge Cases

    func testZeroInput() {
        engine.addInput(vertical: 0.0, horizontal: 0.0)

        XCTAssertFalse(engine.hasActiveAnimations) // Should not create animation
    }

    func testNegativeInput() {
        engine.addInput(vertical: -10.0, horizontal: 0.0)

        var totalV = 0.0

        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        XCTAssertEqual(totalV, -10.0, accuracy: 0.1) // Should handle negative
    }

    func testVerySmallInput() {
        let params = SmoothScrollParameters(minimumDelta: 0.0001)
        engine.updateParameters(params)

        engine.addInput(vertical: 0.001, horizontal: 0.0)

        var totalV = 0.0

        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        XCTAssertEqual(totalV, 0.001, accuracy: 0.0001)
    }

    func testVeryLargeInput() {
        engine.addInput(vertical: 1000.0, horizontal: 0.0)

        var totalV = 0.0

        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        XCTAssertEqual(totalV, 1000.0, accuracy: 1.0)
    }

    func testRapidInputBurst() {
        // Simulate fast scrolling
        for _ in 0..<10 {
            engine.addInput(vertical: 1.0, horizontal: 0.0)
        }

        XCTAssertEqual(engine.activeAnimationCount, 10)

        var totalV = 0.0

        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        // Should accumulate all inputs
        XCTAssertEqual(totalV, 10.0, accuracy: 0.5)
    }

    // MARK: - Reset

    func testReset() {
        engine.addInput(vertical: 10.0, horizontal: 0.0)

        XCTAssertTrue(engine.hasActiveAnimations)

        engine.reset()

        XCTAssertFalse(engine.hasActiveAnimations)
        XCTAssertEqual(engine.activeAnimationCount, 0)
    }

    func testResetMidAnimation() {
        engine.addInput(vertical: 10.0, horizontal: 0.0)

        // Tick a few times
        for _ in 0..<5 {
            _ = engine.tick()
            advanceTime(by: 0.01)
        }

        engine.reset()

        // Should have no more output
        let (v, h) = engine.tick()
        XCTAssertEqual(v, 0.0)
        XCTAssertEqual(h, 0.0)
    }

    // MARK: - Parameter Updates

    func testGetParameters() {
        let params = engine.getParameters()
        XCTAssertEqual(params, .default)
    }

    func testUpdateParameters() {
        let newParams = SmoothScrollParameters(
            duration: 0.5,
            curve: .easeIn,
            distanceMultiplier: 2.0
        )

        engine.updateParameters(newParams)

        let retrieved = engine.getParameters()
        XCTAssertEqual(retrieved, newParams)
    }

    func testParameterUpdateAffectsNewAnimations() {
        engine.addInput(vertical: 10.0, horizontal: 0.0)

        let newParams = SmoothScrollParameters(distanceMultiplier: 2.0)
        engine.updateParameters(newParams)

        engine.addInput(vertical: 10.0, horizontal: 0.0)

        // Second animation should be affected by new parameters
        var totalV = 0.0

        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        // First: 10, Second: 20
        XCTAssertEqual(totalV, 30.0, accuracy: 0.5)
    }

    // MARK: - Performance

    func testManySimultaneousAnimations() {
        // Add 100 animations
        for _ in 0..<100 {
            engine.addInput(vertical: 1.0, horizontal: 0.0)
        }

        XCTAssertEqual(engine.activeAnimationCount, 100)

        // Should handle many animations
        var totalV = 0.0

        for _ in 0...100 {
            let (v, _) = engine.tick()
            totalV += v
            advanceTime(by: 0.01)
        }

        XCTAssertEqual(totalV, 100.0, accuracy: 2.0)
        XCTAssertFalse(engine.hasActiveAnimations)
    }

    func testZeroDuration() {
        let params = SmoothScrollParameters(duration: 0.0)
        engine.updateParameters(params)

        engine.addInput(vertical: 10.0, horizontal: 0.0)

        // With zero duration, should return all immediately
        let (v, _) = engine.tick()
        XCTAssertEqual(v, 10.0, accuracy: 0.1)

        XCTAssertFalse(engine.hasActiveAnimations)
    }

    func testInterpolationSmoothness() {
        let params = SmoothScrollParameters(duration: 0.3, curve: .linear)
        engine.updateParameters(params)

        engine.addInput(vertical: 10.0, horizontal: 0.0)

        var deltas: [Double] = []

        for _ in 0...30 {
            let (v, _) = engine.tick()
            deltas.append(v)
            advanceTime(by: 0.01)
        }

        // With linear curve, deltas should be relatively consistent
        let nonZeroDeltas = deltas.filter { $0 > 0.0 }
        XCTAssertGreaterThan(nonZeroDeltas.count, 25) // Most frames should have output

        // Check that we're distributing smoothly (no huge spikes)
        let maxDelta = nonZeroDeltas.max() ?? 0.0
        let avgDelta = nonZeroDeltas.reduce(0.0, +) / Double(nonZeroDeltas.count)
        XCTAssertLessThan(maxDelta, avgDelta * 3.0) // Max shouldn't be more than 3x average
    }
}

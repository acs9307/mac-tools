import XCTest
@testable import DisplayLayouts

final class WindowFrameTests: XCTestCase {
    func testInitialization() {
        let frame = WindowFrame(x: 100, y: 200, width: 800, height: 600)

        XCTAssertEqual(frame.x, 100)
        XCTAssertEqual(frame.y, 200)
        XCTAssertEqual(frame.width, 800)
        XCTAssertEqual(frame.height, 600)
    }

    func testFromCGRect() {
        let rect = CGRect(x: 50, y: 100, width: 1920, height: 1080)
        let frame = WindowFrame(rect)

        XCTAssertEqual(frame.x, 50)
        XCTAssertEqual(frame.y, 100)
        XCTAssertEqual(frame.width, 1920)
        XCTAssertEqual(frame.height, 1080)
    }

    func testToCGRect() {
        let frame = WindowFrame(x: 100, y: 200, width: 800, height: 600)
        let rect = frame.cgRect

        XCTAssertEqual(rect.origin.x, 100)
        XCTAssertEqual(rect.origin.y, 200)
        XCTAssertEqual(rect.size.width, 800)
        XCTAssertEqual(rect.size.height, 600)
    }

    func testCenter() {
        let frame = WindowFrame(x: 100, y: 200, width: 800, height: 600)
        let center = frame.center

        XCTAssertEqual(center.x, 500) // 100 + 800/2
        XCTAssertEqual(center.y, 500) // 200 + 600/2
    }

    func testContains() {
        let frame = WindowFrame(x: 100, y: 100, width: 200, height: 200)

        XCTAssertTrue(frame.contains(CGPoint(x: 150, y: 150)))
        XCTAssertTrue(frame.contains(CGPoint(x: 100, y: 100))) // Edge
        XCTAssertTrue(frame.contains(CGPoint(x: 299, y: 299))) // Edge

        XCTAssertFalse(frame.contains(CGPoint(x: 50, y: 150)))
        XCTAssertFalse(frame.contains(CGPoint(x: 350, y: 150)))
    }

    func testEquality() {
        let frame1 = WindowFrame(x: 100, y: 200, width: 800, height: 600)
        let frame2 = WindowFrame(x: 100, y: 200, width: 800, height: 600)

        XCTAssertEqual(frame1, frame2)
    }

    func testCodable() throws {
        let original = WindowFrame(x: 100, y: 200, width: 800, height: 600)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WindowFrame.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

final class ApplicationIdentifierTests: XCTestCase {
    func testInitialization() {
        let app = ApplicationIdentifier(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari"
        )

        XCTAssertEqual(app.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(app.name, "Safari")
    }

    func testEquality() {
        let app1 = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let app2 = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")

        XCTAssertEqual(app1, app2)
    }

    func testHashing() {
        let app1 = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let app2 = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")

        var set = Set<ApplicationIdentifier>()
        set.insert(app1)
        set.insert(app2)

        XCTAssertEqual(set.count, 1)
    }

    func testCodable() throws {
        let original = ApplicationIdentifier(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ApplicationIdentifier.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

final class WindowRoleTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(WindowRole.standard.rawValue, "AXStandardWindow")
        XCTAssertEqual(WindowRole.dialog.rawValue, "AXDialog")
        XCTAssertEqual(WindowRole.sheet.rawValue, "AXSheet")
        XCTAssertEqual(WindowRole.unknown.rawValue, "AXUnknown")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(WindowRole(rawValue: "AXStandardWindow"), .standard)
        XCTAssertEqual(WindowRole(rawValue: "AXDialog"), .dialog)
        XCTAssertEqual(WindowRole(rawValue: "AXInvalidRole"), nil)
    }
}

final class WindowIdentifierTests: XCTestCase {
    func testInitialization() {
        let app = ApplicationIdentifier(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari"
        )

        let window = WindowIdentifier(
            application: app,
            title: "Welcome",
            role: .standard,
            index: 0
        )

        XCTAssertEqual(window.application, app)
        XCTAssertEqual(window.title, "Welcome")
        XCTAssertEqual(window.role, .standard)
        XCTAssertEqual(window.index, 0)
    }

    func testStableIDWithIndex() {
        let app = ApplicationIdentifier(
            bundleIdentifier: "com.test.app",
            name: "Test"
        )

        let window = WindowIdentifier(
            application: app,
            title: "Window",
            role: .standard,
            index: 2
        )

        XCTAssertEqual(window.stableID, "com.test.app|Window|2")
    }

    func testStableIDWithoutIndex() {
        let app = ApplicationIdentifier(
            bundleIdentifier: "com.test.app",
            name: "Test"
        )

        let window = WindowIdentifier(
            application: app,
            title: "Window",
            role: .standard,
            index: nil
        )

        XCTAssertEqual(window.stableID, "com.test.app|Window")
    }

    func testEquality() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")

        let window1 = WindowIdentifier(application: app, title: "Window", role: .standard, index: 0)
        let window2 = WindowIdentifier(application: app, title: "Window", role: .standard, index: 0)

        XCTAssertEqual(window1, window2)
    }

    func testCodable() throws {
        let app = ApplicationIdentifier(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari"
        )

        let original = WindowIdentifier(
            application: app,
            title: "Welcome",
            role: .standard,
            index: 0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WindowIdentifier.self, from: data)

        XCTAssertEqual(decoded.application, original.application)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.index, original.index)
    }
}

final class WindowInfoTests: XCTestCase {
    func testInitialization() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let frame = WindowFrame(x: 0, y: 0, width: 800, height: 600)

        let info = WindowInfo(
            identifier: windowID,
            frame: frame,
            processID: 12345,
            isMinimized: false,
            isHidden: false
        )

        XCTAssertEqual(info.identifier, windowID)
        XCTAssertEqual(info.frame, frame)
        XCTAssertEqual(info.processID, 12345)
        XCTAssertFalse(info.isMinimized)
        XCTAssertFalse(info.isHidden)
    }

    func testEquality() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let frame = WindowFrame(x: 0, y: 0, width: 800, height: 600)

        let info1 = WindowInfo(identifier: windowID, frame: frame, processID: 12345)
        let info2 = WindowInfo(identifier: windowID, frame: frame, processID: 12345)

        XCTAssertEqual(info1, info2)
    }
}

final class WindowLayoutSpecTests: XCTestCase {
    func testInitialization() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let frame = WindowFrame(x: 100, y: 100, width: 800, height: 600)

        let spec = WindowLayoutSpec(
            windowID: windowID,
            targetFrame: frame,
            displayID: "display-1",
            restoreIfMinimized: true,
            unhideIfHidden: true
        )

        XCTAssertEqual(spec.windowID, windowID)
        XCTAssertEqual(spec.targetFrame, frame)
        XCTAssertEqual(spec.displayID, "display-1")
        XCTAssertTrue(spec.restoreIfMinimized)
        XCTAssertTrue(spec.unhideIfHidden)
    }

    func testCodable() throws {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let frame = WindowFrame(x: 100, y: 100, width: 800, height: 600)

        let original = WindowLayoutSpec(
            windowID: windowID,
            targetFrame: frame,
            displayID: "display-1"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WindowLayoutSpec.self, from: data)

        XCTAssertEqual(decoded.windowID, original.windowID)
        XCTAssertEqual(decoded.targetFrame, original.targetFrame)
        XCTAssertEqual(decoded.displayID, original.displayID)
    }
}

final class WindowLayoutPresetTests: XCTestCase {
    func testInitialization() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let frame = WindowFrame(x: 0, y: 0, width: 800, height: 600)
        let spec = WindowLayoutSpec(windowID: windowID, targetFrame: frame)

        let preset = WindowLayoutPreset(
            name: "Test Preset",
            displayConfigSignature: "sig-123",
            layouts: [spec]
        )

        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.displayConfigSignature, "sig-123")
        XCTAssertEqual(preset.windowCount, 1)
    }

    func testLayoutLookup() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID1 = WindowIdentifier(application: app, title: "Window 1")
        let windowID2 = WindowIdentifier(application: app, title: "Window 2")

        let frame = WindowFrame(x: 0, y: 0, width: 800, height: 600)
        let spec1 = WindowLayoutSpec(windowID: windowID1, targetFrame: frame)
        let spec2 = WindowLayoutSpec(windowID: windowID2, targetFrame: frame)

        let preset = WindowLayoutPreset(
            name: "Test",
            displayConfigSignature: "sig",
            layouts: [spec1, spec2]
        )

        XCTAssertNotNil(preset.layout(for: windowID1))
        XCTAssertNotNil(preset.layout(for: windowID2))
        XCTAssertNil(preset.layout(for: WindowIdentifier(application: app, title: "Unknown")))
    }

    func testCodable() throws {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let frame = WindowFrame(x: 0, y: 0, width: 800, height: 600)
        let spec = WindowLayoutSpec(windowID: windowID, targetFrame: frame)

        let original = WindowLayoutPreset(
            name: "Test Preset",
            displayConfigSignature: "sig-123",
            layouts: [spec]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WindowLayoutPreset.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.displayConfigSignature, original.displayConfigSignature)
        XCTAssertEqual(decoded.windowCount, original.windowCount)
    }
}

final class WindowLayoutResultTests: XCTestCase {
    func testSuccess() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let oldFrame = WindowFrame(x: 0, y: 0, width: 800, height: 600)
        let newFrame = WindowFrame(x: 100, y: 100, width: 900, height: 700)

        let result = WindowLayoutResult(
            windowID: windowID,
            success: true,
            error: nil,
            previousFrame: oldFrame,
            newFrame: newFrame
        )

        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.previousFrame, oldFrame)
        XCTAssertEqual(result.newFrame, newFrame)
    }

    func testFailure() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")

        let result = WindowLayoutResult(
            windowID: windowID,
            success: false,
            error: WindowError.windowNotFound(windowID)
        )

        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }
}

final class WindowLayoutBatchResultTests: XCTestCase {
    func testAllSucceeded() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID1 = WindowIdentifier(application: app, title: "Window 1")
        let windowID2 = WindowIdentifier(application: app, title: "Window 2")

        let result1 = WindowLayoutResult(windowID: windowID1, success: true)
        let result2 = WindowLayoutResult(windowID: windowID2, success: true)

        let batch = WindowLayoutBatchResult(results: [result1, result2])

        XCTAssertEqual(batch.successCount, 2)
        XCTAssertEqual(batch.failureCount, 0)
        XCTAssertTrue(batch.allSucceeded)
        XCTAssertTrue(batch.failures.isEmpty)
    }

    func testPartialFailure() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID1 = WindowIdentifier(application: app, title: "Window 1")
        let windowID2 = WindowIdentifier(application: app, title: "Window 2")

        let result1 = WindowLayoutResult(windowID: windowID1, success: true)
        let result2 = WindowLayoutResult(
            windowID: windowID2,
            success: false,
            error: WindowError.windowNotFound(windowID2)
        )

        let batch = WindowLayoutBatchResult(results: [result1, result2])

        XCTAssertEqual(batch.successCount, 1)
        XCTAssertEqual(batch.failureCount, 1)
        XCTAssertFalse(batch.allSucceeded)
        XCTAssertEqual(batch.failures.count, 1)
    }
}

final class WindowLayoutPresetManagerTests: XCTestCase {
    var manager: WindowLayoutPresetManager!

    override func setUp() {
        super.setUp()
        manager = WindowLayoutPresetManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testStoreAndRetrieve() {
        let preset = makePreset(name: "Test", signature: "sig-1")

        manager.store(preset)

        let retrieved = manager.preset(named: "Test", for: "sig-1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Test")
    }

    func testPresetsForSignature() {
        let preset1 = makePreset(name: "Preset 1", signature: "sig-1")
        let preset2 = makePreset(name: "Preset 2", signature: "sig-1")
        let preset3 = makePreset(name: "Preset 3", signature: "sig-2")

        manager.store(preset1)
        manager.store(preset2)
        manager.store(preset3)

        let presetsForSig1 = manager.presets(for: "sig-1")
        XCTAssertEqual(presetsForSig1.count, 2)

        let presetsForSig2 = manager.presets(for: "sig-2")
        XCTAssertEqual(presetsForSig2.count, 1)
    }

    func testReplaceExistingPreset() {
        let preset1 = makePreset(name: "Test", signature: "sig-1", windowCount: 1)
        manager.store(preset1)

        let preset2 = makePreset(name: "Test", signature: "sig-1", windowCount: 2)
        manager.store(preset2)

        let retrieved = manager.preset(named: "Test", for: "sig-1")
        XCTAssertEqual(retrieved?.windowCount, 2)

        let allForSig = manager.presets(for: "sig-1")
        XCTAssertEqual(allForSig.count, 1) // Should only have one
    }

    func testRemove() {
        let preset = makePreset(name: "Test", signature: "sig-1")
        manager.store(preset)

        XCTAssertNotNil(manager.preset(named: "Test", for: "sig-1"))

        manager.remove(presetNamed: "Test", for: "sig-1")

        XCTAssertNil(manager.preset(named: "Test", for: "sig-1"))
    }

    func testRemoveAll() {
        manager.store(makePreset(name: "Preset 1", signature: "sig-1"))
        manager.store(makePreset(name: "Preset 2", signature: "sig-1"))
        manager.store(makePreset(name: "Preset 3", signature: "sig-2"))

        XCTAssertEqual(manager.presets(for: "sig-1").count, 2)

        manager.removeAll(for: "sig-1")

        XCTAssertEqual(manager.presets(for: "sig-1").count, 0)
        XCTAssertEqual(manager.presets(for: "sig-2").count, 1)
    }

    func testTotalCount() {
        manager.store(makePreset(name: "Preset 1", signature: "sig-1"))
        manager.store(makePreset(name: "Preset 2", signature: "sig-1"))
        manager.store(makePreset(name: "Preset 3", signature: "sig-2"))

        XCTAssertEqual(manager.totalCount, 3)
    }

    func testThreadSafety() {
        let expectation = self.expectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 20

        for i in 0..<10 {
            DispatchQueue.global().async {
                let preset = self.makePreset(name: "Preset \(i)", signature: "sig-\(i)")
                self.manager.store(preset)
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = self.manager.allPresets()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(manager.totalCount, 10)
    }

    // MARK: - Helpers

    private func makePreset(
        name: String,
        signature: String,
        windowCount: Int = 1
    ) -> WindowLayoutPreset {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let frame = WindowFrame(x: 0, y: 0, width: 800, height: 600)

        var layouts: [WindowLayoutSpec] = []
        for i in 0..<windowCount {
            let windowID = WindowIdentifier(application: app, title: "Window \(i)")
            let spec = WindowLayoutSpec(windowID: windowID, targetFrame: frame)
            layouts.append(spec)
        }

        return WindowLayoutPreset(
            name: name,
            displayConfigSignature: signature,
            layouts: layouts
        )
    }
}

import XCTest
@testable import MacToolsCore

final class PermissionsManagerTests: XCTestCase {
    var manager: PermissionsManager!

    override func setUp() {
        manager = PermissionsManager.shared
    }

    func testCheckAccessibilityPermissions() {
        // We can't control the actual permissions in tests, but we can verify the method doesn't crash
        let hasPermissions = manager.checkAccessibilityPermissions()

        // The return value will depend on the test environment
        // Just verify it returns a boolean without crashing
        XCTAssertTrue(hasPermissions is Bool)
    }

    func testRequestAccessibilityPermissions() {
        // We can't control the actual permissions in tests, but we can verify the method doesn't crash
        let hasPermissions = manager.requestAccessibilityPermissions()

        // The return value will depend on the test environment
        // Just verify it returns a boolean without crashing
        XCTAssertTrue(hasPermissions is Bool)
    }

    func testVerifyAllPermissions() {
        let permissions = manager.verifyAllPermissions()

        // Should at least contain accessibility
        XCTAssertTrue(permissions.keys.contains("accessibility"))

        // Verify all values are booleans
        for (_, value) in permissions {
            XCTAssertTrue(value is Bool)
        }
    }

    func testPrintPermissionStatusDoesNotCrash() {
        // This method prints to console, we just verify it doesn't crash
        manager.printPermissionStatus()
    }
}

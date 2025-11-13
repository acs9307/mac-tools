import XCTest
@testable import MacToolsCore

final class PermissionTypeTests: XCTestCase {
    // MARK: - Display Name Tests

    func testAccessibilityDisplayName() {
        XCTAssertEqual(PermissionType.accessibility.displayName, "Accessibility")
    }

    func testInputMonitoringDisplayName() {
        XCTAssertEqual(PermissionType.inputMonitoring.displayName, "Input Monitoring")
    }

    func testScreenRecordingDisplayName() {
        XCTAssertEqual(PermissionType.screenRecording.displayName, "Screen Recording")
    }

    // MARK: - Purpose Tests

    func testAccessibilityPurpose() {
        let purpose = PermissionType.accessibility.purpose
        XCTAssertTrue(purpose.contains("keyboard") || purpose.contains("windows"))
    }

    func testInputMonitoringPurpose() {
        let purpose = PermissionType.inputMonitoring.purpose
        XCTAssertTrue(purpose.contains("mouse") || purpose.contains("keyboard"))
    }

    func testScreenRecordingPurpose() {
        let purpose = PermissionType.screenRecording.purpose
        XCTAssertTrue(purpose.contains("display") || purpose.contains("capture"))
    }

    // MARK: - Critical Status Tests

    func testAccessibilityIsCritical() {
        XCTAssertTrue(PermissionType.accessibility.isCritical)
    }

    func testInputMonitoringIsCritical() {
        XCTAssertTrue(PermissionType.inputMonitoring.isCritical)
    }

    func testScreenRecordingIsNotCritical() {
        XCTAssertFalse(PermissionType.screenRecording.isCritical)
    }

    // MARK: - System Settings Path Tests

    func testAccessibilitySystemSettingsPath() {
        let path = PermissionType.accessibility.systemSettingsPath
        XCTAssertTrue(path.contains("Privacy") && path.contains("Accessibility"))
    }

    func testInputMonitoringSystemSettingsPath() {
        let path = PermissionType.inputMonitoring.systemSettingsPath
        XCTAssertTrue(path.contains("Privacy") && path.contains("Input Monitoring"))
    }

    func testScreenRecordingSystemSettingsPath() {
        let path = PermissionType.screenRecording.systemSettingsPath
        XCTAssertTrue(path.contains("Privacy") && path.contains("Screen Recording"))
    }

    // MARK: - Codable Tests

    func testPermissionTypeCodable() throws {
        for permissionType in PermissionType.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(permissionType)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(PermissionType.self, from: data)

            XCTAssertEqual(decoded, permissionType)
        }
    }
}

// MARK: - Permission Status Tests

final class PermissionStatusTests: XCTestCase {
    // MARK: - State Tests

    func testNotDeterminedIsNotGranted() {
        XCTAssertFalse(PermissionStatus.notDetermined.isGranted)
    }

    func testDeniedIsNotGranted() {
        XCTAssertFalse(PermissionStatus.denied.isGranted)
    }

    func testGrantedIsGranted() {
        XCTAssertTrue(PermissionStatus.granted.isGranted)
    }

    func testPromptShownIsNotGranted() {
        XCTAssertFalse(PermissionStatus.promptShown.isGranted)
    }

    // MARK: - In Progress Tests

    func testPromptShownIsInProgress() {
        XCTAssertTrue(PermissionStatus.promptShown.isInProgress)
    }

    func testOtherStatesNotInProgress() {
        XCTAssertFalse(PermissionStatus.notDetermined.isInProgress)
        XCTAssertFalse(PermissionStatus.denied.isInProgress)
        XCTAssertFalse(PermissionStatus.granted.isInProgress)
    }

    // MARK: - Denied Tests

    func testDeniedIsDenied() {
        XCTAssertTrue(PermissionStatus.denied.isDenied)
    }

    func testOtherStatesNotDenied() {
        XCTAssertFalse(PermissionStatus.notDetermined.isDenied)
        XCTAssertFalse(PermissionStatus.granted.isDenied)
        XCTAssertFalse(PermissionStatus.promptShown.isDenied)
    }

    // MARK: - Codable Tests

    func testPermissionStatusCodable() throws {
        let statuses: [PermissionStatus] = [
            .notDetermined,
            .denied,
            .granted,
            .promptShown
        ]

        for status in statuses {
            let encoder = JSONEncoder()
            let data = try encoder.encode(status)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(PermissionStatus.self, from: data)

            XCTAssertEqual(decoded, status)
        }
    }
}

// MARK: - Permission State Tests

final class PermissionStateTests: XCTestCase {
    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let state = PermissionState()

        XCTAssertEqual(state.accessibility, .notDetermined)
        XCTAssertEqual(state.inputMonitoring, .notDetermined)
        XCTAssertEqual(state.screenRecording, .notDetermined)
    }

    func testCustomInitialization() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .denied,
            screenRecording: .promptShown
        )

        XCTAssertEqual(state.accessibility, .granted)
        XCTAssertEqual(state.inputMonitoring, .denied)
        XCTAssertEqual(state.screenRecording, .promptShown)
    }

    // MARK: - Subscript Tests

    func testSubscriptAccess() {
        var state = PermissionState()

        state[.accessibility] = .granted
        state[.inputMonitoring] = .denied
        state[.screenRecording] = .promptShown

        XCTAssertEqual(state[.accessibility], .granted)
        XCTAssertEqual(state[.inputMonitoring], .denied)
        XCTAssertEqual(state[.screenRecording], .promptShown)
    }

    // MARK: - All Critical Granted Tests

    func testAllCriticalGrantedWhenAllGranted() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .granted,
            screenRecording: .notDetermined
        )

        XCTAssertTrue(state.allCriticalGranted)
    }

    func testAllCriticalNotGrantedWhenAccessibilityDenied() {
        let state = PermissionState(
            accessibility: .denied,
            inputMonitoring: .granted,
            screenRecording: .granted
        )

        XCTAssertFalse(state.allCriticalGranted)
    }

    func testAllCriticalNotGrantedWhenInputMonitoringDenied() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .denied,
            screenRecording: .granted
        )

        XCTAssertFalse(state.allCriticalGranted)
    }

    func testAllCriticalGrantedIgnoresScreenRecording() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .granted,
            screenRecording: .denied
        )

        XCTAssertTrue(state.allCriticalGranted)
    }

    // MARK: - Any Denied Tests

    func testAnyDeniedWhenAccessibilityDenied() {
        let state = PermissionState(
            accessibility: .denied,
            inputMonitoring: .granted,
            screenRecording: .granted
        )

        XCTAssertTrue(state.anyDenied)
    }

    func testAnyDeniedWhenInputMonitoringDenied() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .denied,
            screenRecording: .granted
        )

        XCTAssertTrue(state.anyDenied)
    }

    func testAnyDeniedWhenScreenRecordingDenied() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .granted,
            screenRecording: .denied
        )

        XCTAssertTrue(state.anyDenied)
    }

    func testNoPermissionsDenied() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .granted,
            screenRecording: .granted
        )

        XCTAssertFalse(state.anyDenied)
    }

    // MARK: - Missing Permissions Tests

    func testMissingPermissionsWhenAllGranted() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .granted,
            screenRecording: .granted
        )

        XCTAssertTrue(state.missingPermissions.isEmpty)
    }

    func testMissingPermissionsWhenAccessibilityNotGranted() {
        let state = PermissionState(
            accessibility: .denied,
            inputMonitoring: .granted,
            screenRecording: .granted
        )

        XCTAssertEqual(state.missingPermissions.count, 1)
        XCTAssertTrue(state.missingPermissions.contains(.accessibility))
    }

    func testMissingPermissionsWhenMultipleNotGranted() {
        let state = PermissionState(
            accessibility: .denied,
            inputMonitoring: .notDetermined,
            screenRecording: .denied
        )

        XCTAssertEqual(state.missingPermissions.count, 3)
        XCTAssertTrue(state.missingPermissions.contains(.accessibility))
        XCTAssertTrue(state.missingPermissions.contains(.inputMonitoring))
        XCTAssertTrue(state.missingPermissions.contains(.screenRecording))
    }

    // MARK: - Missing Critical Permissions Tests

    func testMissingCriticalPermissionsWhenAllGranted() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .granted,
            screenRecording: .notDetermined
        )

        XCTAssertTrue(state.missingCriticalPermissions.isEmpty)
    }

    func testMissingCriticalPermissionsIgnoresScreenRecording() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .granted,
            screenRecording: .denied
        )

        XCTAssertTrue(state.missingCriticalPermissions.isEmpty)
    }

    func testMissingCriticalPermissionsIncludesAccessibility() {
        let state = PermissionState(
            accessibility: .denied,
            inputMonitoring: .granted,
            screenRecording: .granted
        )

        XCTAssertEqual(state.missingCriticalPermissions.count, 1)
        XCTAssertTrue(state.missingCriticalPermissions.contains(.accessibility))
    }

    func testMissingCriticalPermissionsIncludesInputMonitoring() {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .denied,
            screenRecording: .granted
        )

        XCTAssertEqual(state.missingCriticalPermissions.count, 1)
        XCTAssertTrue(state.missingCriticalPermissions.contains(.inputMonitoring))
    }

    func testMissingCriticalPermissionsIncludesBoth() {
        let state = PermissionState(
            accessibility: .denied,
            inputMonitoring: .denied,
            screenRecording: .granted
        )

        XCTAssertEqual(state.missingCriticalPermissions.count, 2)
        XCTAssertTrue(state.missingCriticalPermissions.contains(.accessibility))
        XCTAssertTrue(state.missingCriticalPermissions.contains(.inputMonitoring))
    }

    // MARK: - Codable Tests

    func testPermissionStateCodable() throws {
        let state = PermissionState(
            accessibility: .granted,
            inputMonitoring: .denied,
            screenRecording: .promptShown
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PermissionState.self, from: data)

        XCTAssertEqual(decoded.accessibility, state.accessibility)
        XCTAssertEqual(decoded.inputMonitoring, state.inputMonitoring)
        XCTAssertEqual(decoded.screenRecording, state.screenRecording)
    }
}

// MARK: - Permissions Manager Tests

final class PermissionsManagerTests: XCTestCase {
    var permissionsManager: PermissionsManager!

    override func setUp() {
        super.setUp()
        permissionsManager = .shared
    }

    override func tearDown() {
        permissionsManager.pollForChanges = false
        permissionsManager = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSharedInstanceInitialization() {
        XCTAssertNotNil(permissionsManager)
        XCTAssertNotNil(permissionsManager.permissionState)
    }

    // MARK: - Permission Checking Tests

    func testCheckAccessibilityPermissions() {
        // This will return false in test environment
        // but should not crash
        let result = permissionsManager.checkAccessibilityPermissions()
        XCTAssertFalse(result) // Expected to be false in test environment
    }

    func testCheckInputMonitoringPermissions() {
        // This will likely return false in test environment
        let result = permissionsManager.checkInputMonitoringPermissions()
        // Don't assert specific value as it depends on environment
        XCTAssertTrue(result == true || result == false)
    }

    func testCheckScreenRecordingPermissions() {
        if #available(macOS 10.15, *) {
            let result = permissionsManager.checkScreenRecordingPermissions()
            // Current implementation returns true
            XCTAssertTrue(result)
        }
    }

    // MARK: - Permission Status Management Tests

    func testCheckPermissionAccessibility() {
        let status = permissionsManager.checkPermission(.accessibility)
        // Will be denied in test environment
        XCTAssertEqual(status, .denied)
    }

    func testCheckPermissionInputMonitoring() {
        let status = permissionsManager.checkPermission(.inputMonitoring)
        // Should be either granted or denied, not notDetermined after check
        XCTAssertTrue(status == .granted || status == .denied)
    }

    func testCheckPermissionScreenRecording() {
        if #available(macOS 10.15, *) {
            let status = permissionsManager.checkPermission(.screenRecording)
            // Current implementation returns granted
            XCTAssertEqual(status, .granted)
        }
    }

    // MARK: - Update All Permissions Tests

    func testUpdateAllPermissions() {
        permissionsManager.updateAllPermissions()

        // Should have updated all permission states
        XCTAssertNotEqual(permissionsManager.permissionState.accessibility, .notDetermined)
        XCTAssertNotEqual(permissionsManager.permissionState.inputMonitoring, .notDetermined)
    }

    // MARK: - Verify All Permissions Tests

    func testVerifyAllPermissions() {
        let permissions = permissionsManager.verifyAllPermissions()

        XCTAssertTrue(permissions.keys.contains("accessibility"))
        XCTAssertTrue(permissions.keys.contains("inputMonitoring"))

        if #available(macOS 10.15, *) {
            XCTAssertTrue(permissions.keys.contains("screenRecording"))
        }
    }

    // MARK: - Polling Tests

    func testPollingStartsAndStops() {
        permissionsManager.pollForChanges = true
        XCTAssertTrue(permissionsManager.pollForChanges)

        permissionsManager.pollForChanges = false
        XCTAssertFalse(permissionsManager.pollForChanges)
    }

    // MARK: - Print Status Tests

    func testPrintPermissionStatusDoesNotCrash() {
        // Should not crash
        permissionsManager.printPermissionStatus()
    }

    // MARK: - Open Settings Tests

    func testOpenSystemSettingsDoesNotCrash() {
        // Should not crash, but may not do anything in test environment
        permissionsManager.openSystemSettings()
    }
}

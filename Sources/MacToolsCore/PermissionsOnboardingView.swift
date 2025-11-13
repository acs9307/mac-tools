import SwiftUI

/// Onboarding view for requesting permissions
public struct PermissionsOnboardingView: View {
    @ObservedObject private var permissionsManager: PermissionsManager
    @State private var currentStep: Int = 0

    private let requiredPermissions: [PermissionType]
    private let onComplete: () -> Void

    public init(
        permissionsManager: PermissionsManager = .shared,
        requiredPermissions: [PermissionType] = PermissionType.allCases.filter { $0.isCritical },
        onComplete: @escaping () -> Void = {}
    ) {
        self.permissionsManager = permissionsManager
        self.requiredPermissions = requiredPermissions
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Content
            if permissionsManager.permissionState.allCriticalGranted {
                completionView
            } else {
                onboardingSteps
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            permissionsManager.pollForChanges = true
        }
        .onDisappear {
            permissionsManager.pollForChanges = false
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("MacTools Setup")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Grant required permissions to enable all features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            progressIndicator
        }
    }

    private var progressIndicator: some View {
        let granted = permissionsManager.permissionState.missingCriticalPermissions.count
        let total = requiredPermissions.filter { $0.isCritical }.count
        let grantedCount = total - granted

        return HStack(spacing: 8) {
            Circle()
                .fill(grantedCount == total ? Color.green : Color.orange)
                .frame(width: 12, height: 12)

            Text("\(grantedCount)/\(total) granted")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
    }

    private var onboardingSteps: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(requiredPermissions, id: \.self) { permission in
                    PermissionStepView(
                        permission: permission,
                        status: permissionsManager.permissionState[permission],
                        onRequest: {
                            permissionsManager.requestPermission(permission)
                        },
                        onOpenSettings: {
                            permissionsManager.openSystemSettings()
                        }
                    )
                }

                if !permissionsManager.permissionState.allCriticalGranted {
                    instructionsView
                }
            }
            .padding()
        }
    }

    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("After Granting Permissions:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(
                    number: 1,
                    text: "Click the button above to open System Settings"
                )

                InstructionRow(
                    number: 2,
                    text: "Find MacTools in the list and enable it"
                )

                InstructionRow(
                    number: 3,
                    text: "Return to this window - permissions will update automatically"
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            Text("All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("MacTools has all the permissions it needs")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Continue") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Permission Step View

struct PermissionStepView: View {
    let permission: PermissionType
    let status: PermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                statusIcon
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(permission.displayName)
                        .font(.headline)

                    Text(permission.purpose)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                actionButton
            }

            if status.isDenied || status == .promptShown {
                instructionBox
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 2)
        )
    }

    private var statusIcon: some View {
        Group {
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .promptShown:
                Image(systemName: "hourglass.circle.fill")
                    .foregroundColor(.orange)
            case .notDetermined:
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
    }

    private var actionButton: some View {
        Group {
            if status.isGranted {
                Text("Granted")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            } else if status == .promptShown {
                Button("Open System Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Grant Permission") {
                    onRequest()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var instructionBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)

                Text("How to grant this permission:")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Text("1. Click 'Open System Settings' above")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("2. Navigate to \(permission.systemSettingsPath)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("3. Enable MacTools in the list")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("4. Return to this window")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private var backgroundColor: Color {
        switch status {
        case .granted:
            return Color.green.opacity(0.1)
        case .denied, .promptShown:
            return Color.orange.opacity(0.1)
        case .notDetermined:
            return Color(NSColor.controlBackgroundColor)
        }
    }

    private var borderColor: Color {
        switch status {
        case .granted:
            return Color.green.opacity(0.3)
        case .denied, .promptShown:
            return Color.orange.opacity(0.3)
        case .notDetermined:
            return Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct PermissionsOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsOnboardingView()
    }
}

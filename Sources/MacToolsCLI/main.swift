import Foundation
import ArgumentParser
import MacToolsCore
import KeyManipulation
import WindowManipulation

@main
struct MacTools: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mactools",
        abstract: "A suite of macOS system tools for key and window manipulation",
        version: "0.1.0",
        subcommands: [
            Daemon.self,
            Permissions.self,
            Config.self,
            Window.self,
            Key.self
        ]
    )
}

// MARK: - Daemon Command

struct Daemon: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage the MacTools daemon"
    )

    @Flag(name: .shortAndLong, help: "Run in foreground (don't daemonize)")
    var foreground = false

    func run() async throws {
        let manager = DaemonManager.shared

        // Register agents
        let keyAgent = KeyManipulationAgent()
        let windowAgent = WindowManipulationAgent()

        try manager.register(keyAgent)
        try manager.register(windowAgent)

        if foreground {
            print("Starting MacTools daemon in foreground...")
            try await manager.run()
        } else {
            print("Starting MacTools daemon...")
            try await manager.startAll()
            print("Daemon started successfully")
            print("Agents running: \(manager.status().filter { $0.value }.count)")
        }
    }
}

// MARK: - Permissions Command

struct Permissions: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check and request system permissions"
    )

    @Flag(name: .shortAndLong, help: "Request permissions if not granted")
    var request = false

    func run() throws {
        let manager = PermissionsManager.shared

        if request {
            print("Requesting accessibility permissions...")
            let granted = manager.requestAccessibilityPermissions()

            if granted {
                print("✓ Accessibility permissions granted")
            } else {
                print("⚠️  Please grant accessibility permissions in System Settings")
                print("   Go to: System Settings > Privacy & Security > Accessibility")
            }
        } else {
            manager.printPermissionStatus()
        }
    }
}

// MARK: - Config Command

struct Config: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage configuration",
        subcommands: [Show.self, Reset.self, Set.self, Get.self]
    )

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show current configuration"
        )

        func run() throws {
            let config = Configuration.shared
            let data = try JSONSerialization.data(
                withJSONObject: config.all(),
                options: [.prettyPrinted, .sortedKeys]
            )

            if let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        }
    }

    struct Reset: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reset configuration to defaults"
        )

        func run() throws {
            Configuration.shared.reset()
            print("Configuration reset to defaults")
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set a configuration value"
        )

        @Argument(help: "Configuration key")
        var key: String

        @Argument(help: "Configuration value")
        var value: String

        func run() throws {
            Configuration.shared.set(key, value: value)
            print("Set \(key) = \(value)")
        }
    }

    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get a configuration value"
        )

        @Argument(help: "Configuration key")
        var key: String

        func run() throws {
            if let value = Configuration.shared.get(key) {
                print("\(key) = \(value)")
            } else {
                print("Key '\(key)' not found")
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Window Command

struct Window: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Window manipulation commands",
        subcommands: [List.self, Focus.self, Maximize.self, Center.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all windows"
        )

        @Option(name: .shortAndLong, help: "Filter by application bundle identifier")
        var app: String?

        func run() async throws {
            let agent = WindowManipulationAgent()
            try await agent.start()
            defer {
                Task {
                    try? await agent.stop()
                }
            }

            let windows: [WindowManipulation.Window]
            if let bundleId = app {
                windows = try agent.getWindows(forApplication: bundleId)
            } else {
                windows = try agent.getAllWindows()
            }

            print("Found \(windows.count) window(s):")
            for window in windows {
                let title = window.title ?? "<untitled>"
                let appName = window.application.name ?? "Unknown"
                let frame = window.frame.map { "(\($0.origin.x), \($0.origin.y)) \($0.size.width)×\($0.size.height)" } ?? "unknown"
                print("  [\(window.id)] \(appName): \(title) - \(frame)")
            }
        }
    }

    struct Focus: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Focus the current window"
        )

        func run() async throws {
            let agent = WindowManipulationAgent()
            try await agent.start()
            defer {
                Task {
                    try? await agent.stop()
                }
            }

            if let window = try agent.getFocusedWindow() {
                print("Focused window: \(window.title ?? "<untitled>")")
            } else {
                print("No focused window")
            }
        }
    }

    struct Maximize: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Maximize the focused window"
        )

        func run() async throws {
            let agent = WindowManipulationAgent()
            try await agent.start()
            defer {
                Task {
                    try? await agent.stop()
                }
            }

            guard let window = try agent.getFocusedWindow() else {
                print("No focused window")
                throw ExitCode.failure
            }

            try agent.maximizeWindow(window)
            print("Maximized window: \(window.title ?? "<untitled>")")
        }
    }

    struct Center: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Center the focused window"
        )

        func run() async throws {
            let agent = WindowManipulationAgent()
            try await agent.start()
            defer {
                Task {
                    try? await agent.stop()
                }
            }

            guard let window = try agent.getFocusedWindow() else {
                print("No focused window")
                throw ExitCode.failure
            }

            try agent.centerWindow(window)
            print("Centered window: \(window.title ?? "<untitled>")")
        }
    }
}

// MARK: - Key Command

struct Key: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Key manipulation commands",
        subcommands: [Type.self]
    )

    struct Type: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Type text using key simulation"
        )

        @Argument(help: "Text to type")
        var text: String

        func run() async throws {
            let agent = KeyManipulationAgent()
            try await agent.start()
            defer {
                Task {
                    try? await agent.stop()
                }
            }

            // Add a small delay to allow user to focus the target window
            print("Typing in 2 seconds...")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            try agent.typeText(text)
            print("Typed: \(text)")
        }
    }
}

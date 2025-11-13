import Foundation
import Logging

/// Protocol that all agent modules must implement
public protocol Agent: AnyObject {
    /// Unique identifier for the agent
    var identifier: String { get }

    /// Human-readable name for the agent
    var name: String { get }

    /// Whether the agent is currently running
    var isRunning: Bool { get }

    /// Logger instance for the agent
    var logger: Logger { get }

    /// Start the agent
    /// - Throws: AgentError if the agent fails to start
    func start() async throws

    /// Stop the agent
    /// - Throws: AgentError if the agent fails to stop
    func stop() async throws

    /// Handle configuration changes
    /// - Parameter config: New configuration dictionary
    func configure(_ config: [String: Any]) async throws
}

/// Errors that can occur during agent operations
public enum AgentError: Error, CustomStringConvertible {
    case alreadyRunning(String)
    case notRunning(String)
    case startupFailed(String, Error?)
    case shutdownFailed(String, Error?)
    case configurationError(String)
    case permissionDenied(String)
    case unsupported(String)

    public var description: String {
        switch self {
        case .alreadyRunning(let agent):
            return "Agent '\(agent)' is already running"
        case .notRunning(let agent):
            return "Agent '\(agent)' is not running"
        case .startupFailed(let agent, let error):
            return "Failed to start agent '\(agent)': \(error?.localizedDescription ?? "unknown error")"
        case .shutdownFailed(let agent, let error):
            return "Failed to stop agent '\(agent)': \(error?.localizedDescription ?? "unknown error")"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .unsupported(let message):
            return "Unsupported operation: \(message)"
        }
    }
}

/// Base class for agent implementations
open class BaseAgent: Agent {
    public let identifier: String
    public let name: String
    public private(set) var isRunning: Bool = false
    public let logger: Logger

    private let startStopQueue = DispatchQueue(label: "com.mactools.agent.startstop", qos: .userInitiated)

    public init(identifier: String, name: String) {
        self.identifier = identifier
        self.name = name
        self.logger = Logger(label: "com.mactools.\(identifier)")
    }

    open func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startStopQueue.async {
                guard !self.isRunning else {
                    continuation.resume(throwing: AgentError.alreadyRunning(self.identifier))
                    return
                }

                do {
                    try self.performStart()
                    self.isRunning = true
                    self.logger.info("Agent '\(self.name)' started")
                    continuation.resume()
                } catch {
                    self.logger.error("Failed to start agent '\(self.name)': \(error)")
                    continuation.resume(throwing: AgentError.startupFailed(self.identifier, error))
                }
            }
        }
    }

    open func stop() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startStopQueue.async {
                guard self.isRunning else {
                    continuation.resume(throwing: AgentError.notRunning(self.identifier))
                    return
                }

                do {
                    try self.performStop()
                    self.isRunning = false
                    self.logger.info("Agent '\(self.name)' stopped")
                    continuation.resume()
                } catch {
                    self.logger.error("Failed to stop agent '\(self.name)': \(error)")
                    continuation.resume(throwing: AgentError.shutdownFailed(self.identifier, error))
                }
            }
        }
    }

    open func configure(_ config: [String: Any]) async throws {
        logger.info("Configuring agent '\(name)'")
    }

    /// Override this method to implement agent-specific startup logic
    /// - Throws: Error if startup fails
    open func performStart() throws {
        // Default implementation does nothing
    }

    /// Override this method to implement agent-specific shutdown logic
    /// - Throws: Error if shutdown fails
    open func performStop() throws {
        // Default implementation does nothing
    }
}

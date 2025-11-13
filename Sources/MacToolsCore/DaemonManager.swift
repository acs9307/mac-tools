import Foundation
import Logging

/// Manages the lifecycle of all agents in the daemon
public final class DaemonManager {
    public static let shared = DaemonManager()

    private var agents: [String: Agent] = [:]
    private let logger = Logger(label: "com.mactools.daemon")
    private let agentQueue = DispatchQueue(label: "com.mactools.daemon.agents", attributes: .concurrent)
    private var isShuttingDown = false

    private init() {
        setupSignalHandlers()
    }

    /// Register an agent with the daemon manager
    /// - Parameter agent: The agent to register
    /// - Throws: AgentError if an agent with the same identifier is already registered
    public func register(_ agent: Agent) throws {
        try agentQueue.sync(flags: .barrier) {
            guard agents[agent.identifier] == nil else {
                throw AgentError.configurationError("Agent '\(agent.identifier)' is already registered")
            }
            agents[agent.identifier] = agent
            logger.info("Registered agent '\(agent.name)' (\(agent.identifier))")
        }
    }

    /// Unregister an agent from the daemon manager
    /// - Parameter identifier: The identifier of the agent to unregister
    public func unregister(_ identifier: String) async throws {
        let agent = agentQueue.sync { agents[identifier] }

        if let agent = agent, agent.isRunning {
            try await agent.stop()
        }

        agentQueue.sync(flags: .barrier) {
            agents.removeValue(forKey: identifier)
            logger.info("Unregistered agent '\(identifier)'")
        }
    }

    /// Start all registered agents
    public func startAll() async throws {
        logger.info("Starting all agents...")
        let allAgents = agentQueue.sync { Array(agents.values) }

        for agent in allAgents {
            do {
                try await agent.start()
            } catch {
                logger.error("Failed to start agent '\(agent.name)': \(error)")
                throw error
            }
        }

        logger.info("All agents started successfully")
    }

    /// Stop all registered agents
    public func stopAll() async {
        logger.info("Stopping all agents...")
        let allAgents = agentQueue.sync { Array(agents.values) }

        for agent in allAgents {
            do {
                if agent.isRunning {
                    try await agent.stop()
                }
            } catch {
                logger.error("Error stopping agent '\(agent.name)': \(error)")
            }
        }

        logger.info("All agents stopped")
    }

    /// Start a specific agent by identifier
    /// - Parameter identifier: The identifier of the agent to start
    public func start(_ identifier: String) async throws {
        guard let agent = agentQueue.sync(execute: { agents[identifier] }) else {
            throw AgentError.configurationError("Agent '\(identifier)' not found")
        }

        try await agent.start()
    }

    /// Stop a specific agent by identifier
    /// - Parameter identifier: The identifier of the agent to stop
    public func stop(_ identifier: String) async throws {
        guard let agent = agentQueue.sync(execute: { agents[identifier] }) else {
            throw AgentError.configurationError("Agent '\(identifier)' not found")
        }

        try await agent.stop()
    }

    /// Get the status of all agents
    /// - Returns: Dictionary mapping agent identifiers to their running status
    public func status() -> [String: Bool] {
        agentQueue.sync {
            Dictionary(uniqueKeysWithValues: agents.map { ($0.key, $0.value.isRunning) })
        }
    }

    /// Run the daemon (blocks until shutdown)
    public func run() async throws {
        logger.info("MacTools daemon starting...")

        do {
            try await startAll()
        } catch {
            logger.error("Failed to start all agents: \(error)")
            throw error
        }

        // Keep the daemon running
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // This will block until a signal is received
            dispatchMain()
        }
    }

    /// Shutdown the daemon gracefully
    public func shutdown() {
        guard !isShuttingDown else { return }
        isShuttingDown = true

        logger.info("Shutting down daemon...")

        Task {
            await stopAll()
            logger.info("Daemon shutdown complete")
            exit(0)
        }
    }

    private func setupSignalHandlers() {
        signal(SIGINT) { _ in
            DaemonManager.shared.shutdown()
        }

        signal(SIGTERM) { _ in
            DaemonManager.shared.shutdown()
        }
    }
}

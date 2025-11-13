.PHONY: build test clean install uninstall coverage lint format help

# Variables
BINARY_NAME=mactools
INSTALL_PATH=/usr/local/bin
DAEMON_PLIST=com.mactools.daemon.plist
LAUNCH_AGENTS_PATH=$(HOME)/Library/LaunchAgents

# Default target
help:
	@echo "MacTools - macOS System Tools"
	@echo ""
	@echo "Available targets:"
	@echo "  build          - Build the project"
	@echo "  test           - Run tests"
	@echo "  coverage       - Run tests with coverage"
	@echo "  lint           - Run SwiftLint"
	@echo "  format         - Format code with SwiftFormat"
	@echo "  clean          - Clean build artifacts"
	@echo "  install        - Install the binary and daemon"
	@echo "  uninstall      - Uninstall the binary and daemon"
	@echo "  start-daemon   - Start the daemon"
	@echo "  stop-daemon    - Stop the daemon"
	@echo "  daemon-status  - Check daemon status"

# Build the project
build:
	swift build -c release

# Run tests
test:
	swift test

# Run tests with coverage
coverage:
	swift test --enable-code-coverage
	xcrun llvm-cov export -format="lcov" \
		.build/debug/MacToolsPackageTests.xctest/Contents/MacOS/MacToolsPackageTests \
		-instr-profile .build/debug/codecov/default.profdata > coverage.lcov
	@echo "Coverage report generated: coverage.lcov"

# Run SwiftLint
lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

# Format code
format:
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat .; \
	else \
		echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
	fi

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
	rm -rf coverage.lcov

# Install binary and daemon
install: build
	@echo "Installing $(BINARY_NAME) to $(INSTALL_PATH)..."
	@mkdir -p $(INSTALL_PATH)
	@cp .build/release/$(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@chmod +x $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "Installing daemon configuration..."
	@mkdir -p $(LAUNCH_AGENTS_PATH)
	@cp configs/$(DAEMON_PLIST) $(LAUNCH_AGENTS_PATH)/$(DAEMON_PLIST)
	@echo "Installation complete!"
	@echo "Run 'make start-daemon' to start the daemon"

# Uninstall binary and daemon
uninstall: stop-daemon
	@echo "Uninstalling $(BINARY_NAME)..."
	@rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	@rm -f $(LAUNCH_AGENTS_PATH)/$(DAEMON_PLIST)
	@echo "Uninstallation complete!"

# Start the daemon
start-daemon:
	@echo "Starting daemon..."
	@launchctl load $(LAUNCH_AGENTS_PATH)/$(DAEMON_PLIST)
	@echo "Daemon started!"

# Stop the daemon
stop-daemon:
	@echo "Stopping daemon..."
	@-launchctl unload $(LAUNCH_AGENTS_PATH)/$(DAEMON_PLIST) 2>/dev/null || true
	@echo "Daemon stopped!"

# Check daemon status
daemon-status:
	@launchctl list | grep mactools || echo "Daemon not running"

.PHONY: test test-verbose install-hooks lint format format-check check clean help

# Variables
TEST_SCRIPT := ./scripts/test

# Default target
help:
	@echo "Available targets:"
	@echo "  test          - Run all tests"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  install-hooks - Install pre-commit git hooks"
	@echo "  lint          - Run linting checks (Lua and shell scripts)"
	@echo "  format        - Format code (Lua, shell scripts, and markdown)"
	@echo "  format-check  - Check code formatting without modifying"
	@echo "  check         - Run all quality checks (lint + format-check + test)"
	@echo "  clean         - Clean test cache and temporary files"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make test-verbose"
	@echo "  make check"
	@echo "  make install-hooks"

# Run tests
test:
	@echo "Running tests..."
	@$(TEST_SCRIPT)

# Run tests with verbose output
test-verbose:
	@echo "Running tests with verbose output..."
	@$(TEST_SCRIPT) --verbose

# Install git pre-commit hooks
install-hooks:
	@echo "Installing git pre-commit hooks..."
	@./scripts/install-hooks

# Run linting
lint:
	@echo "Running linting checks..."
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck lua/ tests/; \
	else \
		echo "luacheck not found. Install with: luarocks install luacheck"; \
		exit 1; \
	fi
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck scripts/*; \
		echo "✅ Shell scripts passed linting"; \
	else \
		echo "shellcheck not found. Install with: sudo apt install shellcheck"; \
		exit 1; \
	fi

# Format code
format:
	@echo "Formatting code..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua/ tests/; \
		echo "✅ Lua files formatted"; \
	else \
		echo "stylua not found. Install with: cargo install stylua"; \
		exit 1; \
	fi
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -w scripts/; \
		echo "✅ Shell scripts formatted"; \
	else \
		echo "shfmt not found. Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"; \
		exit 1; \
	fi
	@if command -v prettier >/dev/null 2>&1; then \
		prettier --write *.md; \
		echo "✅ Markdown files formatted"; \
	else \
		echo "prettier not found. Install with: npm install -g prettier"; \
		exit 1; \
	fi

# Check formatting without modifying
format-check:
	@echo "Checking code formatting..."
	@if command -v stylua >/dev/null 2>&1; then \
		if stylua --check lua/ tests/; then \
			echo "✅ Lua files are properly formatted"; \
		else \
			echo "❌ Lua files need formatting. Run: make format"; \
			exit 1; \
		fi \
	else \
		echo "stylua not found. Install with: cargo install stylua"; \
		exit 1; \
	fi
	@if command -v shfmt >/dev/null 2>&1; then \
		if shfmt -d scripts/; then \
			echo "✅ Shell scripts are properly formatted"; \
		else \
			echo "❌ Shell scripts need formatting. Run: make format"; \
			exit 1; \
		fi \
	else \
		echo "shfmt not found. Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"; \
		exit 1; \
	fi
	@if command -v prettier >/dev/null 2>&1; then \
		if prettier --check *.md; then \
			echo "✅ Markdown files are properly formatted"; \
		else \
			echo "❌ Markdown files need formatting. Run: make format"; \
			exit 1; \
		fi \
	else \
		echo "prettier not found. Install with: npm install -g prettier"; \
		exit 1; \
	fi

# Run all quality checks
check: lint format-check test
	@echo "✅ All quality checks passed!"

# Clean test cache and temporary files
clean:
	@echo "Cleaning test cache and temporary files..."
	@rm -rf .tests/
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "✅ Cleanup complete"
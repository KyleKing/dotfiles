# Makefile for completion-server
# Convenience wrapper around mise tasks

.PHONY: help build test lint format clean install dev ci

# Default target
help:
	@echo "Available targets:"
	@echo "  build    - Build the binary"
	@echo "  test     - Run tests"
	@echo "  lint     - Run linters"
	@echo "  format   - Format code"
	@echo "  clean    - Clean build artifacts"
	@echo "  install  - Build and install to ~/.local/bin"
	@echo "  dev      - Build and run"
	@echo "  ci       - Run all CI checks"
	@echo ""
	@echo "Using mise tasks under the hood. Run 'mise tasks' to see all tasks."

build:
	@mise run build

test:
	@mise run test

lint:
	@mise run lint

format:
	@mise run format

clean:
	@mise run clean

install: build
	@mise run build:install

dev:
	@mise run dev

ci:
	@mise run ci

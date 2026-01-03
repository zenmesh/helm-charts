# Contributing to {{ .projectName }}

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing.

## Development Setup

### Prerequisites

- **Go**: 1.24 or later ([Download](https://golang.org/dl/))
- **kubectl**: Configured to access a Kubernetes cluster ([Install](https://kubernetes.io/docs/tasks/tools/))
- **Docker**: For building images ([Install](https://docs.docker.com/get-docker/))
- **Make**: For running common tasks ([Install](https://www.gnu.org/software/make/))

### Getting Started

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/kube-zen/{{ .projectName }}.git
   cd {{ .projectName }}
   ```

2. **Verify Go installation:**
   ```bash
   go version  # Should be 1.25+
   ```

3. **Install dependencies:**
   ```bash
   go mod download
   ```

4. **Run tests:**
   ```bash
   make check
   ```

## Development Workflow

1. Create a feature branch from `main`
2. Make your changes
3. Run `make check` to ensure all checks pass
4. Commit your changes with clear commit messages
5. Push to your fork and open a pull request

## Code Standards

- Follow Go best practices and conventions
- Run `go fmt` before committing
- Ensure all tests pass
- Add tests for new functionality
- Update documentation as needed

## Pull Request Process

1. Ensure your PR description clearly describes the changes
2. Link any related issues
3. Ensure CI checks pass
4. Request review from maintainers

## Questions?

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for more detailed development guidelines.


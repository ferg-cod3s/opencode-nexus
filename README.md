# OpenCode Nexus

[![Build Status](https://github.com/opencode-nexus/opencode-nexus/workflows/Quality%20Gate/badge.svg)](https://github.com/opencode-nexus/opencode-nexus/actions/workflows/quality-gate.yml)
[![Security Scan](https://github.com/opencode-nexus/opencode-nexus/workflows/Security%20Scan/badge.svg)](https://github.com/opencode-nexus/opencode-nexus/actions/workflows/security-scan.yml)
[![License Check](https://github.com/opencode-nexus/opencode-nexus/workflows/License%20Check/badge.svg)](https://github.com/opencode-nexus/opencode-nexus/actions/workflows/license-check.yml)
[![codecov](https://codecov.io/gh/opencode-nexus/opencode-nexus/branch/main/graph/badge.svg)](https://codecov.io/gh/opencode-nexus/opencode-nexus)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A secure, cross-platform client application for connecting to OpenCode servers started with `opencode serve`, powered by Tauri v2 (Rust), Astro + Svelte (Bun), and real-time API integration.

## 🚀 Features

- **Native OpenCode Client** - Connect to OpenCode servers started with `opencode serve` with a beautiful native interface
- **Real-Time Chat Interface** - Seamless AI conversation experience with instant message streaming
- **Cross-Platform Support** - iOS (TestFlight ready), Android (prepared), and Desktop (macOS, Windows, Linux)
- **Secure Authentication** - Argon2 password hashing, account lockout protection, encrypted local storage
- **Session Management** - Persistent conversation history with search and context preservation
- **Accessibility First** - WCAG 2.2 AA compliant with full screen reader and keyboard navigation support

## 🛠️ Tech Stack

- **Backend:** Tauri v2 (Rust) for cross-platform client integration and API communication
- **Frontend:** Astro with Svelte islands for modern, responsive chat interface
- **Package Manager:** Bun for frontend dependencies and runtime
- **API Integration:** RESTful API client with Server-Sent Events for real-time streaming
- **Security:** Argon2 authentication, TLS 1.3, encrypted local storage

## 📋 Prerequisites

- **OpenCode Server:** Start an OpenCode server on any machine with OpenCode installed using `opencode serve` (or `opencode --server` in older versions)
- **Operating System:** iOS 14.0+, macOS 10.15+, Windows 10+, or Ubuntu 18.04+
- **Memory:** 4GB RAM minimum, 8GB recommended
- **Storage:** 1GB available disk space
- **Network:** Internet connection for server communication

## 🚀 Quick Start

### Starting an OpenCode Server

First, ensure you have OpenCode installed on a server machine. Start the server:

```bash
# On the machine where you want to run the OpenCode server
opencode serve --port 3000 --hostname 0.0.0.0
```

This will start an OpenCode server that the client can connect to. Note the server's IP address or hostname for client configuration.

### Installation

#### iOS (TestFlight)
1. **Request TestFlight access** through the [GitHub Issues](https://github.com/opencode-nexus/opencode-nexus/issues)
2. **Install** TestFlight app from the App Store
3. **Accept invitation** and install OpenCode Nexus
4. **Launch** and configure your OpenCode server connection

#### Desktop
1. **Download** the latest release for your platform from the [releases page](https://github.com/opencode-nexus/opencode-nexus/releases)
2. **Install** the application following platform-specific instructions
3. **Launch** OpenCode Nexus and connect to your OpenCode server

### Development Setup

```bash
# Clone the repository
git clone https://github.com/opencode-nexus/opencode-nexus.git
cd opencode-nexus

# Install frontend dependencies
cd frontend
bun install

# Start frontend development server
bun run dev

# In another terminal, start Tauri development
cd ..
cargo tauri dev
```

### Building for Production

```bash
# Build frontend
cd frontend
bun run build

# Build Tauri application
cd ..
cargo tauri build
```

## 📦 Release Process

OpenCode Nexus uses automated releases via GitHub Actions.

### For Users

Download the latest release for your platform:
- **Linux:** `.AppImage` (universal) or `.deb` (Debian/Ubuntu)
- **macOS:** `.dmg` (Intel and Apple Silicon)
- **Windows:** `.msi` installer or `.exe` portable

Visit the [Releases page](https://github.com/opencode-nexus/opencode-nexus/releases) to download.

### For Maintainers

Releases are automatically built and published when a version tag is pushed:

```bash
# Create and push a version tag
git tag v0.1.0
git push origin v0.1.0
```

This triggers the release workflow which:
1. Builds cross-platform binaries (Linux, macOS, Windows)
2. Runs all quality gates and security scans
3. Creates a GitHub Release with all assets
4. Generates checksums for verification

See [CONTRIBUTING.md](CONTRIBUTING.md#release-process) for detailed release guidelines.

## 📚 Documentation

Comprehensive documentation is available in the `/docs/client/` directory:

- **[Product Requirements Document](docs/client/PRD.md)** - Mobile-first client goals, features, and requirements
- **[Architecture Overview](docs/client/ARCHITECTURE.md)** - Client-only system design and technical architecture
- **[User Flows](docs/client/USER-FLOWS.md)** - Mobile touch interactions and offline user flows
- **[Security Model](docs/client/SECURITY.md)** - Client connection security and data protection
- **[Testing Strategy](docs/client/TESTING.md)** - Mobile testing approach and touch interaction testing
- **[Documentation Overview](docs/client/README.md)** - Complete client documentation guide

## 🔧 Development

### Project Structure

```
opencode-nexus/
├── frontend/                 # Astro + Svelte frontend (Bun)
├── src-tauri/               # Tauri Rust backend
├── docs/                    # Project documentation
├── status_docs/             # Project status and tracking
│   ├── TODO.md              # Task tracking
│   └── CURRENT_STATUS.md    # Detailed status
├── README.md                # This file
├── CHANGELOG.md             # Version history
└── LICENSE                  # Project license
```

### Development Commands

```bash
# Frontend development
cd frontend
bun run dev          # Start development server
bun run build        # Build for production
bun run test         # Run tests
bun run test:e2e     # Run end-to-end tests
bun run lint         # Lint code
bun run type-check   # TypeScript type checking

# Backend development
cargo tauri dev      # Start Tauri development
cargo tauri build    # Build Tauri application
cargo test           # Run Rust tests
cargo clippy         # Run linter
```

### Testing

This project follows **Test-Driven Development (TDD)** as required by our development standards:

- **Unit Tests:** Frontend (Vitest) and backend (Rust test framework)
- **Integration Tests:** Component and API integration testing
- **End-to-End Tests:** Playwright for full user journey validation
- **Accessibility Tests:** WCAG 2.2 AA compliance validation
- **Security Tests:** Automated vulnerability scanning and security testing

## 🔒 Security

OpenCode Nexus is built with security by design:

- **Client Authentication:** Argon2 password hashing with account lockout protection
- **Server Authentication:** Multiple methods for securing OpenCode server connections
- **Encryption:** TLS 1.3 for all server communications, AES-256 for local data
- **Session Security:** Secure session management with automatic timeout
- **Data Privacy:** Local data storage with encryption, no data sharing without consent
- **Audit Logging:** Comprehensive activity logging and monitoring

### 🔐 Server Authentication Setup

OpenCode servers don't include built-in client authentication. You must configure an external authentication layer. OpenCode Nexus supports:

| Method | Security | Best For | Setup Guide |
|--------|----------|----------|-------------|
| **Cloudflare Access** | ✅✅✅ High | Internet exposure | [Setup Guide](docs/client/AUTH_SETUP.md#method-2-cloudflare-access-service-tokens) |
| **API Key (nginx/Caddy)** | ✅✅ Medium | Self-hosted production | [Setup Guide](docs/client/AUTH_SETUP.md#method-3-api-key-authentication) |
| **Custom Header** | ✅✅✅ High | Enterprise SSO | [Setup Guide](docs/client/AUTH_SETUP.md#method-4-custom-header-authentication) |
| **No Auth** | ❌ Unsecured | Development only | Not recommended |

**📖 Complete setup instructions:** [Authentication Setup Guide](docs/client/AUTH_SETUP.md)

### Reporting Security Vulnerabilities

We take security seriously. If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** open a public GitHub issue
2. Report via [GitHub Security Advisories](https://github.com/opencode-nexus/opencode-nexus/security/advisories/new)
3. Or email: security@opencode-nexus.example.com

For detailed information, see our [Security Policy](docs/SECURITY.md#15-vulnerability-reporting-process).

**Response Timeline:**
- Initial response: Within 48 hours
- Status update: Within 7 days
- Fix timeline: Based on severity (critical: 7 days, high: 30 days, medium: 90 days)

## 🤝 Contributing

We welcome contributions from the community! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### CI/CD Pipeline

This project uses automated workflows to ensure code quality and security:

- **Quality Gate:** Runs on all PRs - linting, testing, coverage checks, builds
- **Security Scan:** Automated vulnerability scanning (Trivy, CodeQL, audit tools)
- **License Check:** Ensures all dependencies comply with approved licenses
- **Release Build:** Automated cross-platform builds on version tags

All checks must pass before code can be merged. See [CONTRIBUTING.md](CONTRIBUTING.md#cicd-pipeline) for details.

### Development Standards

This project follows strict development standards:

- **Test-Driven Development (TDD)** - Write tests before implementing features
- **Security First** - All code must pass security reviews
- **Accessibility** - WCAG 2.2 AA compliance required
- **Code Quality** - Comprehensive testing and linting
- **Documentation** - Maintain comprehensive documentation

### Getting Started

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Write tests** first (TDD requirement)
4. **Implement** your feature
5. **Test** thoroughly
6. **Commit** your changes (`git commit -m 'Add amazing feature'`)
7. **Push** to the branch (`git push origin feature/amazing-feature`)
8. **Open** a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Getting Help

- **Documentation:** Check the `/docs/` directory
- **Issues:** Report bugs and request features on [GitHub Issues](https://github.com/opencode-nexus/opencode-nexus/issues)
- **Discussions:** Join community discussions on [GitHub Discussions](https://github.com/opencode-nexus/opencode-nexus/discussions)
- **Wiki:** Check the [GitHub Wiki](https://github.com/opencode-nexus/opencode-nexus/wiki) for additional resources

### Community

- **GitHub:** [opencode-nexus/opencode-nexus](https://github.com/opencode-nexus/opencode-nexus)
- **Discord:** Join our community server
- **Reddit:** r/opencode-nexus
- **Twitter:** [@OpenCodeNexus](https://twitter.com/OpenCodeNexus)

## 🗺️ Roadmap

- **v0.1.0** - iOS client with TestFlight distribution ✅
- **v0.2.0** - Android client release
- **v0.3.0** - Desktop client enhancements
- **v1.0.0** - Production-ready with enterprise features

## 🙏 Acknowledgments

- **OpenCode Team** - For the amazing OpenCode AI coding assistant
- **Tauri Team** - For the excellent cross-platform framework
- **Astro Team** - For the modern web framework
- **Svelte Team** - For the reactive component framework
- **Bun Team** - For the fast JavaScript runtime

---

**OpenCode Nexus** - Democratizing access to AI-powered coding assistance through beautiful, secure native clients.

Made with ❤️ by the OpenCode Nexus community.


## Codeflow Workflow - Multi-Platform

This project supports both Claude Code and MCP integration.

### Claude Code Users

Use native slash commands:
- `/research`, `/plan`, `/execute`, `/test`, `/document`, `/commit`, `/review`

Commands are in `.claude/commands/`.

### Other AI Platforms (OpenCode, Claude Desktop, etc.)

Use MCP tools:
- `research`, `plan`, `execute`, `test`, `document`, `commit`, `review`

**Setup MCP Server**:
```bash
bun run /path/to/codeflow/mcp/codeflow-server.mjs
```

Commands are in `.opencode/command/`.

### Universal Workflow

1. **Research** → 2. **Plan** → 3. **Execute** → 4. **Test** → 5. **Document** → 6. **Commit** → 7. **Review**

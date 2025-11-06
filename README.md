# OpenCode Nexus

A secure, cross-platform client application for connecting to OpenCode servers, powered by Tauri v2 (Rust), Astro + Svelte (Bun), and real-time API integration.

## 🚀 Features

- **Native OpenCode Client** - Connect to existing OpenCode servers with a beautiful native interface
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

- **OpenCode Server:** Access to an existing OpenCode server instance
- **Operating System:** iOS 14.0+, macOS 10.15+, Windows 10+, or Ubuntu 18.04+
- **Memory:** 4GB RAM minimum, 8GB recommended
- **Storage:** 1GB available disk space
- **Network:** Internet connection for server communication

## 🚀 Quick Start

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

## 📚 Documentation

Comprehensive documentation is available in the `/docs/` directory:

- **[Product Requirements Document](docs/PRD.md)** - Project goals, features, and requirements
- **[Architecture Overview](docs/ARCHITECTURE.md)** - System design and technical architecture
- **[User Flows](docs/USER-FLOWS.md)** - User experience and interaction flows
- **[Security Model](docs/SECURITY.md)** - Security architecture and best practices
- **[Testing Strategy](docs/TESTING.md)** - Testing approach and quality assurance
- **[DevOps & Deployment](docs/DEVOPS.md)** - CI/CD pipeline and deployment
- **[Onboarding Guide](docs/ONBOARDING.md)** - Getting started and user guide

## 🔧 Development

### Project Structure

```
opencode-nexus/
├── frontend/                 # Astro + Svelte frontend (Bun)
├── src-tauri/               # Tauri Rust backend
├── docs/                    # Project documentation
├── README.md                # This file
├── TODO.md                  # Task tracking
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

- **Authentication:** Argon2 password hashing with account lockout protection
- **Encryption:** TLS 1.3 for all server communications, AES-256 for local data
- **Session Security:** Secure session management with automatic timeout
- **Data Privacy:** Local data storage with encryption, no data sharing without consent
- **Audit Logging:** Comprehensive activity logging and monitoring

## 🤝 Contributing

We welcome contributions from the community! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

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

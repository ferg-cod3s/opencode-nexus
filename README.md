# OpenCode Nexus

A secure, cross-platform desktop application for running and remotely accessing your OpenCode server, powered by Tauri (Rust), Astro + Svelte (Bun), and secure tunneling.

## 🚀 Features

- **One-Click OpenCode Server Management** - Start, stop, and monitor your local OpenCode server
- **Secure Remote Access** - Access your server from anywhere via Cloudflared, Tailscale, or VPN
- **Modern Web Interface** - Beautiful, responsive UI built with Astro and Svelte
- **Cross-Platform** - Works on macOS, Windows, and Linux
- **Privacy First** - Your code and data never leave your machine
- **Built-in Security** - Authentication, encryption, and access control

## 🛠️ Tech Stack

- **Backend:** Tauri (Rust) for desktop integration and security
- **Frontend:** Astro with Svelte islands for modern, responsive UI
- **Package Manager:** Bun for frontend dependencies and runtime
- **Remote Access:** Cloudflared, Tailscale, or VPN integration
- **Security:** TLS encryption, authentication, and access control

## 📋 Prerequisites

- **Operating System:** macOS 10.15+, Windows 10+, or Ubuntu 18.04+
- **Memory:** 4GB RAM minimum, 8GB recommended
- **Storage:** 2GB available disk space
- **Network:** Internet connection for initial setup and remote access

## 🚀 Quick Start

### Installation

1. **Download** the latest release for your platform from the [releases page](https://github.com/opencode-nexus/opencode-nexus/releases)
2. **Install** the application following platform-specific instructions
3. **Launch** OpenCode Nexus and follow the setup wizard

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

- **Authentication:** Multi-factor authentication support
- **Encryption:** TLS 1.3 for all communications, AES-256 for data at rest
- **Access Control:** Role-based permissions and IP whitelisting
- **Secure Tunnels:** Cloudflared, Tailscale, or VPN integration
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

- **v0.1.0** - Basic OpenCode server management
- **v0.2.0** - Secure remote access via tunnels
- **v0.3.0** - Multi-instance management
- **v1.0.0** - Production-ready with enterprise features

## 🙏 Acknowledgments

- **OpenCode Team** - For the amazing OpenCode server
- **Tauri Team** - For the excellent desktop framework
- **Astro Team** - For the modern web framework
- **Svelte Team** - For the reactive component framework
- **Bun Team** - For the fast JavaScript runtime

---

**OpenCode Nexus** - Democratizing access to AI-powered coding assistance while maintaining privacy and security.

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

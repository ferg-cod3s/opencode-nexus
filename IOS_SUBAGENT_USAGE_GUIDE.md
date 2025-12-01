# iOS Development Subagent Usage Guide

## 🎯 Overview

This guide provides specific instructions for using specialized subagents to fix iOS build issues and optimize the OpenCode Nexus Tauri application for iOS deployment.

## 🤖 Available Subagents for iOS Development

### Primary iOS Subagents

1. **development/ios_developer** - Core iOS development expertise
2. **operations/deployment_engineer** - CI/CD pipeline optimization
3. **development/mobile_developer** - Cross-platform mobile best practices
4. **operations/devops_troubleshooter** - Build failure resolution
5. **development/tauri_pro** - Tauri-specific optimization

### Supporting Subagents

6. **quality-testing/test_automator** - Automated testing setup
7. **operations/monitoring_expert** - Build monitoring and alerting
8. **development/security_auditor** - iOS security and compliance

## 📋 Subagent Delegation Matrix

| Issue Type | Primary Subagent | Secondary Subagents | When to Use |
|------------|------------------|---------------------|-------------|
| iOS build failures | `development/ios_developer` | `operations/devops_troubleshooter` | Xcode compilation errors, linking issues |
| Code signing problems | `development/ios_developer` | `operations/deployment_engineer` | Certificate/provisioning issues |
| CI/CD pipeline optimization | `operations/deployment_engineer` | `development/ios_developer` | Slow builds, workflow improvements |
| Tauri 2.x compatibility | `development/tauri_pro` | `development/ios_developer` | Rust-iOS integration issues |
| Mobile UI/UX issues | `development/mobile_developer` | `development/ios_developer` | Layout, responsiveness, touch targets |
| Performance optimization | `development/mobile_developer` | `development/tauri_pro` | App size, startup time, memory usage |
| Security compliance | `development/security_auditor` | `development/ios_developer` | App Store guidelines, permissions |
| Testing automation | `quality-testing/test_automator` | `development/mobile_developer` | E2E tests, device testing |

## 🚀 Specific Subagent Tasks

### Phase 1: Core iOS Setup (development/ios_developer)

```bash
Task: "Fix iOS configuration and dependencies for Tauri 2.x"
Agent: development/ios_developer
Focus: 
- Update Cargo.toml iOS dependencies
- Create proper entitlements file
- Configure ATS for @opencode-ai/sdk
- Fix Podfile configuration
- Validate iOS deployment target
```

**Expected Output:**
- Updated Cargo.toml with iOS-specific dependencies
- Proper entitlements configuration
- ATS exceptions for OpenCode domains
- Working Podfile for iOS builds

### Phase 2: Build System Optimization (operations/deployment_engineer)

```bash
Task: "Optimize iOS build pipeline for GitHub Actions"
Agent: operations/deployment_engineer
Focus:
- Fix Tauri CLI version compatibility
- Optimize build caching strategy
- Improve code signing workflow
- Reduce build time
- Add proper error handling
```

**Expected Output:**
- Optimized GitHub Actions workflow
- Improved caching configuration
- Faster build times
- Better error reporting

### Phase 3: Tauri Integration (development/tauri_pro)

```bash
Task: "Fix Tauri 2.x iOS integration issues"
Agent: development/tauri_pro
Focus:
- Rust-iOS target compilation
- Tauri plugin compatibility
- IPC communication on iOS
- Memory management
- Performance optimization
```

**Expected Output:**
- Working Rust compilation for iOS
- Proper Tauri plugin setup
- Optimized IPC layer
- Memory usage improvements

### Phase 4: Mobile Testing (development/mobile_developer)

```bash
Task: "Validate iOS app functionality and performance"
Agent: development/mobile_developer
Focus:
- Device compatibility testing
- UI responsiveness validation
- Touch target compliance
- Performance profiling
- Accessibility testing
```

**Expected Output:**
- Device compatibility report
- UI/UX validation results
- Performance metrics
- Accessibility compliance status

### Phase 5: Security & Compliance (development/security_auditor)

```bash
Task: "Audit iOS app for App Store compliance"
Agent: development/security_auditor
Focus:
- App Store guidelines compliance
- Privacy manifest validation
- Network security review
- Permission usage audit
- Encryption compliance
```

**Expected Output:**
- Security audit report
- App Store compliance checklist
- Privacy policy recommendations
- Permission usage documentation

## 🔧 Subagent Usage Examples

### Example 1: Fixing iOS Build Failures

```bash
# Use ios_developer for build issues
Task: "Diagnose and fix iOS compilation errors"
Agent: development/ios_developer
Prompt: """
The iOS build is failing with the following errors:
1. Rust compilation errors for aarch64-apple-ios target
2. Missing iOS-specific dependencies
3. Code signing configuration issues

Please analyze the current Cargo.toml, tauri.conf.json, and build workflow to identify and fix these issues. Focus on Tauri 2.x compatibility and iOS-specific requirements.

Current files to examine:
- src-tauri/Cargo.toml
- src-tauri/tauri.ios.conf.json
- .github/workflows/ios-release.yml
- src-tauri/ios-config/

Provide specific fixes and updated configuration files.
"""
```

### Example 2: Optimizing CI/CD Pipeline

```bash
# Use deployment_engineer for pipeline optimization
Task: "Optimize iOS build pipeline for faster builds"
Agent: operations/deployment_engineer
Prompt: """
The current iOS build pipeline is taking too long (60+ minutes) and has reliability issues. Please optimize the GitHub Actions workflow for:

1. Faster build times through better caching
2. Improved reliability with proper error handling
3. Better resource utilization
4. Enhanced logging and debugging
5. Parallel build steps where possible

Current workflow: .github/workflows/ios-release.yml

Focus on:
- Rust dependency caching
- Frontend build optimization
- Xcode build parallelization
- Code signing efficiency
- TestFlight upload reliability

Provide an optimized workflow file and implementation plan.
"""
```

### Example 3: Tauri 2.x iOS Integration

```bash
# Use tauri_pro for Tauri-specific issues
Task: "Fix Tauri 2.x iOS integration and performance"
Agent: development/tauri_pro
Prompt: """
We're migrating to Tauri 2.x and experiencing iOS integration issues:

1. Rust backend not properly linking with iOS frontend
2. IPC communication failures on iOS
3. Memory usage is too high
4. App startup time is slow
5. Some Tauri plugins not working on iOS

Please analyze the current Tauri setup and provide:
1. Updated Cargo.toml with proper iOS dependencies
2. Fixed tauri.conf.json for iOS
3. Optimized Rust code for iOS
4. Performance improvements
5. Plugin compatibility fixes

Current setup:
- Tauri 2.0.0
- iOS deployment target: 14.0
- Using @opencode-ai/sdk for HTTP calls
- Frontend: Astro + Svelte 5

Focus on iOS-specific Tauri patterns and best practices.
"""
```

## 📊 Subagent Coordination Workflow

### Sequential Subagent Usage

```
1. development/ios_developer (Core setup)
   ↓
2. development/tauri_pro (Tauri integration)
   ↓
3. operations/deployment_engineer (CI/CD optimization)
   ↓
4. development/mobile_developer (Testing & validation)
   ↓
5. development/security_auditor (Compliance check)
```

### Parallel Subagent Usage

```
development/ios_developer ←→ operations/deployment_engineer
         ↓                           ↓
development/tauri_pro ←→ development/mobile_developer
         ↓                           ↓
development/security_auditor ←→ quality-testing/test_automator
```

## 🎯 Subagent Success Criteria

### development/ios_developer Success Metrics
- ✅ iOS build success rate >95%
- ✅ Build time <30 minutes
- ✅ Code signing working reliably
- ✅ All iOS-specific configurations in place

### operations/deployment_engineer Success Metrics
- ✅ CI/CD pipeline reliability >98%
- ✅ Build time reduced by 40%
- ✅ Proper caching implemented
- ✅ Error handling and recovery in place

### development/tauri_pro Success Metrics
- ✅ Tauri 2.x integration complete
- ✅ IPC communication working
- ✅ Memory usage optimized
- ✅ Plugin compatibility verified

### development/mobile_developer Success Metrics
- ✅ Device compatibility verified
- ✅ UI/UX meets mobile standards
- ✅ Performance benchmarks met
- ✅ Accessibility compliance achieved

### development/security_auditor Success Metrics
- ✅ App Store compliance verified
- ✅ Security audit passed
- ✅ Privacy manifest complete
- ✅ Permission usage documented

## 🔄 Iterative Improvement Process

### 1. Initial Assessment
```bash
Task: "Assess current iOS build status and identify issues"
Agent: development/ios_developer
```

### 2. Core Fixes Implementation
```bash
Task: "Implement core iOS configuration fixes"
Agent: development/ios_developer
```

### 3. Integration Testing
```bash
Task: "Test iOS integration and fix compatibility issues"
Agent: development/tauri_pro
```

### 4. Pipeline Optimization
```bash
Task: "Optimize build pipeline for production"
Agent: operations/deployment_engineer
```

### 5. Final Validation
```bash
Task: "Perform comprehensive iOS app validation"
Agent: development/mobile_developer
```

### 6. Security & Compliance
```bash
Task: "Complete security audit and compliance check"
Agent: development/security_auditor
```

## 📞 Escalation Procedures

### When to Escalate
1. **Build failures persisting >3 attempts** → Escalate to `operations/devops_troubleshooter`
2. **Security issues identified** → Escalate to `development/security_auditor`
3. **Performance not meeting targets** → Escalate to `development/mobile_developer`
4. **Tauri-specific issues** → Escalate to `development/tauri_pro`

### Emergency Escalation
```bash
Task: "Emergency iOS build fix - production deployment blocked"
Agent: operations/devops_troubleshooter
Priority: Critical
Prompt: """
URGENT: iOS build is blocking production deployment. Build is failing with [specific error]. Need immediate resolution to meet release deadline.

Current status:
- Build failing at: [stage]
- Error message: [error]
- Impact: Production release blocked
- Deadline: [deadline]

Please provide immediate fix and rollback plan if needed.
"""
```

## 📈 Monitoring & Metrics

### Key Performance Indicators
- **Build Success Rate**: Target >95%
- **Build Time**: Target <30 minutes
- **TestFlight Upload Success**: Target 100%
- **App Store Approval**: Target first submission success

### Monitoring Setup
```bash
Task: "Set up iOS build monitoring and alerting"
Agent: operations/monitoring_expert
Focus:
- Build success/failure tracking
- Performance metrics collection
- Alert configuration for failures
- Dashboard setup for visibility
```

## 🎉 Success Celebration

When all subagents complete their tasks successfully:
```bash
Task: "Celebrate successful iOS build and deployment"
Agent: generalist/code_generation_specialist
Focus:
- Generate success summary
- Create deployment announcement
- Document lessons learned
- Plan next improvements
```

---

**Remember**: Each subagent has specialized expertise. Use them according to their strengths, and don't hesitate to escalate when issues are outside a subagent's primary domain. The key is systematic, iterative improvement with proper coordination between subagents.
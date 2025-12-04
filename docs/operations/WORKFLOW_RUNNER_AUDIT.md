# GitHub Actions Runner Usage Audit

**Date**: December 4, 2025  
**Purpose**: Document current runner usage patterns across all workflows  
**Status**: AUDIT COMPLETE

---

## 📊 Summary

| Workflow | Primary Runner | macOS Target | Self-Hosted | Cost Impact |
|----------|----------------|---------------|-------------|------------|
| `ios-release-optimized.yml` | `self-hosted` | ✅ | ✅ | $0/min |
| `ios-release-fixed.yml` | `self-hosted` | ✅ | ✅ | $0/min |
| `test-backend.yml` | `ubuntu-latest` + `self-hosted` | ✅ | ✅ | $0/min (macOS) |
| `test-frontend.yml` | `ubuntu-latest` | ❌ | ❌ | $0/min |
| `test-mobile-e2e.yml` | `ubuntu-l14` | ❌ | ❌ | $0/min |
| `test-integration.yml` | `ubuntu-latest` | ❌ | ❌ | $0/min |
| `license-check.yml` | `ubuntu-latest` | ❌ | ❌ | $0/min |

**Current State**: 3/7 workflows use self-hosted runner for macOS builds  
**Optimization Opportunity**: 4 workflows could benefit from macOS testing

---

## 🔍 Detailed Analysis

### ✅ Workflows Already Using Self-Hosted Runner

#### 1. `ios-release-optimized.yml`
- **Line 25**: `runs-on: self-hosted`
- **Purpose**: iOS TestFlight builds
- **Target**: `aarch64-apple-ios`
- **Status**: ✅ OPTIMIZED

#### 2. `ios-release-fixed.yml`
- **Line 25**: `runs-on: self-hosted`
- **Purpose**: iOS TestFlight builds (alternative)
- **Target**: `aarch64-apple-ios`
- **Status**: ✅ OPTIMIZED

#### 3. `test-backend.yml`
- **Lines 151-154**: Matrix includes self-hosted targets
```yaml
- os: self-hosted
  target: aarch64-apple-darwin
- os: self-hosted
  target: x86_64-apple-darwin
```
- **Purpose**: Backend testing across platforms
- **Status**: ✅ OPTIMIZED

### ⚠️ Workflows Using GitHub-Hosted Runners

#### 4. `test-frontend.yml`
- **Line 19**: `runs-on: ubuntu-latest`
- **Purpose**: Frontend testing (TypeScript, Svelte, Astro)
- **macOS Opportunity**: Could add optional macOS testing
- **Status**: ⚠️ OPTIMIZATION OPPORTUNITY

#### 5. `test-mobile-e2e.yml`
- **Line 28**: `runs-on: ubuntu-latest`
- **Purpose**: Mobile E2E testing (simulated mobile)
- **macOS Opportunity**: Could test on actual Safari/iOS
- **Status**: ⚠️ OPTIMIZATION OPPORTUNITY

#### 6. `test-integration.yml`
- **Line 29**: `runs-on: ubuntu-latest`
- **Purpose**: Full-stack integration testing
- **macOS Opportunity**: Could test macOS-specific features
- **Status**: ⚠️ OPTIMIZATION OPPORTUNITY

#### 7. `license-check.yml`
- **Lines 14, 57**: `runs-on: ubuntu-latest`
- **Purpose**: License compliance checking
- **macOS Opportunity**: Not necessary (platform-agnostic)
- **Status**: ✅ NO CHANGE NEEDED

---

## 🎯 Recommendations

### High Priority (Immediate Impact)

#### 1. Add Runner Detection to Existing Self-Hosted Workflows
- **Files**: `ios-release-optimized.yml`, `ios-release-fined.yml`, `test-backend.yml`
- **Change**: Add runner availability detection and fallback logic
- **Impact**: Prevent build failures when self-hosted runner unavailable

#### 2. Create Reusable Runner Detection Workflow
- **File**: `.github/workflows/runner-detection.yml`
- **Purpose**: Centralized runner availability checking
- **Impact**: Consistent behavior across all workflows

### Medium Priority (Enhanced Coverage)

#### 3. Add macOS Testing to Frontend Workflows
- **Files**: `test-frontend.yml`, `test-mobile-e2e.yml`
- **Change**: Add optional macOS matrix on self-hosted runner
- **Impact**: Better platform coverage, Safari testing

#### 4. Implement Runner Health Monitoring
- **File**: `.github/workflows/runner-health-check.yml`
- **Purpose**: Daily health checks and alerting
- **Impact**: Proactive issue detection

### Low Priority (Future Enhancements)

#### 5. Cost Tracking and Reporting
- **File**: `.github/workflows/cost-report.yml`
- **Purpose**: Monthly cost savings reporting
- **Impact**: Visibility into savings and ROI

---

## 📈 Cost Analysis

### Current Monthly Costs (Estimated)
- **Self-hosted runner**: $0/month
- **GitHub-hosted runners**: $0/month (no macOS usage)
- **Total**: $0/month

### Potential Monthly Costs (Without Self-Hosted)
- **iOS builds**: ~2 hours/day × $0.08/min × 30 days = $288/month
- **Backend macOS testing**: ~1 hour/day × $0.08/min × 30 days = $144/month
- **Total Potential**: $432/month

### Current Monthly Savings
- **Direct savings**: $432/month
- **Annual savings**: $5,184/year

---

## 🔧 Technical Findings

### Runner Configuration Patterns

#### Pattern 1: Direct Self-Hosted Usage
```yaml
jobs:
  build-ios:
    runs-on: self-hosted
```
**Used in**: `ios-release-optimized.yml`, `ios-release-fixed.yml`

#### Pattern 2: Matrix with Self-Hosted
```yaml
strategy:
  matrix:
    include:
      - os: self-hosted
        target: aarch64-apple-darwin
```
**Used in**: `test-backend.yml`

#### Pattern 3: GitHub-Hosted Only
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
```
**Used in**: `test-frontend.yml`, `test-mobile-e2e.yml`, `test-integration.yml`, `license-check.yml`

### Missing Features

1. **Runner Availability Detection**: No workflows check if self-hosted runner is actually available
2. **Fallback Mechanism**: No fallback to GitHub-hosted runners when self-hosted unavailable
3. **Cost Warnings**: No alerts when falling back to expensive runners
4. **Health Monitoring**: No automated health checks for self-hosted runner
5. **Usage Tracking**: No metrics on runner utilization and savings

---

## 📋 Action Items

### Immediate (This Sprint)
1. ✅ **Audit Complete**: Documented current state
2. 🔄 **Create Runner Detection**: Implement availability checking
3. 🔄 **Update Existing Workflows**: Add fallback logic
4. 🔄 **Create Health Monitoring**: Daily health checks

### Short Term (Next Sprint)
1. 🔄 **Add macOS Testing**: Extend frontend testing to macOS
2. 🔄 **Implement Cost Tracking**: Monthly savings reports
3. 🔄 **Create Documentation**: Operational runbooks

### Long Term (Future)
1. ⏳ **Advanced Monitoring**: Performance dashboards
2. ⏳ **Auto-scaling**: Multiple self-hosted runners
3. ⏳ **Cross-platform**: Windows/Linux self-hosted runners

---

## 🎯 Success Metrics

### Before Implementation
- **Self-hosted utilization**: 43% (3/7 workflows)
- **Fallback mechanism**: 0%
- **Health monitoring**: 0%
- **Cost tracking**: 0%

### After Implementation (Target)
- **Self-hosted utilization**: 85%+ (6/7 workflows)
- **Fallback mechanism**: 100% (all self-hosted workflows)
- **Health monitoring**: 100% (daily checks)
- **Cost tracking**: 100% (monthly reports)

---

## 📚 Related Documentation

- [SELF_HOSTED_RUNNER_SETUP.md](../SELF_HOSTED_RUNNER_SETUP.md) - Initial setup guide
- [GitHub Actions Documentation](https://docs.github.com/en/actions) - Official docs
- [Self-Hosted Runner Best Practices](https://docs.github.com/en/actions/hosting-your-own-runners) - Runner management

---

**Audit Completed**: December 4, 2025  
**Next Step**: Create runner detection mechanism and reusable workflow
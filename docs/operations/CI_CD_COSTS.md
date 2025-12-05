# CI/CD Cost Tracking and Optimization Guide

**Purpose**: Comprehensive cost management for GitHub Actions with self-hosted runner  
**Target Audience**: DevOps engineers, engineering managers, finance teams  
**Last Updated**: December 4, 2025

---

## 💰 Cost Overview

### GitHub Actions Pricing (2025)

| Runner Type | Cost per Minute | Monthly Cost (8h/day) |
|-------------|------------------|-------------------------|
| Ubuntu Linux | $0.008 | $11.52 |
| Windows | $0.016 | $23.04 |
| macOS | $0.080 | $115.20 |
| **Self-Hosted** | **$0.000** | **$0.00** |

### Cost Impact Analysis

#### Before Self-Hosted Runner
```
Monthly CI/CD Costs:
- iOS Builds (2h/day × $0.08): $288.00
- macOS Backend Tests (1h/day × $0.08): $144.00
- Linux Tests (4h/day × $0.008): $5.76
- Windows Tests (1h/day × $0.016): $2.88

Total Monthly Cost: $440.64
Annual Cost: $5,287.68
```

#### After Self-Hosted Runner
```
Monthly CI/CD Costs:
- Self-Hosted Runner (8h/day × $0.00): $0.00
- Linux Tests (4h/day × $0.008): $5.76
- Windows Tests (1h/day × $0.016): $2.88

Total Monthly Cost: $8.64
Annual Cost: $103.68
```

#### **Monthly Savings: $432.00**
#### **Annual Savings: $5,184.00**

---

## 📊 Cost Tracking Implementation

### Automated Cost Collection

#### GitHub Actions Workflow
```yaml
# .github/workflows/cost-tracking.yml
name: CI/CD Cost Tracking

on:
  schedule:
    - cron: '0 3 1 * *'  # Monthly on 1st at 3 AM UTC
  workflow_dispatch:

jobs:
  collect-metrics:
    runs-on: ubuntu-latest
    steps:
      - name: Collect Workflow Metrics
        id: metrics
        run: |
          # Query GitHub API for workflow runs
          # Calculate minutes by runner type
          # Compute costs and savings
          
      - name: Generate Cost Report
        run: |
          # Create detailed cost analysis
          # Generate recommendations
          
      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: cost-report-$(date +%Y%m)
          path: cost-report.md
```

#### Metrics Collection Script
```javascript
// scripts/cost-calculator.js
const { Octokit } = require("@octokit/rest");

class CostCalculator {
  constructor(token, repo) {
    this.octokit = new Octokit({ auth: token });
    this.repo = repo;
    this.pricing = {
      'ubuntu-latest': 0.008,
      'windows-latest': 0.016,
      'macos-14': 0.080,
      'self-hosted': 0.000
    };
  }

  async collectWorkflowRuns(days = 30) {
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    
    const { data: runs } = await this.octokit.actions.listWorkflowRunsForRepo({
      owner: this.repo.owner,
      repo: this.repo.name,
      created: since.toISOString(),
      per_page: 100
    });

    return runs.workflow_runs.map(run => this.analyzeRun(run));
  }

  analyzeRun(run) {
    const duration = (new Date(run.updated_at) - new Date(run.created_at)) / 1000 / 60;
    const runnerType = this.extractRunnerType(run);
    const cost = duration * this.pricing[runnerType];
    
    return {
      id: run.id,
      name: run.name,
      status: run.conclusion,
      duration: duration,
      runnerType: runnerType,
      cost: cost,
      date: run.created_at
    };
  }

  extractRunnerType(run) {
    // Extract runner type from logs or labels
    if (run.labels?.includes('self-hosted')) {
      return 'self-hosted';
    }
    
    // Default to job name patterns
    if (run.name.includes('iOS') || run.name.includes('macOS')) {
      return 'macos-14';
    } else if (run.name.includes('Windows')) {
      return 'windows-latest';
    } else {
      return 'ubuntu-latest';
    }
  }

  generateReport(runs) {
    const totalCost = runs.reduce((sum, run) => sum + run.cost, 0);
    const selfHostedRuns = runs.filter(run => run.runnerType === 'self-hosted');
    const selfHostedMinutes = selfHostedRuns.reduce((sum, run) => sum + run.duration, 0);
    
    const potentialCost = runs.reduce((sum, run) => {
      const githubCost = run.duration * this.pricing['macos-14']; // Assume all would be macOS
      return sum + githubCost;
    }, 0);
    
    const savings = potentialCost - totalCost;
    
    return {
      totalRuns: runs.length,
      selfHostedRuns: selfHostedRuns.length,
      totalMinutes: runs.reduce((sum, run) => sum + run.duration, 0),
      selfHostedMinutes: selfHostedMinutes,
      actualCost: totalCost,
      potentialCost: potentialCost,
      savings: savings,
      utilizationRate: (selfHostedMinutes / runs.reduce((sum, run) => sum + run.duration, 0)) * 100
    };
  }
}

module.exports = CostCalculator;
```

### Manual Cost Tracking

#### Spreadsheet Template
| Date | Workflow | Runner Type | Duration (min) | Cost | Status | Notes |
|------|----------|--------------|-----------------|------|--------|-------|
| 2025-12-01 | iOS Release | self-hosted | 15 | $0.00 | Success |
| 2025-12-01 | Backend Test | ubuntu-latest | 8 | $0.064 | Success |
| 2025-12-01 | Frontend Test | ubuntu-latest | 5 | $0.040 | Success |

#### Cost Calculation Formulas
```excel
=IF(D2="self-hosted", 0, C2 * VLOOKUP(D2, $PricingTable, 2, FALSE))
=SUM(E2:E100)  # Total cost
=COUNTIF(D2:D100, "self-hosted") / COUNTA(D2:D100) * 100  # Utilization rate
```

---

## 📈 Cost Optimization Strategies

### 1. Maximize Self-Hosted Utilization

#### Target: 85%+ utilization
```yaml
# Workflow optimization
jobs:
  build:
    strategy:
      matrix:
        include:
          - os: self-hosted
            target: aarch64-apple-darwin
          - os: ubuntu-latest
            target: x86_64-unknown-linux-gnu
    
    # Use self-hosted when available
    runs-on: ${{ matrix.os }}
```

#### Utilization Tracking
```bash
# Monthly utilization report
SELF_HOSTED_MINUTES=$(calculate_self_hosted_minutes)
TOTAL_MINUTES=$(calculate_total_minutes)
UTILIZATION_RATE=$((SELF_HOSTED_MINUTES * 100 / TOTAL_MINUTES))

if [ "$UTILIZATION_RATE" -lt 85 ]; then
  echo "⚠️ Self-hosted utilization: ${UTILIZATION_RATE}% (target: 85%+)"
  echo "💰 Potential additional savings: $((85 - UTILIZATION_RATE)) * TOTAL_MINUTES * 0.08 / 100"
fi
```

### 2. Optimize Workflow Triggers

#### Smart Triggering
```yaml
# Only run expensive macOS builds when necessary
on:
  push:
    branches: [main, release]
    paths:
      - 'src-tauri/**'      # Only on Rust changes
      - 'ios-config/**'      # Only on iOS changes
  pull_request:
    branches: [main]
    paths:
      - 'src-tauri/**'
      - 'ios-config/**'
```

#### Conditional Execution
```yaml
jobs:
  ios-build:
    runs-on: self-hosted
    if: |
      contains(github.event.head_commit.modified, 'src-tauri/') ||
      contains(github.event.head_commit.modified, 'ios-config/') ||
      github.event_name == 'workflow_dispatch'
```

### 3. Caching Optimization

#### Multi-Layer Caching
```yaml
- name: Optimize Caching
  uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/registry
      ~/.cargo/git
      target
      frontend/node_modules
      ~/.bun/install/cache
    key: ${{ runner.os }}-comprehensive-${{ hashFiles('**/Cargo.lock', '**/bun.lockb', 'src-tauri/Cargo.toml', 'frontend/package.json') }}
    restore-keys: |
      ${{ runner.os }}-comprehensive-
      ${{ runner.os }}-partial-
      ${{ runner.os }}-
```

#### Cache Hit Rate Tracking
```yaml
- name: Track Cache Performance
  run: |
    CACHE_HIT_RATE=$(calculate_cache_hit_rate)
    echo "Cache hit rate: ${CACHE_HIT_RATE}%"
    
    if [ "$CACHE_HIT_RATE" -lt 70 ]; then
      echo "::warning::Low cache hit rate: ${CACHE_HIT_RATE}%"
    fi
```

### 4. Parallel Execution Optimization

#### Job Parallelization
```yaml
jobs:
  test:
    strategy:
      matrix:
        include:
          - os: self-hosted
            test_type: unit
          - os: self-hosted
            test_type: integration
          - os: ubuntu-latest
            test_type: e2e
    
    runs-on: ${{ matrix.os }}
```

#### Resource Allocation
```yaml
- name: Optimize Resource Usage
  run: |
    # Limit parallel jobs on self-hosted runner
    export CARGO_JOBS=2  # Limit to 2 CPU cores
    export BUN_JOBS=2     # Limit to 2 CPU cores
    
    # Use less memory-intensive settings
    export NODE_OPTIONS="--max-old-space-size=2048"
```

---

## 💡 Cost Analysis Tools

### ROI Calculator

#### Investment Analysis
```javascript
// scripts/roi-calculator.js
class ROICalculator {
  calculateROI(hardwareCost, monthlySavings, months = 12) {
    const totalSavings = monthlySavings * months;
    const roi = ((totalSavings - hardwareCost) / hardwareCost) * 100;
    const paybackPeriod = hardwareCost / monthlySavings;
    
    return {
      hardwareCost,
      monthlySavings,
      annualSavings: monthlySavings * 12,
      totalSavings,
      roi: roi.toFixed(1),
      paybackPeriod: paybackPeriod.toFixed(1)
    };
  }
}

// Example usage
const calculator = new ROICalculator();
const roi = calculator.calculateROI(2000, 432); // MacBook cost + monthly savings
console.log(`ROI: ${roi.roi}%`);
console.log(`Payback Period: ${roi.paybackPeriod} months`);
```

#### Break-Even Analysis
```bash
# Calculate break-even point
HARDWARE_COST=2000  # MacBook cost
MONTHLY_SAVINGS=432
BREAK_EVEN_MONTHS=$((HARDWARE_COST / MONTHLY_SAVINGS))

echo "Hardware Investment: $${HARDWARE_COST}"
echo "Monthly Savings: $${MONTHLY_SAVINGS}"
echo "Break-Even: ${BREAK_EVEN_MONTHS} months"
echo "Annual ROI: $((MONTHLY_SAVINGS * 12 * 100 / HARDWARE_COST))%"
```

### Cost Forecasting

#### Trend Analysis
```javascript
// scripts/forecast.js
class CostForecaster {
  forecastNextPeriod(historicalData, periods = 1) {
    // Simple linear regression for trend
    const n = historicalData.length;
    const sumX = historicalData.reduce((sum, _, i) => sum + i, 0);
    const sumY = historicalData.reduce((sum, cost) => sum + cost, 0);
    const sumXY = historicalData.reduce((sum, cost, i) => sum + i * cost, 0);
    const sumX2 = historicalData.reduce((sum, _, i) => sum + i * i, 0);
    
    const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    const intercept = (sumY - slope * sumX) / n;
    
    const nextPeriod = intercept + slope * (n + periods);
    
    return {
      forecast: nextPeriod,
      trend: slope > 0 ? 'increasing' : 'decreasing',
      confidence: this.calculateConfidence(historicalData, slope, intercept)
    };
  }
}
```

### Scenario Planning

#### What-If Analysis
```javascript
// scripts/scenario-planner.js
const scenarios = {
  current: {
    selfHostedUtilization: 0.85,
    githubHostedJobs: 50,
    monthlyCost: 8.64
  },
  optimized: {
    selfHostedUtilization: 0.95,
    githubHostedJobs: 25,
    monthlyCost: 4.32
  },
  degraded: {
    selfHostedUtilization: 0.60,
    githubHostedJobs: 100,
    monthlyCost: 25.28
  }
};

function compareScenarios(scenarios) {
  return Object.entries(scenarios).map(([name, scenario]) => ({
    scenario: name,
    monthlyCost: scenario.monthlyCost,
    annualSavings: (432 - scenario.monthlyCost) * 12,
    roi: ((432 - scenario.monthlyCost) * 12 / 2000) * 100
  }));
}
```

---

## 📊 Reporting and Visualization

### Monthly Cost Report Template

```markdown
# 💰 CI/CD Cost Report - [Month] [Year]

## Executive Summary
- **Total Cost**: $X.XX
- **Savings vs GitHub-Hosted**: $XXX.XX
- **Self-Hosted Utilization**: XX%
- **Annual ROI**: XX%

## Detailed Breakdown

### By Runner Type
| Runner Type | Jobs | Minutes | Cost | % of Total |
|-------------|-------|---------|-------|------------|
| Self-Hosted | XXX | XXX | $0.00 | XX% |
| GitHub-Hosted | XXX | XXX | $XXX.XX | XX% |

### By Workflow
| Workflow | Runner Type | Jobs | Avg Duration | Cost |
|----------|--------------|-------|--------------|------|
| iOS Release | Self-Hosted | XX | XX min | $0.00 |
| Backend Test | Self-Hosted | XX | XX min | $0.00 |
| Frontend Test | Ubuntu | XX | XX min | $X.XX |

## Trends and Analysis

### Utilization Trends
- Self-hosted utilization: [↑/↓/→] X% vs last month
- Cost per job: [↑/↓/→] $X.XX vs last month
- Success rate: XX% (target: 95%+)

### Optimization Opportunities
1. **Increase Self-Hosted Utilization**: Current X% → Target 85%+
   - Potential savings: $XX.XX/month
2. **Optimize Caching**: Current cache hit rate X% → Target 80%+
   - Potential time savings: XX minutes/month
3. **Review Workflow Triggers**: X jobs could be optimized
   - Potential cost reduction: $XX.XX/month

## Recommendations
1. **Immediate Actions** (This month)
   - [ ] Address runner downtime issues
   - [ ] Optimize workflow triggers
   - [ ] Improve caching strategy

2. **Short-term Improvements** (Next 3 months)
   - [ ] Expand self-hosted to more workflows
   - [ ] Implement advanced monitoring
   - [ ] Consider additional self-hosted runners

3. **Long-term Strategy** (Next 12 months)
   - [ ] Evaluate multi-runner setup
   - [ ] Implement cost forecasting
   - [ ] Develop automated optimization
```

### Dashboard Metrics

#### Key Performance Indicators
1. **Cost Efficiency**
   - Cost per job: Target <$0.50
   - Cost per minute: Target <$0.02
   - Monthly savings trend: Target increasing

2. **Utilization Metrics**
   - Self-hosted utilization: Target >85%
   - Runner uptime: Target >99.5%
   - Job success rate: Target >95%

3. **Operational Metrics**
   - Average job duration: Target decreasing
   - Queue time: Target <1 minute
   - Cache hit rate: Target >80%

---

## 🔧 Cost Optimization Implementation

### Phase 1: Foundation (Month 1)
- [ ] Implement automated cost tracking
- [ ] Set up monthly reporting
- [ ] Establish baseline metrics
- [ ] Create cost awareness culture

### Phase 2: Optimization (Months 2-3)
- [ ] Maximize self-hosted utilization
- [ ] Optimize workflow triggers
- [ ] Implement advanced caching
- [ ] Reduce GitHub-hosted usage

### Phase 3: Advanced (Months 4-6)
- [ ] Implement cost forecasting
- [ ] Add scenario planning
- [ ] Create automated optimization
- [ ] Expand monitoring capabilities

### Phase 4: Scale (Months 7-12)
- [ ] Evaluate multi-runner setup
- [ ] Implement cross-repo sharing
- [ ] Develop cost governance
- [ ] Create optimization playbook

---

## 📋 Cost Management Checklist

### Daily
- [ ] Monitor runner status
- [ ] Check for unusual cost spikes
- [ ] Review active job costs

### Weekly
- [ ] Analyze cost trends
- [ ] Review utilization rates
- [ ] Identify optimization opportunities

### Monthly
- [ ] Generate cost report
- [ ] Compare vs budget/forecast
- [ ] Update ROI calculations
- [ ] Plan optimizations

### Quarterly
- [ ] Review cost strategy
- [ ] Evaluate hardware investments
- [ ] Update cost models
- [ ] Present to stakeholders

---

## 🚀 Advanced Cost Optimization

### Machine Learning Optimization
```python
# scripts/ml-optimizer.py
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split

class CostOptimizer:
    def __init__(self):
        self.model = RandomForestRegressor(n_estimators=100)
        self.features = ['day_of_week', 'time_of_day', 'workflow_type', 'file_changes']
        self.target = 'cost'
    
    def train(self, historical_data):
        X = historical_data[self.features]
        y = historical_data[self.target]
        
        self.model.fit(X, y)
        
    def predict_optimal_schedule(self, upcoming_workflows):
        predictions = []
        for workflow in upcoming_workflows:
            features = self.extract_features(workflow)
            predicted_cost = self.model.predict([features])[0]
            predictions.append({
                'workflow': workflow,
                'predicted_cost': predicted_cost,
                'optimal_time': self.find_optimal_time(workflow)
            })
        
        return sorted(predictions, key=lambda x: x['predicted_cost'])
```

### Automated Cost Governance
```yaml
# .github/workflows/cost-governance.yml
name: Cost Governance

on:
  pull_request:
    paths:
      - '.github/workflows/**'

jobs:
  cost-impact:
    runs-on: ubuntu-latest
    steps:
      - name: Analyze Cost Impact
        run: |
          # Analyze workflow changes for cost impact
          # Block expensive changes without approval
          
      - name: Cost Guard
        if: cost_impact.monthly_increase > 50
        run: |
          echo "::error::Proposed changes increase monthly costs by $${cost_impact.monthly_increase}"
          echo "Requires engineering manager approval"
          exit 1
```

---

## 📚 Resources and References

### Documentation
- [GitHub Actions Billing](https://docs.github.com/en/billing/managing-billing-for-github-actions)
- [Self-Hosted Runner Costs](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners)
- [Cost Optimization Best Practices](https://github.com/features/cost-optimization)

### Tools
- [GitHub CLI](https://cli.github.com/) - Cost analysis commands
- [Cost Explorer](https://github.com/marketplace/actions/cost-explorer) - Third-party cost tracking
- [Actions Cost Calculator](https://github.com/marketplace/actions/cost-calculator) - Automated cost calculation

### Community
- [GitHub Actions Community](https://github.com/community)
- [DevOps Cost Optimization](https://devops.com/cost-optimization)
- [CI/CD Cost Management](https://cicd.com/cost-management)

---

**Document Maintainer**: DevOps Team  
**Review Schedule**: Monthly  
**Last Reviewed**: December 4, 2025
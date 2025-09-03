---
description: Generate and run a comprehensive testing workflow
---

# Test Implementation

You are tasked with designing, generating, and executing tests for the implemented feature or plan. Ensure automated coverage, practical manual steps, and performance considerations.

## Inputs
- <scope>: short description of the feature/area under test
- <files>: any paths that must be tested or that changed
- <plan>: optional path to an implementation plan to derive criteria from

## Process

1) Read context fully
- Read <plan> if provided
- Read all <files> fully (no limit/offset)
- Read related modules that integrate with <files>

2) Derive testing strategy
- Identify unit, integration, and E2E layers relevant to <scope>
- Enumerate critical paths, edge cases, and failure modes
- Map success criteria from the plan to concrete checks

3) Propose test suite outline
- List files to add/update (by path)
- For each test file, specify describe blocks and key cases
- Ask for confirmation if scope is ambiguous; otherwise proceed

4) Generate tests
- Create/extend test files following repo conventions
- Prefer clear, deterministic assertions over snapshot overuse
- Include negative tests and boundary values

5) Execute checks and iterate
- Run type checks and tests
- Triage failures; fix or adjust tests as appropriate
- Re-run until green

6) Summarize results
- Report coverage summary if available
- List remaining manual steps
- Note any gaps or technical debt for follow-up

## Commands to run
- Type check: `bun run typecheck` (or repo equivalent)
- Tests: pick the project’s standard runner; if none, provide runnable minimal harness suggestions

## Output Template
```markdown
## Test Plan for: <scope>

### Strategy
- Layers: [unit/integration/e2e]
- Critical paths: [...]
- Edge cases: [...]

### Test Files
- path/to/file.test.ts
  - Cases: [..]
- path/to/another.spec.ts
  - Cases: [..]

### Execution
- Typecheck: [pass/fail]
- Tests: [pass/fail]
- Failures triage: [...]

### Manual Testing
1. Step-by-step scenario 1
2. Scenario 2 / error handling

### Coverage / Gaps
- Coverage: [if tool available]
- Known gaps: [...]
```

<scope>$ARGUMENTS</scope>

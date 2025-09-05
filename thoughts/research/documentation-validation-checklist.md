# Documentation Validation Checklist

This checklist ensures CLAUDE.md and AGENTS.md files maintain accuracy and follow best practices for AI-readable documentation.

## Pre-Commit Validation

### File Reference Validation
- [ ] **All file paths exist**: Verify every linked file actually exists in the codebase
- [ ] **Relative paths used correctly**: Project files use relative paths (`docs/FILE.md`, `src-tauri/src/FILE.rs`)
- [ ] **Absolute paths for user-global only**: Use `~/.claude/` or `~/.config/` only for user-global files
- [ ] **No broken links**: All `[text](path)` links resolve to valid locations

### Content Accuracy Validation
- [ ] **Technology stack accurate**: Verify project uses the technologies claimed in documentation
- [ ] **File structure matches reality**: Ensure directory structures and file locations are current
- [ ] **Progress percentages updated**: Current completion status reflects actual implementation
- [ ] **Command examples work**: All shell commands and code examples are valid and tested

### Cross-Reference Validation
- [ ] **Documentation consistency**: CLAUDE.md and AGENTS.md provide consistent information
- [ ] **Implementation plan alignment**: References to `thoughts/plans/` files are accurate and current
- [ ] **TODO.md synchronization**: Progress claims match actual task completion status
- [ ] **Architecture documentation**: Links to `docs/` files are relevant and up-to-date

## Content Quality Standards

### AI-Readable Structure
- [ ] **Clear hierarchical headings**: Proper H1, H2, H3 structure for AI parsing
- [ ] **Structured information**: Use bullet points and numbered lists for key information
- [ ] **Context before details**: Provide project overview before diving into specifics
- [ ] **Specific file references**: Include line numbers and specific functions where relevant

### Essential Information Completeness
- [ ] **Project type clearly stated**: Desktop app vs web app vs CLI tool explicitly identified
- [ ] **Current phase documented**: Clear statement of what's implemented vs what's missing
- [ ] **Next priorities identified**: Specific next steps with reference to implementation plans
- [ ] **Critical gaps highlighted**: Any MVP-blocking issues prominently called out

### File-Specific Validations

#### CLAUDE.md Specific
- [ ] **Claude Code specific guidance**: Content tailored for Claude Code tool usage
- [ ] **Development commands accurate**: All `cargo`, `bun`, and `npm` commands work as documented
- [ ] **Quality gates defined**: Clear pre-commit checklist and validation steps
- [ ] **Emergency procedures relevant**: Security and critical bug procedures match project needs

#### AGENTS.md Specific  
- [ ] **Multi-AI compatibility**: Content applicable across different AI systems
- [ ] **Agent role definitions**: Clear separation of concerns between different agent types
- [ ] **Workflow patterns documented**: Systematic approach to development and testing
- [ ] **Code patterns accurate**: Rust and TypeScript examples follow project conventions

## Validation Commands

### Automated Checks (Run Before Commit)
```bash
# Verify file references exist
find . -name "*.md" -exec grep -l "docs/" {} \; | xargs -I {} bash -c 'echo "Checking {}" && grep -o "docs/[^)]*" {} | while read path; do test -f "$path" || echo "BROKEN: $path"; done'

# Check project structure accuracy  
ls -la docs/ src-tauri/src/ frontend/src/pages/ # Verify directories exist

# Validate commands work
cargo --version && bun --version # Verify tools available
cargo build --dry-run # Test Rust compilation
cd frontend && bun run typecheck # Test TypeScript
```

### Manual Review Process
1. **Read as AI would**: Review documentation from AI perspective, checking for clear context
2. **Verify implementation claims**: Cross-check progress claims against actual codebase
3. **Test command examples**: Run any shell commands or code examples provided
4. **Check external references**: Ensure links to thoughts/, docs/, and external resources work

## Common Issues to Check

### Technology Stack Accuracy
- [ ] **No outdated frameworks**: Remove references to replaced or unused technologies
- [ ] **Version consistency**: Ensure version numbers match actual dependencies
- [ ] **Architecture clarity**: Clear distinction between desktop app vs web app vs CLI

### File Organization Reality
- [ ] **Actual file structure**: Documentation matches real directory organization
- [ ] **Key file identification**: Important files for development are correctly identified
- [ ] **Missing file acknowledgment**: Non-existent but planned files are clearly marked as "TBD"

### Progress and Status Accuracy
- [ ] **Completion percentages**: Progress claims match actual implementation status
- [ ] **Phase identification**: Current development phase accurately described  
- [ ] **Gap identification**: Missing critical functionality clearly highlighted
- [ ] **Next steps clarity**: Immediate priorities clearly defined with actionable tasks

## Maintenance Schedule

### Weekly Reviews
- Verify progress percentages match TODO.md status
- Check that file references remain valid after any restructuring
- Update current phase information as development progresses

### Pre-Major Milestone Reviews
- Complete full validation checklist
- Update technology stack information if dependencies changed
- Refresh file structure documentation if architecture evolved
- Verify all command examples still work

### Post-Implementation Updates
- Update completion status immediately after major features
- Add new file references for newly created components
- Remove or update any stale information about planned features

---

**Usage**: Run this checklist before committing any changes to CLAUDE.md or AGENTS.md. This prevents the accumulation of stale or inaccurate information that could mislead AI agents or developers.
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Shipworthy

## What This Is

Shipworthy is an open-source Claude Code plugin that guides AI coding sessions toward production engineering practices. All checks are advisory by default — they suggest, never block. Every rule is configurable via `.shipworthy/config.json`. v1.5.0 with 64 skills, 6 hooks, 6 agents, 8 templates, 5 adapters, 3 presets, 7 commands.

## Repository Structure

```
skills/              64 engineering skills as SKILL.md files (YAML frontmatter + Markdown)
  core/              Master router, architecture awareness, intent-to-spec
  planning/          Brainstorming, writing-plans, executing-plans, design-documents, decision-frameworks
  quality/           TDD, quality-gates, verification, error-handling, code-complexity, response-schema-validation, feedback-driven-adaptation, confidence-based-strictness
  security/          14 skills: adaptive-security, secrets, supply-chain, PII, compliance, bias-detection, vendor-risk-assessment, etc.
  architecture/      API design, database, performance, observability, resilience, 12-factor
  collaboration/     Subagent-driven-dev, parallel agents, code review
  operations/        15 skills: CI/CD, git worktrees, migrations, feature flags, incident response, context-manager, guardrail-audit-log, scope-creep-detection
  frontend/          Accessibility, frontend standards
  debugging/         Systematic debugging
  documentation/     Documentation as code
  meta/              Writing skills, retrospective
hooks/               6 bash hook scripts + shared library
  lib.sh             Shared utilities: JSON parsing, escaping, debug logging, transparency, config helpers
  session-start      SessionStart hook — tier detection, arch spec loading, transparency banner
  pre-tool-use       PreToolUse (Write|Edit) — secrets, eval, console.log suggestions (config-gated)
  pre-tool-use-bash  PreToolUse (Bash) — destructive command heads-up (config-gated)
  pre-push-validate  PreToolUse (Bash) — advisory pre-push check (blocks only in plugin repo or if user opts in)
  post-tool-use      PostToolUse (Bash) — commit, dependency, migration suggestions (config-gated)
  post-tool-use-write PostToolUse (Write|Edit) — :any, test location, route validation suggestions (config-gated)
commands/            7 slash commands (Markdown): /audit, /context, /diagnose, /health, /retro, /scaffold, /validate
agents/              6 agent personas (Markdown): code-reviewer, architecture-analyzer, security-auditor, test-strategist, project-doctor, pre-push-validator
templates/           8 architecture templates: nextjs, express, fastapi, go-service, react-spa, generic-typescript, generic-python, monorepo
adapters/            5 multi-agent adapters: cursor, copilot, codex, windsurf, gemini
presets/             3 config presets: startup.json, agency.json, enterprise.json
extensions/          Domain-specific extensions: e-commerce, fintech, healthcare
bin/shipworthy.cjs   CLI entry point (npx shipworthy init)
tests/               Test suites (14 suites, all passing)
  hooks/             Hook tests: test-session-start, test-pre-tool-use, test-post-tool-use, test-transparency
  skills/            Skill tests: test-skill-frontmatter, test-cso-format, test-cross-references, test-skill-routing, test-skill-quality, test-transparency-instructions
  security/          Security audit: test-security-audit (12 static analysis checks)
  run-all-tests.sh   Master test runner (auto-discovers test-*.sh files)
  validate-all.sh    Pre-push validation (8 checks, called by pre-push-validate hook)
site/                Landing page (GitHub Pages): index.html, og-image.html
docs/                Documentation site: getting-started/, guides/, reference/, blog/
benchmarks/          Reproducible benchmark suite with scoring scripts
```

## Key Conventions

### Skills
- Every skill is a `SKILL.md` with YAML frontmatter: `name`, `description`, `invoke_when`
- `name` must match the directory name (kebab-case)
- `description` and `invoke_when` must start with "Use when..." (CSO standard)
- Total frontmatter under 1024 characters
- Skills reference each other via `shipworthy:skill-name` syntax

### Hooks
- All hooks are bash scripts sourcing `hooks/lib.sh`
- Hooks communicate with Claude Code via JSON on stdout: `{"hookSpecificOutput":{...}}`
- Transparency logging goes to stderr (ANSI colors, `sw_log`/`sw_check`/`sw_banner` functions)
- Hooks must output valid JSON even on error (ERR trap)
- Timeouts: session-start 5s, pre/post-tool-use 3s, pre-push-validate 90s
- **Advisory-first**: all hooks suggest, never block (except pre-push-validate in the plugin repo itself)
- **Config-gated**: every check can be disabled via `rules.<name>: "off"` in `.shipworthy/config.json`
- Available rule keys: `secrets`, `eval`, `env_files`, `console_log`, `destructive_commands`, `destructive_git`, `destructive_db`, `any_types`, `test_location`, `route_validation`, `push_validation`, `commit_reminders`, `dependency_review`, `migration_review`
- Helper functions in lib.sh: `is_rule_enabled()`, `read_config_default()`, `is_ignored_path()`

### Transparency System
- Shell track: `sw_log <level> <source> <message>` writes to stderr with ANSI colors
- Instruction track: Transparency Protocol in `using-shipworthy/SKILL.md` — Claude announces skills, routing, defaults, guards
- Toggle: `SHIPWORTHY_TRANSPARENCY=0` env var or `"transparency": false` in config
- Brand prefix: `⚓ shipworthy ›` in bold cyan
- Levels: info (cyan), security (green), warn (yellow), block (red)

### Tests
- Test files follow `test-*.sh` pattern, auto-discovered by `run-all-tests.sh`
- Test helpers: `pass()`, `fail()`, `setup_temp_project()`, `cleanup()`, `validate_json()`
- Hook tests suppress stderr with `2>/dev/null` (transparency-safe)
- All tests must pass before push (enforced by pre-push-validate hook)

## Running Tests

```bash
bash tests/run-all-tests.sh           # all 14 suites
bash tests/hooks/test-transparency.sh  # single suite (any test-*.sh file works)
bash tests/validate-all.sh             # pre-push validation (8 checks)
```

## Running Benchmarks

```bash
bash benchmarks/run-benchmark.sh --task 1              # single task, both modes
bash benchmarks/run-benchmark.sh --task 1 --with-plugin # single task, with plugin only
bash benchmarks/run-benchmark.sh --all                  # all tasks, both modes
bash benchmarks/score.sh /path/to/project               # score any project directory
```

Benchmark prompts are written in **non-technical founder language** (e.g., "I need a to-do list feature") — not developer jargon. The scorer (`score.sh`) checks 25 automated criteria across build, testing, code quality, validation, architecture, and security.

## Common Workflows

### Adding a New Skill
1. Create `skills/<category>/<skill-name>/SKILL.md` with CSO-compliant frontmatter
2. Add cross-references to related skills via `shipworthy:skill-name`
3. Add transparency instruction header (follows Transparency Protocol)
4. Add routing entry in `skills/core/using-shipworthy/SKILL.md` skill selection table
5. Run `bash tests/run-all-tests.sh` — CSO format and frontmatter tests will validate

### Modifying a Hook
1. Edit the hook script in `hooks/`
2. Gate every new check with `is_rule_enabled "rule_name" "$PROJECT_ROOT"` — no ungated checks
3. Use suggestion tone ("consider", "heads up") — never prescriptive ("must", "violation")
4. Use `sw_log`/`sw_check` for transparency (they no-op if disabled)
5. Ensure JSON output on stdout is not affected
6. Run `bash tests/hooks/test-<hookname>.sh` and `test-transparency.sh`

### Adding a Command/Agent
1. Create Markdown file in `commands/` or `agents/`
2. Add transparency header (see existing files for format)
3. Run `bash tests/skills/test-transparency-instructions.sh`

## Don't

- Don't use `console.log` in any example code — use structured logging (pino, logging, slog)
- Don't use `: any` in TypeScript examples — use `unknown` with type guards
- Don't add dependencies — this is a zero-dependency project (bash + Markdown)
- Don't break JSON output from hooks — always test with `validate_json()`
- Don't write hooks that block — advisory-first (suggest, never gate)
- Don't hardcode rules without config gates — every check must be disable-able via `is_rule_enabled()`
- Don't use prescriptive language in hook messages — use "consider", "heads up", "suggestion" not "violation", "error", "must"
- Don't use relative dates in docs/learnings — always YYYY-MM-DD
- Don't skip transparency announcements in skill/command/agent files

## Version

v1.5.0 — Advisory-First Revamp (April 9, 2026)

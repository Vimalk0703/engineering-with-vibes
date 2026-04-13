# Shipworthy

> Vibe coding is how you start; engineering is what keeps it alive.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)]()
[![Benchmark: +83%](https://img.shields.io/badge/Benchmark-+83%25%20Quality-brightgreen)](BENCHMARKS.md)
[![Security Audited](https://img.shields.io/badge/Security-Audited-green)]()
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-0-brightgreen)]()

---

## The Problem

AI-assisted coding is transforming how software gets built. But the data tells a sobering story:

- **1.7x more bugs** in AI-generated code compared to human-written code (CodeRabbit, 2025)
- **40% of AI-generated code** contains security vulnerabilities
- **2026 is "the year of technical debt from vibe coding"** (Forrester)

The root cause is not the AI. It is the **absence of engineering discipline between sessions.** The AI forgets your architecture the moment the session ends. It skips tests because you did not ask for them. It introduces security holes because nobody told it your auth strategy. Every new session starts from zero.

You end up building the same feature three times: once to get it working, once to fix what it broke, and once more when you realize the fix broke something else.

## The Solution

**Shipworthy** is a Claude Code plugin that auto-activates every session and enforces production engineering practices with full transparency. It detects your project type, generates an architecture spec, and maintains it across sessions. You vibe code at full speed -- the plugin handles TDD, security, quality gates, and 64 engineering skills while showing you exactly what it's doing. No configuration, no ceremony, no workflow changes.

## Install

```bash
# Any AI agent (CLI setup — hooks + skills + quality gates)
npx shipworthy init

# Specific agent
npx shipworthy init --agent cursor
npx shipworthy init --agent copilot
npx shipworthy init --agent codex
npx shipworthy init --agent windsurf
npx shipworthy init --agent gemini
```

## Supported AI Agents

| Agent | Setup | Hooks | Skills | Quality Gates |
|-------|-------|-------|--------|--------------|
| **Claude Code** | `npx shipworthy init` | Full | Full (64) | Automated |
| **Cursor** | `npx shipworthy init --agent cursor` | Rules | Full | Manual |
| **GitHub Copilot** | `npx shipworthy init --agent copilot` | Rules | Full | Manual |
| **OpenAI Codex** | `npx shipworthy init --agent codex` | Rules | Full | Manual |
| **Windsurf** | `npx shipworthy init --agent windsurf` | Rules | Full | Manual |
| **Gemini CLI** | `npx shipworthy init --agent gemini` | Rules | Full | Manual |

## What Happens In Your First Session

That is the only setup. Here is what happens next:

1. **You open Claude Code on your project.** The plugin fires its session-start hook automatically.
2. **It detects your tech stack.** Next.js? Express? FastAPI? Go? React? Python? It knows.
3. **It generates an architecture spec.** A file at `.shipworthy/architecture.md` captures your project's conventions, mandatory rules, and structure.
4. **From now on, every session enforces those rules.** Claude remembers your architecture, your naming conventions, your patterns -- permanently.
5. **You build features normally.** Say "add a payment endpoint" and Claude automatically applies API design standards, security-first development, TDD, and quality gates. You never asked it to. It just does.
6. **Before completing, it verifies.** Tests pass, no secrets leaked, no regressions, build is clean. Evidence, not claims.

## Four Pillars

### 1. Invisible Discipline
Engineering guardrails activate automatically based on what you are doing. Writing a new feature triggers brainstorming, then planning, then TDD. Creating an API endpoint activates API design standards and security. You never invoke these manually -- they fire when relevant and stay silent when they are not.

### 2. Full Transparency
Every Shipworthy action is visible. Hooks log color-coded activity to your terminal in real time — security scans, compliance checks, push validation. Skills announce themselves before activating. Commands, agents, templates, and adapters all identify when they're contributing. You always know what Shipworthy is doing and why.

```
┌─ ⚓ shipworthy ─────────────────────────────┐
│  Tier: ENGINEER  │  Health: all passed       │
│  Skills: 55      │  Hooks: 6 active          │
└──────────────────────────────────────────────┘
⚓ shipworthy  14:32:05  pre-tool-use  ›  Scanning: service.ts
⚓ shipworthy  14:32:05  pre-tool-use  ›  All checks passed ✓
```

> ⚓ **shipworthy** › skill: `api-design-standards` + `security-first-development` — designing secure endpoint

Toggle off with `SHIPWORTHY_TRANSPARENCY=0` or `"transparency": false` in `.shipworthy/config.json`.

### 3. Architecture as Memory
The architecture spec is Claude's long-term memory for your project. Mandatory rules, directory conventions, naming patterns, tech choices -- all persisted and enforced. Session 5 knows everything session 1 decided. No more "Claude forgot we use Prisma" or "it put the route in the wrong directory again."

### 4. Cross-Session Memory
Inspired by production agent memory architectures, Shipworthy manages a `.shipworthy/` directory as persistent project memory:

- **INDEX.md** -- auto-generated index of all project memory, refreshed every session. Survives context compaction so Claude can rediscover what the project knows mid-conversation.
- **Learnings with frontmatter** -- retrospective findings are saved with `description` and `last_updated` fields. The description feeds into INDEX.md for one-line scanning without reading full files.
- **Dedup guard** -- before writing a new learning, the retrospective checks existing files. Same topic = update, not duplicate.
- **Memory consolidation** -- when learnings exceed 5 files or sessions exceed 10, `/retro` offers to merge duplicates, prune stale entries, fix relative dates, and remove facts contradicted by current code.
- **Session pruning** -- keeps the 10 most recent session summaries, deletes older ones. Valuable patterns from old sessions should already be captured in learnings via retrospectives.
- **Absolute dates everywhere** -- all timestamps use `YYYY-MM-DD`, never "yesterday" or "last week". Relative dates become meaningless across sessions.

### 5. Graduated Rigor
A weekend prototype should not face the same ceremony as an enterprise platform. The plugin scales its enforcement: lightweight checks for small projects, full quality gates as your codebase grows. You start fast and the guardrails tighten as complexity demands it.

## User Experience Tiers

| Tier | Who | Experience |
|------|-----|-----------|
| **Builder** | Non-technical, prototyping | Guardrails are silent. Tests happen invisibly. Plain language feedback when something needs attention. |
| **Maker** | Some experience, growing project | Moderate ceremony. Explains why tests matter. Offers choices on architecture decisions. |
| **Engineer** | Production codebase, CI/CD | Full TDD, quality gates, architecture enforcement. Every PR is verified before completion. |

## Security

v1.4.1 includes a comprehensive security audit of every file in the repository. All 64 skills, 6 hooks, 8 templates, 6 agents, 5 adapters, and the CLI entry point were audited for code injection, data exfiltration, unsafe operations, and supply chain risks.

**Audit results:**
- 6 Python code injection sites in hooks -- **fixed** (shell variables no longer interpolated into code strings)
- 1 TOCTOU race condition in session markers -- **fixed** (moved to user-owned directory with hashed names)
- 1 command injection in CLI -- **fixed** (replaced shell template literal with array arguments)
- 12 automated security tests run on every push (no network requests, no obfuscated code, no secrets, no unsafe /tmp, safe permissions, zero dependencies)
- All skills, templates, agents, commands, adapters, and presets: **clean**

See [RELEASE-NOTES.md](RELEASE-NOTES.md) for full details.

## Skills (64)

### Core (3)
| Skill | What It Does |
|-------|-------------|
| **using-shipworthy** | Master routing skill -- loaded at every session start. Defines skill priority and routing. |
| **architecture-awareness** | Auto-detects project type, generates and enforces architecture spec |
| **intent-to-spec** | Converts vague requests into detailed specs (invisible for Builder, shown for Engineer) |

### Planning (5)
| Skill | What It Does |
|-------|-------------|
| **brainstorming** | 5-step design discovery with HARD-GATE approval before proceeding |
| **writing-plans** | Breaks work into bite-sized TDD implementation plans with HARD-GATE |
| **executing-plans** | Systematic task execution with verification at each step |
| **design-documents** | Creates Architecture Decision Records (ADRs) |
| **decision-frameworks** | Structured decision-making for trade-offs |

### Quality (8)
| Skill | What It Does |
|-------|-------------|
| **test-driven-development** | RED-GREEN-REFACTOR discipline for every feature |
| **quality-gates** | Graduated pre-commit checks that scale with project size |
| **verification-before-completion** | Requires evidence (passing tests, clean build) before marking work done |
| **error-handling-patterns** | Structured errors, recovery strategies, and user-facing messages |
| **code-complexity** | Identifies and refactors complex code |
| **response-schema-validation** | Enforces schema validation on every API response before reaching clients |
| **feedback-driven-adaptation** | Adapts guardrail enforcement dynamically based on user signals and project trajectory |
| **confidence-based-strictness** | Scales verification depth based on uncertainty — routine CRUD vs crypto/financial code |

### Security (14)
| Skill | What It Does |
|-------|-------------|
| **security-first-development** | OWASP-aware coding -- input validation, auth, secrets management |
| **adaptive-security** | Auto-detects app type (web/API/GraphQL/mobile/CLI/IoT/desktop/IaC/container) and applies type-specific security profiles |
| **secrets-management** | Comprehensive lifecycle: rotation, vault integration, leak detection |
| **dependency-management** | Vet, audit, and pin packages before adding them |
| **supply-chain-security** | Lock file integrity, typosquatting detection, SBOM, license compliance |
| **pii-detection** | Identifies and protects personally identifiable data |
| **threat-modeling** | Structured threat analysis |
| **compliance-awareness** | HIPAA, PCI-DSS, SOC2, GDPR guidance |
| **container-security** | Docker/container-specific hardening |
| **bias-detection** | Flags discriminatory logic in scoring, pricing, ranking, and access control code |
| **vendor-risk-assessment** | Evaluates third-party services with 3-tier framework before adoption |

### Architecture (9)
| Skill | What It Does |
|-------|-------------|
| **api-design-standards** | REST conventions, type-safe contracts, consistent error responses |
| **database-design** | Schemas, migrations, indexing, N+1 prevention |
| **performance-budgets** | Bundle size limits, response time targets, query count caps |
| **observability-by-default** | Structured logging, tracing, health checks from day one |
| **resilience-patterns** | Circuit breakers, bulkheads, retries, timeouts, graceful degradation |
| **twelve-factor-app** | Stateless design, env config, backing services |
| **distributed-systems** | Multi-service coordination, eventual consistency |
| **api-versioning** | Breaking change management |
| **api-backward-compatibility** | Non-breaking API evolution |

### Collaboration (4)
| Skill | What It Does |
|-------|-------------|
| **subagent-driven-development** | Dispatch specialized agents with 2-stage review |
| **dispatching-parallel-agents** | Run independent tasks concurrently for speed |
| **requesting-code-review** | Structured review via the code-reviewer agent |
| **receiving-code-review** | Technical verification over performative agreement |

### Operations (15)
| Skill | What It Does |
|-------|-------------|
| **environment-setup** | Auto-generates .env.example and validates environment configuration |
| **session-memory** | Cross-session memory system for specs, decisions, and plans |
| **tech-debt-tracking** | Document shortcuts so they get fixed, not forgotten |
| **feature-flag-discipline** | Manage feature flags with expiration dates and kill switches |
| **ci-cd-awareness** | Pipeline design, rollback strategies, and feature flags |
| **using-git-worktrees** | Isolated workspaces for parallel development branches |
| **finishing-a-development-branch** | 5-step completion workflow: tests, cleanup, docs, PR, verify |
| **tech-debt-tracking** | Document shortcuts so they get fixed, not forgotten |
| **session-memory** | Cross-session persistence via `.shipworthy/` with INDEX.md, pruning, and consolidation |
| **production-readiness** | Pre-deployment checklist |
| **migration-strategies** | Database migration safety |
| **zero-downtime-migrations** | Gradual migration patterns |
| **environment-setup** | Local, staging, production configuration |
| **feature-flag-discipline** | Gradual rollout, kill switches |
| **incident-response** | Outage response procedures |
| **slo-sli-definition** | Service level objectives and indicators |
| **context-manager** | Manages context budget across skills, prevents context window overflow |
| **scope-creep-detection** | Detects when tasks expand beyond original boundaries, gets explicit approval |
| **guardrail-audit-log** | Immutable, append-only audit trail for all guardrail events |

### Frontend (2)
| Skill | What It Does |
|-------|-------------|
| **accessibility** | WCAG 2.1 AA baseline for every UI component |
| **frontend-standards** | Component patterns, state management, and rendering best practices |

### Documentation (1)
| Skill | What It Does |
|-------|-------------|
| **documentation-as-code** | JSDoc, README sync, ADRs, and changelog maintenance |

### Debugging (1)
| Skill | What It Does |
|-------|-------------|
| **systematic-debugging** | 4-phase root cause investigation: reproduce, isolate, fix, verify |

### Meta (2)
| Skill | What It Does |
|-------|-------------|
| **writing-skills** | TDD for documentation -- create new skills using the RED-GREEN-REFACTOR process |
| **retrospective** | Self-improving loop -- extracts signals from each session, saves learnings, consolidates memory |

## Graduated Quality Gates

| Level | Threshold | What Gets Checked |
|-------|-----------|-------------------|
| **0** | Any project | Build runs, no obvious errors (Builder-friendly) |
| **1** | Always | Tests pass, build clean, no hardcoded secrets |
| **2** | 10+ files | Coverage > 70%, no untracked TODOs, lint clean |
| **3** | 50+ files | Bundle budgets enforced, no circular imports, API contracts validated |
| **4** | 100+ files | Performance benchmarks, accessibility audit, security scan, dependency audit |

## Architecture Templates (8)

Pre-built architecture specs for common stacks. The plugin selects the right one automatically, or you can run `/scaffold` to choose.

| Template | Stack |
|----------|-------|
| `nextjs.md` | Next.js (App Router, Server Components, API Routes) |
| `express.md` | Express.js (REST API, middleware patterns) |
| `fastapi.md` | FastAPI (Python async API, Pydantic models) |
| `go-service.md` | Go (standard library HTTP, clean architecture) |
| `react-spa.md` | React SPA (client-side routing, state management) |
| `generic-typescript.md` | TypeScript (general-purpose, library or CLI) |
| `generic-python.md` | Python (general-purpose, scripts or packages) |
| `monorepo.md` | Monorepo (multi-package, shared dependencies) |

## Agents (6)

Specialized AI personas dispatched by skills for focused review:

| Agent | Role |
|-------|------|
| **code-reviewer** | Line-by-line review for correctness, style, and maintainability |
| **architecture-analyzer** | Validates structural decisions against the architecture spec |
| **security-auditor** | Scans for vulnerabilities, secrets, auth gaps, injection risks |
| **test-strategist** | Evaluates test coverage, suggests missing test cases, reviews test quality |
| **project-doctor** | Infrastructure gap analysis with auto-fix recommendations |
| **pre-push-validator** | Runs 8-check validation suite (hooks, frontmatter, CSO, routing, cross-refs, quality, structure, security) |

## Commands

| Command | What It Does |
|---------|-------------|
| `/scaffold` | Generate or regenerate the architecture specification for your project |
| `/audit` | Run a full quality audit across all dimensions (tests, security, architecture, performance) |
| `/health` | Quick project health dashboard -- see where you stand at a glance |
| `/diagnose` | Infrastructure gap analysis with auto-fix options via project-doctor agent |
| `/retro` | Run a retrospective -- extract signals, save learnings, consolidate memory |
| `/validate` | Pre-push validation gate -- runs the full 8-check suite before pushing |

## Before and After

**Without Shipworthy:**
- Session 1: Build auth. Works great.
- Session 2: Build payments. Breaks auth. Claude forgot the auth middleware pattern.
- Session 3: Fix auth. Break payments. No tests to catch the regression.
- Ship: Security vulnerabilities, no tests, hardcoded secrets, inconsistent API responses.

**With Shipworthy:**
- Session 1: Build auth. Architecture spec generated. Tests written automatically. Auth patterns documented.
- Session 2: Build payments. Architecture rules prevent breaking auth. Security skill catches missing input validation.
- Session 3: Add features. Quality gates catch issues before you see them. Tech debt is tracked, not hidden.
- Ship: Tested, secure, documented, production-ready.

## Benchmark Results

We tested the plugin with an unbiased benchmark: same prompt, same starter project, scored by 15 automated checks. The only variable is whether the plugin is loaded.

**Task 01 — Build a REST API with CRUD (Express + TypeScript):**

| | With Plugin | Without Plugin |
|---|---|---|
| **Score** | **22/25 (A)** | **12/25 (C)** |
| Tests | 22 tests, all passing | 0 tests |
| Input validation | Zod schemas | Manual if/else |
| Error handling | 3 structured error types | 1 basic class |
| Architecture | 8 files, separated concerns | 5 files, simpler |

**+83% score improvement.** The plugin's TDD skill drove test creation, the security skill enforced Zod validation, and the API design skill produced proper status codes and error formatting.

Full methodology, all 10 task definitions, and reproducible benchmark scripts: [BENCHMARKS.md](BENCHMARKS.md)

```bash
# Run benchmarks yourself
cd benchmarks && ./run-benchmark.sh --task 1 --both
```

## Contributing

We welcome contributions. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on writing new skills, adding templates, proposing agents, and submitting pull requests.

**Good first contributions:** add a new architecture template, improve a skill's edge case coverage, or add code examples to existing skills.

---

If this plugin helps you ship production-quality code, consider giving it a star.

## License

[MIT](LICENSE)

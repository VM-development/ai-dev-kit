# ai-dev-kit

One `AGENTS.md` configures **Claude Code** (Claude), **OpenAI Codex** (GPT), and the
**GitHub Copilot** cloud agent for a project — shared standards, native slash commands,
a code knowledge graph (graphify), and optional tools. The agent CLIs you use are
assumed already installed (the script verifies them; it does install graphify + Superpowers).

## Install

Run **inside the project you want to configure**:

```bash
# Core — prompts you through which agents + tools to enable
curl -fsSL https://raw.githubusercontent.com/VM-development/ai-dev-kit/main/bootstrap.sh | bash

# Core + all optional tools (ast-grep, Grep MCP, private-journal, Claude guardrail hooks)
curl -fsSL https://raw.githubusercontent.com/VM-development/ai-dev-kit/main/bootstrap.sh \
  | bash -s -- --with-all-extras
```

Non-interactive: append `bash -s -- --yes --agents=claude,codex,copilot`. All flags: `./setup.sh --help`.

## Edit after install

Everything you customize lives in **one file — `AGENTS.md`**. Fill in every `{{…}}`; all
three agents read it. This is where your code standards, check tools, and PR/commit formats go:

| What you set | Section in `AGENTS.md` | Placeholder(s) |
|---|---|---|
| Project overview / tech stack          | top                         | `{{PROJECT_OVERVIEW}}`, `{{TECH_STACK}}` |
| **Code standards** + formatter         | Standards → Code            | `{{CODE_STANDARDS}}`, `{{FORMAT_COMMAND}}` |
| **Commit message format**              | Standards → Commit messages | `{{COMMIT_STANDARDS}}` |
| **PR rules + description format**       | Standards → Pull requests   | `{{PR_STANDARDS}}`, `{{PR_DESCRIPTION_FORMAT}}` |
| **Code-check tools** (lint/type/security) | Standards → Static analysis | `{{LINT_COMMAND}}`, `{{TYPECHECK_COMMAND}}`, `{{SECURITY_SCAN_COMMAND}}` |
| **Test command** + coverage target     | Standards → Tests           | `{{TEST_COMMAND}}`, `{{COVERAGE_TARGET}}` |
| Real device / environment              | Standards → Real device     | `{{REAL_DEVICE_NOTES}}`, `{{REAL_DEVICE_TEST_SCRIPT}}`, `{{REAL_DEVICE_PREREQS}}` |
| Extra guardrails                        | Guardrails                  | `{{EXTRA_GUARDRAILS}}` |

**Only edit one other file — and only if you use the Copilot *cloud* agent:**
`.github/workflows/copilot-setup-steps.yml` — replace the TODO with your real toolchain +
the lint/test installs, then commit it to the **default branch**.

Everything else is generated and managed for you — leave it alone:
`CLAUDE.md`, `.claude/`, `.codex/config.toml`, `.github/copilot-instructions.md`, and the
slash-command files.

## Then
1. **Codex:** open the project once and **trust** it (so `.codex/config.toml` loads); restart Codex to load the `/prompts:*` commands.
2. **Copilot:** pick the model in the task model-picker.
3. After code changes: `graphify update .`

## Tools & extras
**graphify** and **Superpowers** are offered by default (you're prompted); the four extras are
opt-in via their flag — or all at once with `--with-all-extras` — and every one is reversible by `uninstall.sh`.

| Tool | What it does | Enable |
|---|---|---|
| **graphify** | Queryable **code knowledge graph** — agents recall architecture instead of grepping (`graphify query "…"`; refresh with `graphify update .`) | default |
| **Superpowers** | Dev-methodology plugin for **Claude Code** (brainstorm → plan → TDD → review); Codex/Copilot follow the same flow via `AGENTS.md` | default |
| **ast-grep** | **Structural (AST) search + safe codemods**, many languages, 100% local | `--with-ast-grep` |
| **Grep MCP** | Search **~1M public GitHub repos** for real-world usage — grounds the agent, avoids hallucinated APIs | `--with-grep` |
| **private-journal** | **Local cross-session memory** (on-device embeddings; nothing leaves your machine) | `--with-journal` |
| **Claude hooks** | **Deterministic guardrails** (Claude only): auto-block reading secrets + dangerous shell (`rm -rf /`, `curl \| sh`) | `--with-hooks` |

MCP servers (Grep, private-journal) are written into each enabled agent's config; security review needs **no API key** (use `/security-audit`, or Claude's built-in `/security-review`).

## Reference
- **Slash commands** (where enabled): `/pr-review`, `/deep-test`, `/security-audit` (no API key), `/progress-report`, `/repeatable-task`. Codex uses `/prompts:<name>`.
- **Options & conflict handling:** `./setup.sh --help`. Re-running is safe (idempotent; tracked in `.ai-dev-kit-manifest`); `AGENTS.md` is never overwritten.
- **Uninstall:** `~/.ai-dev-kit/uninstall.sh .` (add `--dry-run` to preview) — restores backups, removes only kit files, strips kit `.gitignore`/MCP/hook entries.
- **Docs:** [how each agent reads its config](docs/single-source-of-truth.md) · [design](docs/DESIGN.md) · [tool catalog](docs/related-tools.md) · [QA test plan](docs/test-plan.html).

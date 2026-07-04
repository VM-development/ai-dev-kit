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
| **Code-review rubric** (priorities, severity, merge gates) | Standards → Code review | `{{REVIEW_STANDARDS}}`, `{{REVIEW_MERGE_GATES}}` |
| **Code-check tools** (lint/type/security) | Standards → Static analysis | `{{LINT_COMMAND}}`, `{{TYPECHECK_COMMAND}}`, `{{SECURITY_SCAN_COMMAND}}` |
| **Test command** + coverage target     | Standards → Tests           | `{{TEST_COMMAND}}`, `{{COVERAGE_TARGET}}` |
| Real device / environment              | Standards → Real device     | `{{REAL_DEVICE_NOTES}}`, `{{REAL_DEVICE_TEST_SCRIPT}}`, `{{REAL_DEVICE_PREREQS}}` |
| Extra guardrails                        | Guardrails                  | `{{EXTRA_GUARDRAILS}}` |

**Only edit one other file — and only if you use the Copilot *cloud* agent:**
`.github/workflows/copilot-setup-steps.yml` — replace the TODO with your real toolchain +
the lint/test installs, then commit it to the **default branch**.

**Share vs. local — `.gitignore`.** Your agent config (`AGENTS.md`, `.claude/`, `.codex/`,
`.github/`, slash commands) is committed by default, so the whole team shares one setup. To
*also* commit something the kit ignores — e.g. the code graph, so teammates/CI/the cloud agent
get it without rebuilding — remove its line from the managed block and force-add it:
`git add -f graphify-out/`. The `-f` is what makes it stick: tracked files override `.gitignore`
and survive `setup.sh` re-runs (which regenerate the managed block). Keep `*.local.*`,
`.claude/settings.local.json`, `*.adk-bak`, `.ai-dev-kit-manifest`, `.ai-dev-kit-mcp`, and
`.private-journal/` ignored — those are personal/local.

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
| **[ponytail](https://github.com/DietrichGebert/ponytail)** | Lazy-senior-dev skill — agent writes **minimal code** (YAGNI; stdlib/native before deps; one line before fifty), cross-agent | plugin (all 3 agents) |
| **ast-grep** | **Structural (AST) search + safe codemods**, many languages, 100% local | `--with-ast-grep` |
| **Grep MCP** | Search **~1M public GitHub repos** for real-world usage — grounds the agent, avoids hallucinated APIs | `--with-grep` |
| **private-journal** | **Local cross-session memory** (on-device embeddings; nothing leaves your machine) | `--with-journal` |
| **Claude hooks** | **Deterministic guardrails** (Claude only): auto-block reading secrets + dangerous shell (`rm -rf /`, `curl \| sh`) | `--with-hooks` |

MCP servers (Grep, private-journal) are written into each enabled agent's config; security review needs **no API key** (use `/security-audit`, or Claude's built-in `/security-review`). **ponytail** isn't wired into `setup.sh` — install it from each agent's plugin marketplace: `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail` (Claude Code; `codex` / `copilot` use the same subcommands).

## Example prompt — a feature through every tool
Drive one feature through graphify, Grep MCP, ast-grep, the workflow, and private-journal
(full walk-through: [docs/example-prompt.md](docs/example-prompt.md)):

```text
Implement <feature> and follow our
workflow — don't jump straight to code.
1. Orient (graphify). graphify query "how do incoming HTTP requests flow and where is
   middleware registered" + graphify path "<router>" "<handler>" → integration points.
2. Prior art (Grep MCP). Search public repos for real rate-limiter middleware in our
   language (token-bucket / sliding-window); show 2-3 examples + trade-offs.
3. Survey our code (ast-grep). ast-grep -p 'app.use($M)' -l ts (adapt) → every call site.
4. Decide + record (private-journal). Pick algorithm/config; record the decision AND why.
5. Plan + build (workflow). Failing test first → implement → wire in → run test/lint/
   typecheck from AGENTS.md → self-review vs Standards.
6. Wrap up. Summarize, graphify update ., report what you journaled. Don't push.
```

## Reference
- **Slash commands** (where enabled): `/pr-review`, `/deep-test`, `/security-audit` (no API key), `/progress-report`, `/repeatable-task`, `/report-html`. Codex uses `/prompts:<name>`.
- **HTML reports/plans:** ask any report/plan command for HTML — or run `/report-html <topic|file>` — for a styled, self-contained `.html` (Catppuccin Mocha) under `docs/reports/`. The house style lives in `AGENTS.md` → Output formats.
- **Options & conflict handling:** `./setup.sh --help`. Re-running is safe (idempotent; tracked in `.ai-dev-kit-manifest`); `AGENTS.md` is never overwritten.
- **Uninstall:** `~/.ai-dev-kit/uninstall.sh .` (add `--dry-run` to preview) — restores backups, removes only kit files, strips kit `.gitignore`/MCP/hook entries.
- **Docs:** [worked example — a feature through every tool](docs/example-prompt.md) · [how each agent reads its config](docs/single-source-of-truth.md) · [design](docs/DESIGN.md) · [tool catalog](docs/related-tools.md) · [QA test plan](docs/test-plan.html).

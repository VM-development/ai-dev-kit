# ai-dev-kit

Bootstrap any project for AI-assisted development across **Claude Code** (Claude
models), **OpenAI Codex** (GPT models), and the **GitHub Copilot** cloud agent
(any model) — from one shared set of files.

One `AGENTS.md` drives all three agents. The setup script verifies the agent CLIs
you choose are present, optionally installs [Superpowers](docs/superpowers.md) per
agent, installs [graphify](https://pypi.org/project/graphifyy/) and builds a code
knowledge graph, and scaffolds each agent's native config plus a set of reusable
**slash commands** (`/pr-review`, `/progress-report`, `/deep-test`,
`/repeatable-task`).

> **Prerequisites:** the Claude Code, Codex, and/or Copilot CLIs you plan to use
> are assumed already installed — the script verifies them and warns if one is
> missing, but does not install them. It *does* install graphify (+ `uv`) and the
> Superpowers plugins.

## Quickstart

**From inside the project you want to configure:**

```bash
# Option A — clone and run
git clone https://github.com/VM-development/ai-dev-kit ~/.ai-dev-kit
~/.ai-dev-kit/setup.sh .

# Option B — one-liner (clones to ~/.ai-dev-kit, then configures the current dir)
curl -fsSL https://raw.githubusercontent.com/VM-development/ai-dev-kit/main/bootstrap.sh | bash

# Option B + all optional tools (ast-grep, Grep MCP, private-journal, Claude hooks)
curl -fsSL https://raw.githubusercontent.com/VM-development/ai-dev-kit/main/bootstrap.sh | bash -s -- --with-all-extras
```

> Passing flags through `curl … | bash`: use **`bash -s -- <flags>`** (the script is on
> stdin, so `-s --` forwards the flags to it). `bash --with-all-extras` alone would be
> read by bash itself, not the script.

You'll be asked which agents to enable, which models to default to, and whether to
install Superpowers and build the graph. Non-interactive:

```bash
~/.ai-dev-kit/setup.sh . --yes --agents=claude,codex,copilot \
  --claude-model=claude-opus-4-8 --codex-model=gpt-5.5 --no-graphify
```

> Update `VM-development/ai-dev-kit` to your own fork/repo, and adjust the model
> defaults in `setup.sh` as model lineups change.

## What it writes into your project

| File | For | Purpose |
|---|---|---|
| `AGENTS.md`                                   | all      | **Single source of truth** (you fill it in) |
| `CLAUDE.md`                                   | Claude   | `@AGENTS.md` import + managed notes |
| `.claude/settings.json`                       | Claude   | model + schema |
| `.codex/config.toml`                          | Codex    | model + reasoning effort |
| `.github/copilot-instructions.md`             | Copilot  | pointer to `AGENTS.md` |
| `.github/workflows/copilot-setup-steps.yml`   | Copilot  | cloud-agent environment |
| `.claude/commands/*.md`                       | Claude   | slash commands → `/pr-review` … |
| `.github/prompts/*.prompt.md`                 | Copilot  | IDE-chat prompts → `/pr-review` … |
| `~/.codex/prompts/*.md`                        | Codex    | **user-global** prompts → `/prompts:pr-review` … |
| `.gitignore` (appended)                       | —        | ignores `graphify-out/`, `*.local.*`, backups |

The Standards (code/commit/PR rules, static-analysis tools, tests, real-device
script) live in the **`AGENTS.md`** Standards section — fill them in there, in one
place, and every tool and command picks them up.

> **Commands by tool.** Claude Code: `/pr-review` (`.claude/commands/`). Copilot:
> `/pr-review` in **IDE chat** (`.github/prompts/` — the Copilot *cloud* agent does
> not read prompt files; it follows `AGENTS.md`). Codex: `/prompts:pr-review`
> (installed **user-globally** to `~/.codex/prompts/`; restart Codex to see them).

See [`docs/single-source-of-truth.md`](docs/single-source-of-truth.md) for exactly
how each agent reads its config, [`docs/DESIGN.md`](docs/DESIGN.md) for the full
design, and [`docs/related-tools.md`](docs/related-tools.md) for a vetted catalog of
extra tools (graphify/Superpowers-class) you can add.

## After setup
1. Fill in `AGENTS.md`, including its **Standards** section (code/commit/PR rules,
   tools, tests, real-device script). The commands reference it.
2. Codex: open the project once and **trust** it so `.codex/config.toml` loads.
3. Copilot: commit `copilot-setup-steps.yml` to the **default branch**; pick the
   model in the task model-picker.
4. After code changes: `graphify update .`

## What each tool does

| Tool | What it is | Typical use | Set up by |
|---|---|---|---|
| **graphify** | A queryable **code knowledge graph** of your repo (relationships/architecture) — recall instead of grepping | `graphify query "how does auth work"` to orient before editing; `graphify update .` after changes | default (prompted) |
| **Superpowers** | A **dev-methodology** plugin for Claude Code: brainstorm → plan → TDD → review | Ask for a feature and it clarifies, plans, and writes tests first instead of dumping code | default (prompted) |
| **Slash commands** | `pr-review`, `progress-report`, `deep-test`, `repeatable-task`, `security-audit` | `/pr-review 42` · `/deep-test src/api` · `/security-audit` (no API key) | always |
| **ast-grep** | **Structural (AST) search + safe codemods**, many languages; 100% local | Bulk-rewrite a call pattern repo-wide (`ast-grep -p '…' -r '…' -l ts`); find matches regex can't express | `--with-ast-grep` |
| **Grep MCP** | Search **~1M public GitHub repos** for real-world usage examples | "find real examples of `<API>`" — grounds the agent, avoids hallucinated APIs | `--with-grep` |
| **private-journal** | **Local cross-session memory** (on-device embeddings, nothing leaves the machine) | "record in your journal: we chose X because Y" → recall it in a later session | `--with-journal` |
| **Claude hooks** | **Deterministic guardrails** (Claude only) | Auto-block reading `.env`/secrets and dangerous shell commands (`rm -rf /`, `curl \| sh`) | `--with-hooks` |

graphify + Superpowers are the always-offered core; the rest are opt-in. Setup prints
this same "what / config / use" blurb as it installs each one.

## Optional tools (opt-in)
The extras above (ast-grep, Grep MCP, private-journal, Claude hooks) are enabled by
their `--with-*` flag or the setup prompt — or all at once with **`--with-all-extras`**;
all are reversible by `uninstall.sh`. MCP servers are written into each enabled
agent's config (`.mcp.json` / `.codex/config.toml` / `.vscode/mcp.json`). Security
review needs **no API key** — use the cross-agent `/security-audit` command (always
installed) or Claude's built-in `/security-review`, both on your existing plan. See
[`docs/related-tools.md`](docs/related-tools.md) for the full vetted catalog.

## Options
`setup.sh [TARGET_DIR] [--agents=…] [--claude-model=…] [--codex-model=…]
[--codex-reasoning=…] [--superpowers|--no-superpowers] [--no-graphify]
[--gitignore|--no-gitignore] [--on-conflict=prompt|backup|skip|overwrite]
[--with-ast-grep] [--with-grep] [--with-journal] [--with-hooks]
[--with-all-extras] [--no-extras] [-y|--yes] [--quiet] [--dry-run]`. Run `./setup.sh --help`.

## Existing files (conflict handling)
Re-running is safe: files the kit created before are updated in place (tracked in
`.ai-dev-kit-manifest`). If a file the kit would write **already exists and you
created it**, `--on-conflict` decides what happens:

| Policy | Behavior |
|---|---|
| `prompt` (default) | Ask per file. `--yes` treats this as `backup`. |
| `backup` | Save your copy to `<file>.adk-bak`, then write the kit version (restorable). |
| `skip` | Keep yours; don't write the kit version. |
| `overwrite` | Replace yours with no backup. |

`AGENTS.md` is never overwritten (it's yours); `CLAUDE.md` is merged
(your content is preserved below the `@AGENTS.md` import).

## Uninstall
Reverse everything the kit added to a project:
```bash
~/.ai-dev-kit/uninstall.sh .            # restores backups, removes kit files, cleans .gitignore
~/.ai-dev-kit/uninstall.sh . --dry-run  # preview
~/.ai-dev-kit/uninstall.sh . --with-superpowers --with-graphify   # also remove the global tools
```
It restores any `*.adk-bak` (your originals), removes only files in the manifest,
strips the kit's `.gitignore` block (leaving your lines), and removes the kit's
global Codex prompts (only those it created). It also **strips the kit's MCP server
entries** from `.mcp.json` / `.codex/config.toml` / `.vscode/mcp.json` (deleting those
files only if nothing else remains — your own servers are kept), removes the
guardrail-hook entries from `.claude/settings.json`, and **deletes `graphify-out/`**.
Without a manifest it does a best-effort, ownership-safe cleanup that never blind-deletes
a file it can't prove it created. `--with-superpowers` / `--with-graphify` additionally
remove those global tools.

## Safe to re-run
Installs are gated on `command -v`; generated content lives in marker blocks that
are replaced (not duplicated). Try `./setup.sh . --dry-run` to preview.

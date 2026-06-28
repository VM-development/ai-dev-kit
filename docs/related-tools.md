# Related tools — vetted catalog

Tools in the spirit of **graphify** (codebase intelligence) and **Superpowers**
(dev methodology) that fit ai-dev-kit's model: installable per agent
(Claude Code / Codex / Copilot), cross-agent where possible.

> Verified mid-2026 against primary sources (each tool's own repo / docs). The kit
> already integrates [graphify](https://pypi.org/project/graphifyy/),
> [Superpowers](https://github.com/obra/superpowers), and the
> [AGENTS.md](https://agents.md/) standard.

**Now wired into setup as opt-in flags** (reversible via `uninstall.sh`):
`--with-ast-grep`, `--with-grep` (Grep MCP), `--with-journal` (private-journal),
and `--with-hooks` (Claude guardrails); plus an always-installed cross-agent
`/security-audit` command (no API key). **Context7** and **Serena** are *not* wired —
add them manually if wanted. (Serena was evaluated and dropped: it overlaps graphify
on references, and the uv+Python+per-language-LSP footprint wasn't worth it here.)
Everything else below is reference/optional.

**Fit legend:** ⭐ strong add · ◯ optional/opt-in · ⛔ skip (why).

## ⭐ Strong adds — cross-agent, current, fill real gaps

| Tool | What it adds | Install | Agents |
|---|---|---|---|
| [Context7 MCP](https://github.com/upstash/context7) | Up-to-date, version-specific library docs/API examples injected at runtime — kills outdated/hallucinated APIs | Remote MCP URL `https://mcp.context7.com/mcp` (no install) | all (MCP) |
| [ast-grep](https://github.com/ast-grep/ast-grep) | AST/structural code search + safe codemods that text-grep can't express | `brew install ast-grep` · `npm i -g @ast-grep/cli` · `pip install ast-grep-cli` | all (CLI) |
| [Serena](https://github.com/oraios/serena) *(not wired — removed)* | LSP-backed semantic symbol nav + precise cross-file edits (40+ langs) — live intelligence vs. graphify's static graph | manual: `uvx --from git+https://github.com/oraios/serena serena-mcp-server` as an MCP entry (heaviest: uv+Python+LSP) | all (MCP) |
| [claude-code-security-review](https://github.com/anthropics/claude-code-security-review) | Diff-aware semantic vuln scan on PRs (first-party) | GitHub Action `anthropics/claude-code-security-review` | CI (needs `CLAUDE_API_KEY`; local `/security-review` uses Max instead) |

## ◯ Codebase intelligence / context (opt-in)

| Tool | What it adds | Install |
|---|---|---|
| [Repomix](https://github.com/yamadashy/repomix) | Pack a whole repo (local or remote) into one token-counted file for one-shot prompts | `npm i -g repomix` · `npx repomix` · `brew install repomix` |
| [Gitingest](https://github.com/coderamp-labs/gitingest) | Dump a *remote* GitHub repo into a prompt-friendly digest (graphify is local-only) | `pip install gitingest` → `gitingest <path-or-url>` |
| [Probe](https://github.com/probelabs/probe) | Local, embedding-free on-demand AST block retrieval for very large repos | `npx -y @probelabs/probe@latest mcp` |
| [CodeGraphContext](https://github.com/CodeGraphContext/CodeGraphContext) | Live MCP code-graph (tree-sitter) with file-watch re-index | `pip install codegraphcontext` → `codegraphcontext mcp setup` |
| [Grep MCP](https://mcp.grep.app) (Vercel) | Search code across ~1M public GitHub repos ("how is lib X used in the wild") | `claude mcp add --transport http grep https://mcp.grep.app` (no key) |

## ◯ Cross-agent infrastructure (opt-in)

| Tool | What it adds | Install |
|---|---|---|
| [rulesync](https://github.com/dyoshikawa/rulesync) | Generate/sync native rule + MCP + command files for 30+ tools from one source — could *replace* the kit's hand-wired fan-out | `npm i -g rulesync` → `rulesync generate` |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Official spec-driven dev (constitution→specify→plan→tasks→implement) across ~37 agents | `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git` |
| [GitHub MCP Server](https://github.com/github/github-mcp-server) | Structured PR/issue/CI/security access from inside the agent (overlaps `gh`) | `claude mcp add github …` (needs PAT) or hosted remote |
| [Anthropic official marketplace](https://github.com/anthropics/claude-plugins-official) | Curated Claude Code plugins (pr-review-toolkit, commit-commands, …) | auto-available; `/plugin install <name>@claude-plugins-official` (Claude only) |
| [wshobson/agents](https://github.com/wshobson/agents) | Large multi-harness agent/skill marketplace; reimplements "one source → many agents" | `/plugin marketplace add wshobson/agents` (Claude/Codex/…) |

## ◯ Memory / context persistence (pick **one**)

| Tool | What it adds | Install |
|---|---|---|
| [private-journal-mcp](https://github.com/obra/private-journal-mcp) | Private local agent journal with semantic recall (by the Superpowers author) | `--with-journal` clones+builds it once to `~/.ai-dev-kit-tools/` and launches `node …/dist/index.js`. **Don't** use `npx github:obra/private-journal-mcp` — it's GitHub-only + a `tsc` build, so it rebuilds on every launch and the MCP connection times out ("never surfaces"). |
| [agentmemory](https://github.com/rohitg00/agentmemory) | Tri-agent cross-session memory (working/episodic/semantic); long-running server | `npm i -g @agentmemory/agentmemory` (pre-1.0) |
| [mcp-memory-keeper](https://github.com/mkreyman/mcp-memory-keeper) | Session-continuity via SQLite (survive context resets) | `claude mcp add memory-keeper npx mcp-memory-keeper` |
| [mem0](https://docs.mem0.ai/platform/mem0-mcp) | Long-term semantic memory layer (hosted `mcp.mem0.ai/mcp` or self-host OpenMemory) | needs `MEM0_API_KEY` — **not** the archived `mem0ai/mem0-mcp` repo |

## ◯ Review / testing (opt-in)

| Tool | What it adds | Install |
|---|---|---|
| [CodeRabbit CLI](https://docs.coderabbit.ai/cli) | Terminal AI reviewer of local diffs (pre-commit), with a fix loop; Skills at [coderabbitai/skills](https://github.com/coderabbitai/skills) | `curl -fsSL https://cli.coderabbit.ai/install.sh \| sh` (account/paid tiers) |
| [mutation-testing skill](https://github.com/cskiro/claudex) | Injects mutants, re-runs tests, reports survivors (Claude Code skill) | `/plugin marketplace add cskiro/claudex` → `/plugin install mutation-testing@claudex` |
| [claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) | **Reference** for building Claude-side hook guardrails (deny `.env` reads, lint-on-edit) — reimplement, don't vendor | clone & study (Claude-only, no license) |

## ⛔ Skip (and why)

| Tool | Why skip |
|---|---|
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Heavyweight multi-persona SDLC that scaffolds its own per-tool files; clashes with the lean single-AGENTS.md model and competes with Superpowers |
| [Claude-Flow / Ruflo](https://github.com/ruvnet/ruflo) | Full swarm orchestrator (MCP daemon, 100+ agents) — wrong altitude; would dominate the kit; drops Copilot |
| [ChrisRoyse/CodeGraph](https://github.com/ChrisRoyse/CodeGraph) | Needs a running Neo4j; ~4 commits, no releases. Its "single Rust binary / 30+ langs / community detection" claims were **fabricated** (those are graphify's features) |
| [RepoMapper](https://github.com/pdavis68/RepoMapper) | Strict subset of graphify (symbol map only, no query/path/explain); stale, no PyPI |

## Fabrications the scout caught (don't re-suggest)
- **ChrisRoyse/CodeGraph** — not a dependency-free Rust binary; graphify's features were misattributed to it.
- **`mem0ai/mem0-mcp`** — archived/read-only since 2026-03; use the hosted endpoint or OpenMemory instead.
- Superpowers IS available in **both** Anthropic's official marketplace
  (`/plugin install superpowers@claude-plugins-official`, merged 2026-01-15) **and** the
  community `obra/superpowers-marketplace`. The kit installs from the community marketplace;
  the official path is a valid alternative. (An earlier note here that called the official
  path fake was itself wrong — corrected.)
- `pip install repomapper`, `brew install rulesync` — no such packages (use the installs above).

## Current wiring
- **Wired (opt-in flags):** ast-grep, Grep MCP, private-journal, Claude hooks; always-on `/security-audit`.
- **Not wired (add manually if wanted):** Context7 (one MCP entry; for fast-moving deps), Serena (overlaps graphify; heavy LSP footprint — removed).
- **Reference only:** the optional/skip tools above (Repomix, Gitingest, GitHub MCP, etc.).

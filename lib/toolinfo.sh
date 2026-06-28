# lib/toolinfo.sh - short "what / config / use" blurbs printed as each tool is set up,
# so the setup output documents what you just enabled. Respects --quiet (log_dim).
# shellcheck shell=bash
[ -n "${_ADK_TOOLINFO_SOURCED:-}" ] && return 0
_ADK_TOOLINFO_SOURCED=1

_ti() {  # <what> <config/data> <common use>
  log_dim "what:   $1"
  log_dim "config: $2"
  log_dim "use:    $3"
}

# tool_info <key> : print the blurb for a tool (no-op for unknown keys).
tool_info() {
  case "$1" in
    graphify)
      _ti "code knowledge graph - semantic recall over THIS repo (query / path / explain)" \
          "graph in graphify-out/ (gitignored); rebuild after edits: 'graphify update .'" \
          "graphify query \"how does X work\"  - orient before editing, cheaper than grep" ;;
    superpowers)
      _ti "dev methodology - makes the agent brainstorm -> plan -> TDD -> review, not dump code" \
          "per-user Claude plugin (no project files); '/reload-plugins' or restart to activate" \
          "just ask for a feature; it clarifies + plans + writes tests first" ;;
    ast-grep)
      _ti "structural (AST) code search + safe codemods, many languages; 100% local" \
          "CLI only (no project file needed); optional sgconfig.yml for lint rules" \
          "ast-grep -p 'useEffect(\$F, [])' -l tsx   (add -r '...' to rewrite repo-wide)" ;;
    grep)
      _ti "search ~1M PUBLIC GitHub repos for real-world usage examples (not your code)" \
          "remote MCP, no key; entry in .mcp.json / .codex/config.toml / .vscode/mcp.json; sends only your query" \
          "ask: 'use grep to find real examples of <API>' - avoids hallucinated APIs" ;;
    private-journal)
      _ti "cross-session memory - records decisions/notes and recalls them in later sessions" \
          "local stdio MCP (built once in ~/.ai-dev-kit-tools); journal in <project>/.private-journal (gitignored); on-device embeddings" \
          "'record in your journal: ...'  then later  'what did we decide about ...'" ;;
    hooks)
      _ti "deterministic guardrails (Claude only) - block secret-file reads / dangerous shell commands" \
          ".claude/hooks/*.py + a PreToolUse 'hooks' block in .claude/settings.json" \
          "automatic - e.g. reading .env or 'rm -rf /' is denied with a message" ;;
    commands)
      _ti "reusable slash commands: pr-review, progress-report, deep-test, repeatable-task, security-audit" \
          ".claude/commands/ (Claude) - ~/.codex/prompts/ (Codex, /prompts:NAME) - .github/prompts/ (Copilot IDE chat)" \
          "/security-audit (no API key) - /pr-review <PR#> - /deep-test <target>" ;;
  esac
}

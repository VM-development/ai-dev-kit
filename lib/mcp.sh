# lib/mcp.sh - register MCP servers into each enabled agent's config, reversibly.
# Claude: .mcp.json (mcpServers) · Copilot/VS Code: .vscode/mcp.json (servers) via
# mcp_upsert.py (merges, preserves user entries). Codex: a managed [mcp_servers.<name>]
# block in .codex/config.toml. Every addition is logged to .ai-dev-kit-mcp so
# uninstall removes exactly the kit's entries.
# shellcheck shell=bash
[ -n "${_ADK_MCP_SOURCED:-}" ] && return 0
_ADK_MCP_SOURCED=1

_mcp_sidecar() { printf '%s' "$TARGET_DIR/.ai-dev-kit-mcp"; }

# _mcp_json <file> <root_key> <name> <http|stdio> <target> [args...]
# NOTE: the JSON file is deliberately NOT recorded in the manifest. uninstall removes
# only our server key (via the .ai-dev-kit-mcp ledger) and deletes the file only if it
# is then empty — so a user's own servers in the same file are never destroyed.
_mcp_json() {
  local file="$1" root="$2" name="$3" transport="$4"; shift 4
  local rel="${file#"$TARGET_DIR"/}"
  has_cmd python3 || { log_warn "python3 not found — skipping MCP '$name' for ${rel}."; return 0; }
  python3 "$ADK_ROOT/lib/mcp_upsert.py" "$file" "$root" add "$name" "$transport" "$@" \
    || { log_warn "Failed to write MCP '$name' into ${rel}."; return 0; }
  printf '%s|%s|%s\n' "$rel" "$root" "$name" >> "$(_mcp_sidecar)"
}

# _mcp_codex <name> <http|stdio> <target> [args...]
_mcp_codex() {
  local name="$1" transport="$2"; shift 2
  local body a targs=""
  if [ "$transport" = http ]; then
    body="url = \"$1\""
  else
    local cmd="$1"; shift
    for a in "$@"; do targs="$targs, \"$a\""; done
    body="command = \"$cmd\"
args = [${targs#, }]"
  fi
  { printf '[mcp_servers.%s]\n' "$name"; printf '%s\n' "$body"; } \
    | upsert_block "$TARGET_DIR/.codex/config.toml" "mcp-$name"
  printf '%s|toml|%s\n' ".codex/config.toml" "$name" >> "$(_mcp_sidecar)"
}

# register_mcp <name> <http|stdio> <target> [args...] : write to each enabled agent.
register_mcp() {
  local name="$1" transport="$2"; shift 2
  [ -n "${EN_CLAUDE:-}" ]  && _mcp_json "$TARGET_DIR/.mcp.json"        mcpServers "$name" "$transport" "$@"
  [ -n "${EN_COPILOT:-}" ] && _mcp_json "$TARGET_DIR/.vscode/mcp.json" servers   "$name" "$transport" "$@"
  [ -n "${EN_CODEX:-}" ]   && _mcp_codex "$name" "$transport" "$@"
  return 0
}

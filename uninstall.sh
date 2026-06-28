#!/usr/bin/env bash
#
# ai-dev-kit uninstaller — reverse what setup.sh added to a project.
#
#   - Restores any file the kit backed up to *.adk-bak (returns your original).
#   - Removes files the kit created (precisely, from .ai-dev-kit-manifest).
#   - Strips the kit's MCP entries (keeping your own) and guardrail-hook entries.
#   - Removes the kit's managed .gitignore block (leaves your other entries).
#   - Removes only the kit-created global Codex prompts (marker-checked); deletes graphify-out/.
#   - Optionally uninstalls Superpowers and graphify (global tools; off by default).
#
# Usage: ./uninstall.sh [TARGET_DIR] [options]
#
set -euo pipefail

ADK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ADK_ROOT

TARGET_DIR="$(pwd)"
ASSUME_YES=""; QUIET=""; DRY_RUN=""
WITH_SUPERPOWERS=""; WITH_GRAPHIFY=""
SUPERPOWERS_MARKETPLACE="obra/superpowers-marketplace"
SUPERPOWERS_PLUGIN="superpowers@superpowers-marketplace"   # installed-plugin id (matches setup)

usage() {
  cat <<'EOF'
ai-dev-kit uninstall — undo what setup.sh added to a project.

Usage: ./uninstall.sh [TARGET_DIR] [options]

  TARGET_DIR            Project to clean up (default: current directory)

Options:
  --with-superpowers    Also uninstall the Superpowers plugin (global, per tool)
  --with-graphify       Also uninstall the graphify CLI + skill (global)
  -y, --yes             Don't ask for confirmation
  --dry-run             Print what would happen; change nothing
  --quiet               Reduce log output
  -h, --help            Show this help

By default only this project's generated files (+ the kit's global Codex prompts)
are removed. graphify/Superpowers are global tools and are left alone unless asked.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --with-superpowers) WITH_SUPERPOWERS=1 ;;
    --with-graphify)    WITH_GRAPHIFY=1 ;;
    -y|--yes)           ASSUME_YES=1 ;;
    --dry-run)          DRY_RUN=1 ;;
    --quiet)            QUIET=1 ;;
    -h|--help)          usage; exit 0 ;;
    -*)                 echo "Unknown option: $1" >&2; usage; exit 2 ;;
    *)                  TARGET_DIR="$1" ;;
  esac
  shift
done

for f in log detect prompt idempotent commands; do
  # shellcheck source=/dev/null
  . "$ADK_ROOT/lib/$f.sh"
done
export ASSUME_YES QUIET DRY_RUN

# restore-or-remove a project-relative file: prefer restoring a backup; else remove.
remove_managed() {
  local rel="$1" abs bak
  case "$rel" in ""|/*|*..*) log_warn "skipping unsafe manifest path: '$rel'"; return 0 ;; esac
  if [ "$rel" = "CLAUDE.md" ]; then remove_claude_md; return 0; fi
  abs="$TARGET_DIR/$rel"; bak="$TARGET_DIR/$rel.adk-bak"
  if [ -e "$bak" ]; then
    if is_dry; then log_info "[dry] restore $rel (from .adk-bak)"; return 0; fi
    mv -f "$bak" "$abs"; log_success "restored $rel"
  elif [ -e "$abs" ]; then
    if is_dry; then log_info "[dry] remove $rel"; return 0; fi
    rm -f "$abs"; log_success "removed $rel"
  fi
}

# Only restore a file from its backup; never DELETE one we can't confirm we created.
# Used in no-manifest mode for files a user might have authored themselves.
_restore_only() {
  local rel="$1" abs="$TARGET_DIR/$1" bak="$TARGET_DIR/$1.adk-bak"
  if [ -e "$bak" ]; then
    remove_managed "$rel"
  elif [ -e "$abs" ]; then
    log_warn "Left $rel (no manifest, no backup — can't confirm ai-dev-kit created it)."
  fi
}

# CLAUDE.md is a merge target (we prepend @AGENTS.md + a managed notes block). Reverse it
# surgically — strip our block + the prepended import — so post-install user edits survive,
# instead of mv-restoring a stale backup snapshotted at first install.
remove_claude_md() {
  local f="$TARGET_DIR/CLAUDE.md" tmp
  local bak="$f.adk-bak"
  [ -f "$f" ] || { rm -f "$bak" 2>/dev/null || true; return 0; }
  if is_dry; then log_info "[dry] strip ai-dev-kit from CLAUDE.md (preserve your edits)"; return 0; fi
  remove_block "$f" "claude-notes" "<!--" "-->"
  if head -n1 "$f" | grep -qxF '@AGENTS.md'; then
    tmp="$(mktemp)"
    awk 'NR==1 && $0=="@AGENTS.md"{drop=1; next} drop==1 && $0==""{drop=0; next} {drop=0; print}' "$f" > "$tmp" && mv "$tmp" "$f"
  fi
  if grep -q '[^[:space:]]' "$f" 2>/dev/null; then
    log_success "stripped ai-dev-kit from CLAUDE.md (your content kept)"
  else
    rm -f "$f"; log_success "removed CLAUDE.md"
  fi
  rm -f "$bak" 2>/dev/null || true
}

remove_project_files() {
  local manifest="$TARGET_DIR/.ai-dev-kit-manifest" rel c
  if [ -f "$manifest" ]; then
    log_info "Using manifest: $manifest"
    while IFS= read -r rel; do
      [ -n "$rel" ] && remove_managed "$rel"
    done < "$manifest"
    is_dry || { rm -f "$manifest"; log_success "removed .ai-dev-kit-manifest"; }
  else
    log_warn "No .ai-dev-kit-manifest — conservative cleanup."
    log_dim "Removing only kit-named command/prompt files; other files restored only if backed up."
    # No manifest = can't prove ownership. Only restore from backups; never blind-delete
    # a file the user may have authored (even kit-named command files can collide).
    local c
    for c in $ADK_COMMANDS; do
      _restore_only ".claude/commands/$c.md"
      _restore_only ".github/prompts/$c.prompt.md"
    done
    remove_claude_md
    for rel in AGENTS.md .claude/settings.json .codex/config.toml \
               .github/copilot-instructions.md .github/workflows/copilot-setup-steps.yml; do
      _restore_only "$rel"
    done
  fi
}

remove_graphify_out() {
  local d="$TARGET_DIR/graphify-out"
  [ -d "$d" ] || return 0
  if [ -z "${HAVE_MANIFEST:-}" ]; then
    log_warn "Left graphify-out/ (no manifest — not deleting a graph the kit may not have built)."
    return 0
  fi
  if is_dry; then log_info "[dry] remove graphify-out/"; return 0; fi
  rm -rf "$d"; log_success "removed graphify-out/"
}

# Global ~/.codex/prompts/ is shared across projects, so be ownership-precise: restore a
# backed-up user original, remove only files carrying our 'ai-dev-kit:command' marker, and
# never touch a same-named prompt the user authored themselves. Gated on Codex-was-here.
remove_codex_prompts() {
  local dir="${CODEX_HOME:-$HOME/.codex}/prompts" c abs bak
  [ -d "$dir" ] || return 0
  for c in $ADK_COMMANDS; do
    abs="$dir/$c.md"; bak="$dir/$c.md.adk-bak"
    if [ -e "$bak" ]; then
      if is_dry; then log_info "[dry] restore codex prompt $c"; continue; fi
      mv -f "$bak" "$abs"; log_success "restored ~/.codex/prompts/$c.md"
    elif [ -f "$abs" ] && grep -q 'ai-dev-kit:command' "$abs" 2>/dev/null; then
      if is_dry; then log_info "[dry] remove codex prompt $c"; continue; fi
      rm -f "$abs"; log_success "removed ~/.codex/prompts/$c.md"
    elif [ -e "$abs" ]; then
      log_dim "left ~/.codex/prompts/$c.md (not created by ai-dev-kit)"
    fi
  done
}

# Strip the kit's PreToolUse guard hooks from .claude/settings.json so uninstall never
# leaves hooks pointing at deleted scripts (which would error on every tool call).
remove_hooks() {
  local s="$TARGET_DIR/.claude/settings.json"
  [ -f "$s" ] || return 0
  has_cmd python3 || return 0
  if is_dry; then log_info "[dry] strip ai-dev-kit hooks from .claude/settings.json"; return 0; fi
  python3 "$ADK_ROOT/lib/hooks_merge.py" --remove "$s" \
    && log_success "stripped ai-dev-kit hooks from settings.json" || true
}

# Remove the MCP server entries the kit added, from .ai-dev-kit-mcp ledger:
#   JSON files (.mcp.json / .vscode/mcp.json): remove just our server key (keep user's).
#   Codex config.toml: remove our managed [mcp_servers.<name>] block.
remove_mcp() {
  local sc="$TARGET_DIR/.ai-dev-kit-mcp" file root name failed=""
  [ -f "$sc" ] || return 0
  while IFS='|' read -r file root name; do
    [ -n "$file" ] && [ -n "$name" ] || continue
    case "$file" in /*|*..*) log_warn "skipping unsafe MCP path: '$file'"; failed=1; continue ;; esac
    if [ "$root" = toml ]; then
      if is_dry; then log_info "[dry] remove Codex MCP block 'mcp-$name'"
      else remove_block "$TARGET_DIR/$file" "mcp-$name"; log_success "removed Codex MCP '$name'"; fi
    else
      if is_dry; then log_info "[dry] remove MCP '$name' from $file"; continue; fi
      [ -f "$TARGET_DIR/$file" ] || continue
      if ! has_cmd python3; then log_warn "python3 missing — left MCP '$name' in $file"; failed=1; continue; fi
      if python3 "$ADK_ROOT/lib/mcp_upsert.py" "$TARGET_DIR/$file" "$root" remove "$name"; then
        log_success "removed MCP '$name' from $file"
        # Delete the file only if it has NO servers and no other content left.
        if python3 -c "import json,sys; d=json.load(open(sys.argv[1])); r=sys.argv[2]; sys.exit(0 if (not (d.get(r) or {}) and not {k:v for k,v in d.items() if k!=r and v}) else 1)" "$TARGET_DIR/$file" "$root" 2>/dev/null; then
          rm -f "$TARGET_DIR/$file"; log_dim "  ($file had nothing left — removed)"
        fi
      else
        log_warn "couldn't edit $file"; failed=1
      fi
    fi
  done < "$sc"
  if is_dry; then return 0; fi
  if [ -n "$failed" ]; then
    log_warn "Kept .ai-dev-kit-mcp (some MCP entries couldn't be removed) — re-run uninstall after fixing."
  else
    rm -f "$sc"
  fi
}

clean_gitignore() {
  local gi="$TARGET_DIR/.gitignore"
  [ -f "$gi" ] || return 0
  if is_dry; then log_info "[dry] remove ai-dev-kit block from .gitignore"; return 0; fi
  remove_block "$gi" "gitignore"
  # Leave the .gitignore file in place even if now empty — it may be the user's.
  log_success "cleaned .gitignore (removed ai-dev-kit block)"
}

cleanup_empty_dirs() {
  is_dry && return 0
  local d
  for d in .claude/commands .claude/hooks .claude .codex .github/prompts .github/workflows .github; do
    rmdir "$TARGET_DIR/$d" 2>/dev/null || true
  done
}

remove_superpowers() {
  log_step "Superpowers (global plugin)"
  if has_cmd claude; then
    if is_dry; then log_info "[dry] claude plugin uninstall $SUPERPOWERS_PLUGIN"
    else claude plugin uninstall "$SUPERPOWERS_PLUGIN" >/dev/null 2>&1 \
           && log_success "Claude: Superpowers uninstalled." \
           || log_warn "Claude: couldn't auto-uninstall Superpowers (try /plugin)."; fi
  fi
  if has_cmd copilot; then
    if is_dry; then log_info "[dry] copilot plugin uninstall $SUPERPOWERS_PLUGIN"
    else copilot plugin uninstall "$SUPERPOWERS_PLUGIN" >/dev/null 2>&1 \
           && log_success "Copilot CLI: Superpowers uninstalled." \
           || log_warn "Copilot CLI: couldn't auto-uninstall Superpowers."; fi
  fi
  log_dim "Codex: remove Superpowers interactively via 'codex' → /plugins if you installed it there."
}

remove_graphify_tool() {
  log_step "graphify (global tool)"
  if has_cmd graphify; then
    if is_dry; then log_info "[dry] graphify uninstall (remove skill from assistants)"
    else graphify uninstall >/dev/null 2>&1 || log_warn "graphify uninstall returned non-zero."; fi
  fi
  if has_cmd uv; then
    if is_dry; then log_info "[dry] uv tool uninstall graphifyy"
    else uv tool uninstall graphifyy >/dev/null 2>&1 \
           && log_success "graphify CLI uninstalled." \
           || log_warn "uv tool uninstall graphifyy returned non-zero."; fi
  fi
}

main() {
  [ -d "$TARGET_DIR" ] || die "Target directory not found: $TARGET_DIR"
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"; export TARGET_DIR
  HAVE_MANIFEST=""; [ -f "$TARGET_DIR/.ai-dev-kit-manifest" ] && HAVE_MANIFEST=1
  HAD_CODEX="";     [ -f "$TARGET_DIR/.codex/config.toml" ] && HAD_CODEX=1

  log_step "ai-dev-kit uninstall → $TARGET_DIR"
  is_dry && log_warn "DRY RUN — nothing will be changed."
  [ -f "$TARGET_DIR/.ai-dev-kit-manifest" ] || log_warn "No manifest here — will do a best-effort cleanup."
  [ -n "$WITH_SUPERPOWERS" ] && log_info "Will also uninstall the Superpowers plugin (global)."
  [ -n "$WITH_GRAPHIFY" ]    && log_info "Will also uninstall graphify (global tool)."

  if [ -z "$ASSUME_YES" ] && ! is_dry; then
    confirm "Remove ai-dev-kit's files from this project?" n || die "Aborted."
  fi

  remove_hooks
  remove_mcp
  remove_project_files
  [ -n "$HAD_CODEX" ] && remove_codex_prompts || true
  remove_graphify_out
  clean_gitignore
  cleanup_empty_dirs
  [ -n "$WITH_SUPERPOWERS" ] && remove_superpowers
  [ -n "$WITH_GRAPHIFY" ]    && remove_graphify_tool

  log_step "Done"
  if is_dry; then log_info "(dry run — re-run without --dry-run to apply)"; fi
}

main

# lib/scaffold.sh - render templates into the TARGET_DIR project. Idempotent + conflict-aware.
# shellcheck shell=bash
[ -n "${_ADK_SCAFFOLD_SOURCED:-}" ] && return 0
_ADK_SCAFFOLD_SOURCED=1

# Reusable commands list (single source of truth, shared with uninstall.sh).
# shellcheck source=/dev/null
. "$ADK_ROOT/lib/commands.sh"
# shellcheck source=/dev/null
. "$ADK_ROOT/lib/toolinfo.sh"

# ---- manifest + conflict handling ----------------------------------------
# The manifest (.ai-dev-kit-manifest) lists the project-relative paths the kit
# actually wrote, so .gitignore + uninstall.sh act only on real kit files.
_manifest() { printf '%s' "$TARGET_DIR/.ai-dev-kit-manifest"; }

_PRIOR_MANIFEST=""
_load_prior_manifest() {
  if [ -f "$(_manifest)" ]; then _PRIOR_MANIFEST="$(cat "$(_manifest)")"; else _PRIOR_MANIFEST=""; fi
}

# _kit_owns <project-relative-path> : true if a PRIOR run created this file.
_kit_owns() {
  [ -n "$_PRIOR_MANIFEST" ] || return 1
  printf '%s\n' "$_PRIOR_MANIFEST" | grep -qxF -- "$1"
}

record_manifest() {
  grep -qxF -- "$1" "$(_manifest)" 2>/dev/null || printf '%s\n' "$1" >> "$(_manifest)"
}

# should_write <abs> <rel> : decide whether to (over)write a managed file.
#   - no existing file            -> write
#   - file the kit created before -> write (normal re-run update)
#   - genuine pre-existing user file -> apply ON_CONFLICT (prompt|backup|skip|overwrite)
# Returns 0 to proceed (caller writes + records), 1 to skip.
should_write() {
  local abs="$1" rel="$2" policy="${ON_CONFLICT:-prompt}"
  [ -e "$abs" ] || return 0
  _kit_owns "$rel" && return 0
  [ "$policy" = prompt ] && [ -n "${ASSUME_YES:-}" ] && policy=backup
  case "$policy" in
    overwrite) log_warn "$rel exists (yours) - overwriting, no backup."; return 0 ;;
    skip)      log_warn "$rel exists (yours) - keeping it, skipped."; return 1 ;;
    backup)    backup_once "$abs"; log_warn "$rel exists (yours) - backed up to $rel.adk-bak, replacing."; return 0 ;;
    prompt)
      if confirm "$rel already exists and wasn't created by ai-dev-kit. Replace it (your copy is backed up)?" n; then
        backup_once "$abs"; return 0
      fi
      log_warn "$rel - kept yours."; return 1 ;;
    *) log_warn "Unknown --on-conflict='$policy' - keeping $rel."; return 1 ;;
  esac
}

_cmd_desc() {
  case "$1" in
    pr-review)       echo "Review a PR: correctness, security, standards; re-review, report, fix, describe." ;;
    progress-report) echo "Generate a project progress report for a given period." ;;
    deep-test)       echo "Design and run an in-depth testing algorithm for a target." ;;
    repeatable-task) echo "Turn a recurring task into a deterministic, repeatable runbook." ;;
    security-audit)  echo "Security review of a diff/area in this session (no API key)." ;;
    *)               echo "ai-dev-kit command." ;;
  esac
}

_cmd_hint() {
  case "$1" in
    pr-review)       echo "PR ref or URL (default: current diff)" ;;
    progress-report) echo "period, e.g. 'this week'" ;;
    deep-test)       echo "file / module / feature to test" ;;
    repeatable-task) echo "task to codify" ;;
    security-audit)  echo "PR ref / path (default: current diff)" ;;
    *)               echo "argument" ;;
  esac
}

# Claude Code: .claude/commands/<name>.md  (argument via $ARGUMENTS)
_write_command_claude() {
  local name="$1" body="$2" rel=".claude/commands/$1.md" dest="$TARGET_DIR/.claude/commands/$1.md" tmp
  should_write "$dest" "$rel" || return 0
  mkdir -p "$TARGET_DIR/.claude/commands"; tmp="$(mktemp)"
  {
    printf -- '---\n'
    printf 'description: %s\n' "$(_cmd_desc "$name")"
    printf 'argument-hint: "%s"\n' "$(_cmd_hint "$name")"
    printf -- '---\n\n'
    sed 's/__ARG__/$ARGUMENTS/g' "$body"
  } > "$tmp"
  mv "$tmp" "$dest"
  record_manifest "$rel"
}

# Codex CLI: $CODEX_HOME/prompts/<name>.md (USER-GLOBAL; argument via $ARGUMENTS). Invoke /prompts:<name>
# Global (outside the project), so it is not in the project manifest; uninstall handles it by name.
_write_command_codex() {
  local name="$1" body="$2" dir dest tmp
  dir="${CODEX_HOME:-$HOME/.codex}/prompts"; dest="$dir/$1.md"
  mkdir -p "$dir"; tmp="$(mktemp)"
  {
    printf -- '---\n'
    printf 'description: %s\n' "$(_cmd_desc "$name")"
    printf 'argument-hint: "%s"\n' "$(_cmd_hint "$name")"
    printf -- '---\n\n'
    sed 's/__ARG__/$ARGUMENTS/g' "$body"
  } > "$tmp"
  mv "$tmp" "$dest"
}

# Copilot: .github/prompts/<name>.prompt.md (IDE chat only; argument via ${input:arg})
_write_command_copilot() {
  local name="$1" body="$2" rel=".github/prompts/$1.prompt.md" dest="$TARGET_DIR/.github/prompts/$1.prompt.md" tmp
  should_write "$dest" "$rel" || return 0
  mkdir -p "$TARGET_DIR/.github/prompts"; tmp="$(mktemp)"
  {
    printf -- '---\n'
    printf 'description: %s\n' "$(_cmd_desc "$name")"
    printf 'mode: agent\n'
    printf -- '---\n\n'
    sed 's/__ARG__/${input:arg}/g' "$body"
  } > "$tmp"
  mv "$tmp" "$dest"
  record_manifest "$rel"
}

scaffold_commands() {
  local KIT="$ADK_ROOT" name body
  for name in $ADK_COMMANDS; do
    body="$KIT/templates/commands/$name.md"
    [ -f "$body" ] || continue
    [ -n "${EN_CLAUDE:-}" ]  && _write_command_claude  "$name" "$body"
    [ -n "${EN_CODEX:-}" ]   && _write_command_codex   "$name" "$body"
    [ -n "${EN_COPILOT:-}" ] && _write_command_copilot "$name" "$body"
  done
  if [ -n "${EN_CLAUDE:-}" ];  then log_success "Claude commands -> .claude/commands/*.md (invoke: /pr-review …)"; fi
  if [ -n "${EN_COPILOT:-}" ]; then log_success "Copilot prompts -> .github/prompts/*.prompt.md (IDE chat: /pr-review …)"; fi
  if [ -n "${EN_CODEX:-}" ]; then
    log_success "Codex prompts -> ${CODEX_HOME:-$HOME/.codex}/prompts/*.md (USER-GLOBAL; invoke: /prompts:pr-review …)"
    log_dim "Codex prompts are global (no per-project scope) and need a Codex restart to appear."
  fi
  tool_info commands
  return 0
}

# Write the kit's .gitignore entries as one managed block (so uninstall removes
# exactly our lines). Always ignores generated/local artifacts; in --gitignore mode
# it also ignores the generated project files from the manifest.
gitignore_step() {
  local gi="$TARGET_DIR/.gitignore" line
  {
    echo "graphify-out/"
    echo "*.local.*"
    echo ".claude/settings.local.json"
    echo "*.adk-bak"
    echo ".ai-dev-kit-manifest"
    echo ".ai-dev-kit-mcp"
    echo ".private-journal/"
    if [ -n "${GITIGNORE_GENERATED:-}" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && echo "/$line"
      done < "$(_manifest)"
    fi
  } | upsert_block "$gi" "gitignore"
  if [ -n "${GITIGNORE_GENERATED:-}" ]; then log_info "Local mode: generated files added to .gitignore."; fi
  return 0
}

# Optional tools (opt-in, gated by WANT_* flags). MCP servers go to every enabled
# agent; guardrail hooks are Claude-only.
scaffold_extras() {
  local any=""
  if [ -n "${WANT_GREP_MCP:-}" ]; then register_mcp grep http https://mcp.grep.app; tool_info grep; any=1; fi
  if [ -n "${WANT_JOURNAL:-}" ]; then
    local jentry="${ADK_JOURNAL_DIR:-$HOME/.ai-dev-kit-tools/private-journal-mcp}/dist/index.js"
    if [ -f "$jentry" ]; then
      register_mcp private-journal stdio node "$jentry"; tool_info private-journal; any=1
    else
      log_warn "private-journal not built - re-run setup with --with-journal (needs git + npm) to enable it."
    fi
  fi
  if [ -n "$any" ]; then
    log_success "MCP servers registered for:${EN_CLAUDE:+ Claude}${EN_CODEX:+ Codex}${EN_COPILOT:+ Copilot}"
  fi
  if [ -n "${WANT_HOOKS:-}" ] && [ -n "${EN_CLAUDE:-}" ]; then scaffold_hooks; fi
  return 0
}

# Claude-only deterministic guardrail hooks (deny secrets / dangerous shell commands).
scaffold_hooks() {
  has_cmd python3 || { log_warn "python3 not found - skipping Claude guardrail hooks."; return 0; }
  mkdir -p "$TARGET_DIR/.claude/hooks"
  cp "$ADK_ROOT/templates/claude/hooks/guard-bash.py"  "$TARGET_DIR/.claude/hooks/guard-bash.py"
  cp "$ADK_ROOT/templates/claude/hooks/guard-paths.py" "$TARGET_DIR/.claude/hooks/guard-paths.py"
  chmod +x "$TARGET_DIR/.claude/hooks/guard-bash.py" "$TARGET_DIR/.claude/hooks/guard-paths.py" 2>/dev/null || true
  record_manifest ".claude/hooks/guard-bash.py"
  record_manifest ".claude/hooks/guard-paths.py"
  if python3 "$ADK_ROOT/lib/hooks_merge.py" "$TARGET_DIR/.claude/settings.json"; then
    log_success "Claude guardrail hooks -> .claude/hooks/ + settings.json (deny secrets / dangerous cmds)"
    tool_info hooks
  else
    log_warn "Could not merge hooks into .claude/settings.json."
  fi
}

# Ensure CLAUDE.md exists with `@AGENTS.md` as its first line, then a managed notes
# block. Merge (non-destructive): a pre-existing user file is backed up once, then the
# import is prepended and our notes block is upserted below it.
ensure_claude_md() {
  local f="$1"
  # Snapshot a genuine pre-existing (non-kit) CLAUDE.md once — even if it already
  # starts with @AGENTS.md — so uninstall restores it instead of deleting it.
  if [ -f "$f" ] && ! _kit_owns "CLAUDE.md"; then backup_once "$f"; fi
  if [ ! -f "$f" ]; then
    printf '@AGENTS.md\n' > "$f"
  elif ! head -n1 "$f" | grep -qxF '@AGENTS.md'; then
    local tmp; tmp="$(mktemp)"
    printf '@AGENTS.md\n\n' > "$tmp"
    cat "$f" >> "$tmp"
    mv "$tmp" "$f"
  fi
  upsert_block "$f" "claude-notes" "<!--" "-->" < "$ADK_ROOT/templates/claude/CLAUDE.notes.md.tmpl"
  record_manifest "CLAUDE.md"
}

scaffold_project() {
  log_step "Scaffolding shared files into $TARGET_DIR"
  local KIT="$ADK_ROOT"
  : "${PROJECT_NAME:=$(basename "$TARGET_DIR")}"
  : "${ADK_DATE:=$(date +%Y-%m-%d)}"
  : "${ON_CONFLICT:=prompt}"
  export PROJECT_NAME ADK_DATE ON_CONFLICT

  _load_prior_manifest
  : > "$(_manifest)"          # fresh manifest; we append each path we actually write
  rm -f "$TARGET_DIR/.ai-dev-kit-mcp"   # fresh MCP ledger; recreated on demand

  # 1. AGENTS.md - single source of truth (incl. Standards). Never clobber an existing one.
  if [ ! -f "$TARGET_DIR/AGENTS.md" ]; then
    render_template "$KIT/templates/AGENTS.md.tmpl" "$TARGET_DIR/AGENTS.md"
    record_manifest "AGENTS.md"
    log_success "AGENTS.md created - fill in the {{...}} placeholders (incl. the Standards section)."
  else
    log_info "AGENTS.md already exists - left untouched (it is your source of truth)."
    _kit_owns "AGENTS.md" && record_manifest "AGENTS.md"   # keep ownership across re-runs
  fi

  # 2. Claude Code
  if [ -n "${EN_CLAUDE:-}" ]; then
    if should_write "$TARGET_DIR/.claude/settings.json" ".claude/settings.json"; then
      render_template "$KIT/templates/claude/settings.json.tmpl" "$TARGET_DIR/.claude/settings.json"
      record_manifest ".claude/settings.json"
    fi
    ensure_claude_md "$TARGET_DIR/CLAUDE.md"
    log_success "Claude Code -> CLAUDE.md (@AGENTS.md import) + .claude/settings.json (model=$CLAUDE_MODEL)"
  fi

  # 3. Codex
  if [ -n "${EN_CODEX:-}" ]; then
    if should_write "$TARGET_DIR/.codex/config.toml" ".codex/config.toml"; then
      render_template "$KIT/templates/codex/config.toml.tmpl" "$TARGET_DIR/.codex/config.toml"
      record_manifest ".codex/config.toml"
    fi
    log_success "Codex -> .codex/config.toml (model=$CODEX_MODEL). Reads AGENTS.md natively."
  fi

  # 4. Copilot
  if [ -n "${EN_COPILOT:-}" ]; then
    if should_write "$TARGET_DIR/.github/copilot-instructions.md" ".github/copilot-instructions.md"; then
      render_template "$KIT/templates/copilot/copilot-instructions.md.tmpl" "$TARGET_DIR/.github/copilot-instructions.md"
      record_manifest ".github/copilot-instructions.md"
    fi
    if should_write "$TARGET_DIR/.github/workflows/copilot-setup-steps.yml" ".github/workflows/copilot-setup-steps.yml"; then
      render_template "$KIT/templates/copilot/copilot-setup-steps.yml.tmpl" "$TARGET_DIR/.github/workflows/copilot-setup-steps.yml"
      record_manifest ".github/workflows/copilot-setup-steps.yml"
    fi
    log_success "Copilot -> .github/copilot-instructions.md + workflows/copilot-setup-steps.yml"
  fi

  # 5. Reusable commands (native slash commands per enabled tool)
  scaffold_commands

  # 6. Optional tools (MCP servers + Claude guardrail hooks), gated by WANT_* flags
  scaffold_extras

  # 7. .gitignore (managed block; honors --gitignore local mode)
  gitignore_step
  return 0
}

#!/usr/bin/env bash
#
# ai-dev-kit - set up a project for AI-assisted development across
# Claude Code (Claude), OpenAI Codex (GPT), and GitHub Copilot (any model).
#
# Usage:  ./setup.sh [TARGET_DIR] [options]
#
set -euo pipefail

ADK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ADK_ROOT

# ---- defaults -------------------------------------------------------------
TARGET_DIR="$(pwd)"
ASSUME_YES=""; QUIET=""; DRY_RUN=""
AGENTS_ARG=""
CLAUDE_MODEL="claude-opus-4-8"
CODEX_MODEL="gpt-5.5"
CODEX_REASONING="high"
WANT_SUPERPOWERS_ARG="ask"          # ask | yes | no
NO_GRAPHIFY=""
GITIGNORE_GENERATED=""
NO_GITIGNORE=""
ON_CONFLICT="prompt"            # prompt | backup | skip | overwrite
WANT_ASTGREP=""; WANT_GREP_MCP=""; WANT_JOURNAL=""; WANT_HOOKS=""; NO_EXTRAS=""
SUPERPOWERS_REPO="https://github.com/obra/superpowers"
SUPERPOWERS_MARKETPLACE="obra/superpowers-marketplace"

usage() {
  cat <<'EOF'
ai-dev-kit setup

Usage: ./setup.sh [TARGET_DIR] [options]

  TARGET_DIR                  Project to configure (default: current directory)

Options:
  --agents=LIST               Comma list of: claude,codex,copilot (default: prompt)
  --claude-model=NAME         Default Claude model      (default: claude-opus-4-8)
  --codex-model=NAME          Default Codex/GPT model    (default: gpt-5.5)
  --codex-reasoning=LEVEL     Codex reasoning effort     (default: high)
  --superpowers               Install Superpowers without asking
  --no-superpowers            Never install Superpowers
  --no-graphify               Skip graphify install + graph build
  --gitignore                 Add the generated files to .gitignore (keep them local)
  --no-gitignore              Don't add generated files to .gitignore (and don't prompt)
  --on-conflict=POLICY        When a file you already have collides: prompt | backup |
                              skip | overwrite (default: prompt; --yes treats it as backup)
  --with-ast-grep             Install ast-grep (structural search + codemods)
  --with-grep                 Add Grep MCP (search ~1M public repos for usage)
  --with-journal              Add private-journal MCP (cross-session memory)
  --with-hooks                Add Claude guardrail hooks (deny secrets/dangerous cmds)
  --with-all-extras           Enable all of the optional tools above
  --no-extras                 Don't prompt for optional tools
  -y, --yes                   Non-interactive; accept all defaults
  --quiet                     Reduce log output
  --dry-run                   Print planned actions; write/install nothing
  -h, --help                  Show this help
EOF
}

# ---- arg parsing ----------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --agents=*)           AGENTS_ARG="${1#*=}" ;;
    --claude-model=*)     CLAUDE_MODEL="${1#*=}" ;;
    --codex-model=*)      CODEX_MODEL="${1#*=}" ;;
    --codex-reasoning=*)  CODEX_REASONING="${1#*=}" ;;
    --superpowers)        WANT_SUPERPOWERS_ARG="yes" ;;
    --no-superpowers)     WANT_SUPERPOWERS_ARG="no" ;;
    --no-graphify)        NO_GRAPHIFY=1 ;;
    --gitignore)          GITIGNORE_GENERATED=1 ;;
    --no-gitignore)       NO_GITIGNORE=1 ;;
    --on-conflict=*)      ON_CONFLICT="${1#*=}" ;;
    --with-ast-grep)      WANT_ASTGREP=1 ;;
    --with-grep)          WANT_GREP_MCP=1 ;;
    --with-journal)       WANT_JOURNAL=1 ;;
    --with-hooks)         WANT_HOOKS=1 ;;
    --with-all-extras)    WANT_ASTGREP=1; WANT_GREP_MCP=1; WANT_JOURNAL=1; WANT_HOOKS=1 ;;
    --no-extras)          NO_EXTRAS=1 ;;
    -y|--yes)             ASSUME_YES=1 ;;
    --quiet)              QUIET=1 ;;
    --dry-run)            DRY_RUN=1 ;;
    -h|--help)            usage; exit 0 ;;
    -*)                   echo "Unknown option: $1" >&2; usage; exit 2 ;;
    *)                    TARGET_DIR="$1" ;;
  esac
  shift
done

# ---- source libraries -----------------------------------------------------
for f in log detect prompt idempotent toolinfo mcp \
         configure_claude configure_codex configure_copilot \
         install_graphify install_ast_grep install_journal scaffold; do
  # shellcheck source=/dev/null
  . "$ADK_ROOT/lib/$f.sh"
done

export ASSUME_YES QUIET DRY_RUN CLAUDE_MODEL CODEX_MODEL CODEX_REASONING \
       GITIGNORE_GENERATED ON_CONFLICT SUPERPOWERS_REPO SUPERPOWERS_MARKETPLACE \
       WANT_ASTGREP WANT_GREP_MCP WANT_JOURNAL WANT_HOOKS

case "$ON_CONFLICT" in
  prompt|backup|skip|overwrite) ;;
  *) die "Invalid --on-conflict='$ON_CONFLICT' (use: prompt | backup | skip | overwrite)" ;;
esac

# ---- selection helpers ----------------------------------------------------
choose_agents() {
  EN_CLAUDE=""; EN_CODEX=""; EN_COPILOT=""
  if [ -n "$AGENTS_ARG" ]; then
    case ",$AGENTS_ARG," in *,claude,*)  EN_CLAUDE=1 ;; esac
    case ",$AGENTS_ARG," in *,codex,*)   EN_CODEX=1 ;; esac
    case ",$AGENTS_ARG," in *,copilot,*) EN_COPILOT=1 ;; esac
  else
    confirm "Enable Claude Code (Claude models)?"   y && EN_CLAUDE=1  || true
    confirm "Enable OpenAI Codex (GPT models)?"     y && EN_CODEX=1   || true
    confirm "Enable GitHub Copilot (cloud agent)?"  y && EN_COPILOT=1 || true
  fi
  export EN_CLAUDE EN_CODEX EN_COPILOT
}

choose_models() {
  if [ -n "${EN_CLAUDE:-}" ]; then
    CLAUDE_MODEL="$(ask "Default Claude model" "$CLAUDE_MODEL")"
  fi
  if [ -n "${EN_CODEX:-}" ]; then
    CODEX_MODEL="$(ask "Default Codex (GPT) model" "$CODEX_MODEL")"
  fi
  export CLAUDE_MODEL CODEX_MODEL
}

decide_superpowers() {
  case "$WANT_SUPERPOWERS_ARG" in
    yes) WANT_SUPERPOWERS=1 ;;
    no)  WANT_SUPERPOWERS="" ;;
    ask)
      if confirm "Install Superpowers (skills/methodology) from $SUPERPOWERS_REPO?" y; then
        WANT_SUPERPOWERS=1
      else
        WANT_SUPERPOWERS=""
      fi ;;
  esac
  export WANT_SUPERPOWERS
}

decide_gitignore() {
  if [ -z "${GITIGNORE_GENERATED:-}" ] && [ -z "${NO_GITIGNORE:-}" ]; then
    if confirm "Add the generated files to .gitignore (keep them out of version control)?" n; then
      GITIGNORE_GENERATED=1
    fi
  fi
  export GITIGNORE_GENERATED
}

decide_extras() {
  local have="${WANT_ASTGREP:-}${WANT_GREP_MCP:-}${WANT_JOURNAL:-}${WANT_HOOKS:-}"
  if [ -z "$have" ] && [ -z "$NO_EXTRAS" ] && [ -z "$ASSUME_YES" ]; then
    if confirm "Set up optional tools (ast-grep, Grep MCP, private-journal, guardrail hooks)?" n; then
      confirm "  ast-grep - structural search + codemods?"      y && WANT_ASTGREP=1  || true
      confirm "  Grep MCP - search ~1M public repos for usage?"  y && WANT_GREP_MCP=1 || true
      confirm "  private-journal - cross-session memory?"       n && WANT_JOURNAL=1  || true
      [ -n "${EN_CLAUDE:-}" ] && { confirm "  Claude guardrail hooks - deny secrets/dangerous cmds?" y && WANT_HOOKS=1 || true; }
    fi
  fi
  export WANT_ASTGREP WANT_GREP_MCP WANT_JOURNAL WANT_HOOKS
}

print_summary() {
  log_step "Done"
  log_info "Target: $TARGET_DIR"
  log_info "Agents: ${EN_CLAUDE:+Claude }${EN_CODEX:+Codex }${EN_COPILOT:+Copilot}"
  [ -n "${GITIGNORE_GENERATED:-}" ] && log_info "Mode: local — generated files were added to .gitignore."
  if [ -n "${WANT_ASTGREP:-}${WANT_GREP_MCP:-}${WANT_JOURNAL:-}${WANT_HOOKS:-}" ]; then
    log_info "Optional tools:${WANT_ASTGREP:+ ast-grep}${WANT_GREP_MCP:+ grep-mcp}${WANT_JOURNAL:+ journal}${WANT_HOOKS:+ hooks}"
    [ -n "${WANT_GREP_MCP:-}${WANT_JOURNAL:-}" ] && log_dim "MCP servers were added to your agent config(s) — restart/reload the agent to load them."
  fi
  echo
  log_info "Next steps:"
  log_dim "1. Edit AGENTS.md - your single source of truth for all three agents."
  log_dim "2. Fill in the Standards section of AGENTS.md (code/commit/PR rules, tools, tests)."
  [ -n "${EN_CODEX:-}" ]   && log_dim "3. Codex: open the project once and 'trust' it so .codex/config.toml loads."
  [ -n "${EN_COPILOT:-}" ] && log_dim "4. Copilot: pick the model in the task model-picker; commit copilot-setup-steps.yml to the DEFAULT branch."
  log_dim "5. Keep the graph fresh after edits: graphify update ."
  echo
  log_dim "To undo everything ai-dev-kit added here: $ADK_ROOT/uninstall.sh \"$TARGET_DIR\""
}

# ---- main -----------------------------------------------------------------
main() {
  [ -d "$TARGET_DIR" ] || die "Target directory not found: $TARGET_DIR"
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"; export TARGET_DIR

  detect_os; detect_arch; detect_pkg_mgr
  log_step "ai-dev-kit -> $TARGET_DIR   (${ADK_OS}/${ADK_ARCH}, pkg=${ADK_PKG})"
  is_dry && log_warn "DRY RUN - no installs or file writes will happen."

  choose_agents
  [ -n "${EN_CLAUDE:-}${EN_CODEX:-}${EN_COPILOT:-}" ] || die "No agents selected; nothing to do."
  choose_models
  decide_superpowers
  decide_gitignore
  decide_extras

  if [ -n "${EN_CLAUDE:-}" ]; then
    if is_dry; then log_info "[dry] configure Claude Code (superpowers=${WANT_SUPERPOWERS:-no})"; else configure_claude; fi
  fi
  if [ -n "${EN_CODEX:-}" ]; then
    if is_dry; then log_info "[dry] configure Codex (superpowers=${WANT_SUPERPOWERS:-no})"; else configure_codex; fi
  fi
  if [ -n "${EN_COPILOT:-}" ]; then
    if is_dry; then log_info "[dry] configure Copilot (superpowers=${WANT_SUPERPOWERS:-no})"; else configure_copilot; fi
  fi

  if [ -z "$NO_GRAPHIFY" ]; then
    if is_dry; then log_info "[dry] install graphify + build graph"; else install_graphify; fi
  fi

  if [ -n "${WANT_ASTGREP:-}" ]; then
    if is_dry; then log_info "[dry] install ast-grep"; else install_ast_grep; fi
  fi
  if [ -n "${WANT_JOURNAL:-}" ]; then
    if is_dry; then log_info "[dry] build private-journal-mcp"; else install_journal || true; fi
  fi

  if is_dry; then
    log_info "[dry] scaffold AGENTS.md + per-agent config + slash commands${WANT_GREP_MCP:+ + Grep MCP}${WANT_JOURNAL:+ + journal MCP}${WANT_HOOKS:+ + hooks}"
  else
    scaffold_project
  fi

  print_summary
}

main

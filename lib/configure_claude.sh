# lib/configure_claude.sh - verify the Claude Code CLI, optionally set up Superpowers.
# Assumes the user already has the Claude Code CLI installed.
# shellcheck shell=bash
[ -n "${_ADK_CONFIGURE_CLAUDE_SOURCED:-}" ] && return 0
_ADK_CONFIGURE_CLAUDE_SOURCED=1

configure_claude() {
  log_step "Claude Code (Claude models)"

  if has_cmd claude; then
    local ver; ver="$(claude --version 2>/dev/null | head -n1 || true)"
    log_success "Claude Code CLI detected (${ver})."
  else
    log_warn "Claude Code CLI not found on PATH."
    log_dim  "Install it first, then re-run: https://docs.claude.com/claude-code"
  fi

  if [ -n "${WANT_SUPERPOWERS:-}" ]; then
    if has_cmd claude; then
      log_info "Installing Superpowers plugin for Claude Code..."
      claude plugin marketplace add "$SUPERPOWERS_MARKETPLACE" >/dev/null 2>&1 || true
      if claude plugin install superpowers@superpowers-marketplace >/dev/null 2>&1; then
        log_success "Superpowers installed. Run '/reload-plugins' (or restart) to activate."
      else
        log_warn "Auto-install failed. In a Claude Code session run:"
        log_dim   "/plugin install superpowers@claude-plugins-official"
      fi
      tool_info superpowers
    else
      log_warn "Skipping Superpowers - Claude Code CLI not available."
    fi
  fi
}

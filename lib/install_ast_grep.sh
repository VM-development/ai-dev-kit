# lib/install_ast_grep.sh - install the ast-grep CLI (structural search + codemods).
# shellcheck shell=bash
[ -n "${_ADK_INSTALL_ASTGREP_SOURCED:-}" ] && return 0
_ADK_INSTALL_ASTGREP_SOURCED=1

install_ast_grep() {
  log_step "ast-grep (structural search + codemods)"

  if has_cmd ast-grep; then
    local ver; ver="$(ast-grep --version 2>/dev/null | head -n1 || true)"
    log_success "ast-grep already installed (${ver})."
    tool_info ast-grep
    return 0
  fi

  if [ "$ADK_PKG" = brew ]; then
    brew install ast-grep || log_warn "brew install ast-grep failed."
  elif has_cmd npm; then
    log_info "Installing @ast-grep/cli via npm…"
    npm install -g @ast-grep/cli || log_warn "npm install failed."
  elif has_cmd cargo; then
    cargo install ast-grep --locked || log_warn "cargo install failed."
  elif has_cmd pip3; then
    pip3 install ast-grep-cli || log_warn "pip install failed."
  else
    log_warn "Couldn't auto-install ast-grep. Install one of:"
    log_dim  "brew install ast-grep | npm i -g @ast-grep/cli | pip install ast-grep-cli"
    return 0
  fi

  if has_cmd ast-grep; then
    log_success "ast-grep installed."
    tool_info ast-grep
  fi
}

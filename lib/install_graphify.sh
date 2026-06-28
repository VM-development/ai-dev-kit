# lib/install_graphify.sh - install graphify (PyPI 'graphifyy', binary 'graphify') + build the code graph.
# shellcheck shell=bash
[ -n "${_ADK_INSTALL_GRAPHIFY_SOURCED:-}" ] && return 0
_ADK_INSTALL_GRAPHIFY_SOURCED=1

# uv tool binaries live in ~/.local/bin by default; make sure this run can see them.
_adk_ensure_local_bin() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
  esac
}

install_graphify() {
  log_step "graphify (code knowledge graph)"

  # 1. Ensure uv (graphify ships as a uv tool).
  if ! has_cmd uv; then
    if confirm "graphify needs 'uv' (Python tool runner). Install uv now?" y; then
      if [ "$ADK_PKG" = brew ]; then
        brew install uv || log_warn "brew install uv failed."
      else
        curl -LsSf https://astral.sh/uv/install.sh | sh || log_warn "uv install script failed."
      fi
    else
      log_warn "Skipping graphify (uv not installed)."
      return 0
    fi
  fi
  _adk_ensure_local_bin
  if ! has_cmd uv; then
    log_warn "uv still not on PATH; skipping graphify. Install uv and run 'uv tool install graphifyy' later."
    return 0
  fi

  # 2. Install the graphify CLI + register the skill.
  if has_cmd graphify; then
    log_success "graphify already installed ($(graphify --version 2>/dev/null | head -n1 || true))."
  else
    log_info "Installing graphify (PyPI package 'graphifyy', CLI binary 'graphify')..."
    uv tool install --upgrade graphifyy || { log_warn "graphify install failed."; return 0; }
    _adk_ensure_local_bin
  fi
  graphify install >/dev/null 2>&1 || log_dim "graphify skill registration skipped - fine for pure-CLI use."

  if ! has_cmd graphify; then
    log_warn "graphify not on PATH after install; run 'graphify update .' in the project later."
    return 0
  fi

  # 3. Build the code graph now - headless, deterministic AST, no API key needed.
  #    (The rich semantic build over docs/papers is agent-orchestrated: run '/graphify .'.)
  if confirm "Build the code knowledge graph now for this project?" y; then
    log_info "Building code graph (headless, no API key): graphify update ."
    if ( cd "$TARGET_DIR" && graphify update . ); then
      log_success "graphify-out/ built (graph.json, GRAPH_REPORT.md, graph.html)."
      if [ -z "${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}" ]; then
        log_dim "Code is indexed. For semantic extraction over docs/papers, set GEMINI_API_KEY,"
        log_dim "or run '/graphify .' inside your AI assistant for the full agentic build."
      fi
    else
      log_warn "Build failed. Run 'graphify update .' in the project, or '/graphify .' in your assistant."
    fi
  else
    log_dim "Later: run 'graphify update .' in the project, or '/graphify .' inside your assistant."
  fi
  tool_info graphify
}

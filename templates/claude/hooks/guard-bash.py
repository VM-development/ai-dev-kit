#!/usr/bin/env python3
"""ai-dev-kit PreToolUse guard for Bash. Blocks clearly-dangerous commands.

Claude Code feeds the tool call as JSON on stdin; exit code 2 blocks the call
and shows the stderr message to the model. Conservative by design: a recursive
force-delete is blocked only when it targets an absolute path, $HOME/~, or the
cwd/glob (`.` `..` `*`) — so everyday `rm -rf build/` style deletes still work.
Edit DANGER / the dangerous-target set below to tune.
"""
import json
import re
import sys

# Misc catastrophes (regex). rm -rf is handled separately by _dangerous_rm().
DANGER = [
    r"--no-preserve-root",
    r":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;",            # fork bomb
    r"\bmkfs\.",
    r"\bdd\b[^\n]*\bof=/dev/",
    r">\s*/dev/sd[a-z]",
    r"\bchmod\s+-[A-Za-z]*\s*777\b|\bchmod\s+777\b",
    r"\bsudo\s+rm\b",
    r"(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba|z|fi)?sh\b",  # curl ... | sh
    r"git\s+push\b[^\n]*(--force|--force-with-lease|\s-f\b)[^\n]*\b(origin/)?(main|master)\b",
    r"git\s+push\b[^\n]*\b(origin/)?(main|master)\b[^\n]*(--force|\s-f\b)",
]


def _is_dangerous_target(arg):
    arg = arg.strip().strip('"').strip("'")
    if not arg:
        return False
    if arg in ("/", "~", ".", "..", "*", "/*", "$HOME", "${HOME}"):
        return True
    if arg.startswith("/"):            # any absolute path: /etc, /important/data
        return True
    if arg.startswith("~") or arg.startswith("$HOME") or arg.startswith("${HOME}"):
        return True
    return False


def _dangerous_rm(cmd):
    """True if any segment is `rm` with recursive+force flags on a dangerous target."""
    for seg in re.split(r"&&|\|\||;|\n|\|", cmd):
        toks = seg.split()
        if "rm" not in toks:
            continue
        i = toks.index("rm")
        rest = toks[i + 1:]
        recursive = force = False
        targets = []
        for t in rest:
            if t == "--":
                continue
            if t.startswith("--"):
                if t == "--recursive":
                    recursive = True
                elif t == "--force":
                    force = True
            elif t.startswith("-") and len(t) > 1:
                if "r" in t[1:].lower():
                    recursive = True
                if "f" in t[1:]:
                    force = True
            else:
                targets.append(t)
        if recursive and force and any(_is_dangerous_target(t) for t in targets):
            return True
    return False


def main():
    try:
        data = json.load(sys.stdin)
    except (ValueError, OSError):
        sys.exit(0)
    cmd = (data.get("tool_input") or {}).get("command", "") or ""
    blocked = _dangerous_rm(cmd) or any(re.search(p, cmd) for p in DANGER)
    if blocked:
        sys.stderr.write(
            "[ai-dev-kit guard] Blocked a dangerous shell command (matched a safety "
            "rule). If this is a false positive, edit .claude/hooks/guard-bash.py.\n"
            "Command: " + cmd[:300] + "\n"
        )
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()

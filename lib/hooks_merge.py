#!/usr/bin/env python3
"""Add or remove ai-dev-kit's guardrail hooks in a .claude/settings.json.

Idempotent and surgical: it only ever touches PreToolUse entries whose command
points at the kit's guard scripts — user hooks and other settings are preserved.

Usage:
  hooks_merge.py <settings.json>            # add the kit's guard hooks
  hooks_merge.py --remove <settings.json>   # strip the kit's guard hooks (uninstall)
"""
import json
import os
import sys

GUARD = "$CLAUDE_PROJECT_DIR/.claude/hooks"
ENTRIES = [
    {"matcher": "Bash",
     "hooks": [{"type": "command", "command": f"{GUARD}/guard-bash.py"}]},
    {"matcher": "Read|Edit|Write|MultiEdit",
     "hooks": [{"type": "command", "command": f"{GUARD}/guard-paths.py"}]},
]


def is_kit_entry(entry):
    for h in entry.get("hooks", []):
        if isinstance(h, dict) and GUARD in str(h.get("command", "")):
            return True
    return False


def main():
    remove = "--remove" in sys.argv[1:]
    positional = [a for a in sys.argv[1:] if a != "--remove"]
    if not positional:
        sys.exit("hooks_merge: missing settings.json path")
    path = positional[0]

    if not os.path.exists(path):
        if remove:
            sys.exit(0)            # nothing to strip
        data = {}
    else:
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except (ValueError, OSError):
            data = {}
    if not isinstance(data, dict):
        data = {}

    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        hooks = {}
    pre = hooks.get("PreToolUse")
    pre = [e for e in pre if not is_kit_entry(e)] if isinstance(pre, list) else []
    if not remove:
        pre.extend(ENTRIES)

    if pre:
        hooks["PreToolUse"] = pre
    else:
        hooks.pop("PreToolUse", None)
    if hooks:
        data["hooks"] = hooks
    else:
        data.pop("hooks", None)

    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()

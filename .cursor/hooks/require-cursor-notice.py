#!/usr/bin/env python3
"""Block git commit/push if cursor_updatenotice.md would not go with it."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

NOTICE = "cursor_updatenotice.md"


def allow() -> None:
    print(json.dumps({"permission": "allow"}))
    sys.exit(0)


def deny(message: str) -> None:
    print(
        json.dumps(
            {
                "permission": "deny",
                "user_message": message,
                "agent_message": message,
            }
        )
    )
    sys.exit(0)


def git_porcelain() -> str:
    result = subprocess.run(
        ["git", "status", "--porcelain", "--", NOTICE],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip()


def command_adds_notice(command: str) -> bool:
    if re.search(r"git\s+add\s+(?:-A|--all|\.|-u)\b", command):
        return True
    if re.search(r"git\s+add\b[^\n]*cursor_updatenotice\.md", command):
        return True
    if re.search(r"git\s+commit\b[^\n]*-a\b", command):
        return True
    return False


def main() -> None:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        allow()
        return

    command = str(payload.get("command") or "")
    if not re.search(r"\bgit\s+(push|commit)\b", command):
        allow()
        return

    notice = Path(NOTICE)
    if not notice.is_file():
        deny(
            f"{NOTICE} fehlt. Cursor muss die Datei anlegen, committen und mit pushen."
        )

    porcelain = git_porcelain()
    is_push = bool(re.search(r"\bgit\s+push\b", command))
    is_commit = bool(re.search(r"\bgit\s+commit\b", command))

    if not porcelain:
        allow()
        return

    if is_push and not command_adds_notice(command) and "commit" not in command:
        deny(
            f"{NOTICE} ist nicht committed ({porcelain}). "
            "Erst git add cursor_updatenotice.md, commit, dann push."
        )

    if is_commit and not command_adds_notice(command):
        # Untracked or unstaged worktree change: would be left out.
        untracked = porcelain.startswith("??")
        unstaged = len(porcelain) >= 2 and porcelain[1] in "M?"
        staged = len(porcelain) >= 1 and porcelain[0] in "AM"
        if untracked or (unstaged and not staged):
            deny(
                f"{NOTICE} ist nicht gestaged ({porcelain}). "
                "Vor jedem Commit: git add cursor_updatenotice.md."
            )

    allow()


if __name__ == "__main__":
    main()

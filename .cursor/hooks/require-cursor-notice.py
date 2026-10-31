#!/usr/bin/env python3
"""Block git commit/push without notice, and pull/push unless on main."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

NOTICE = "enscapez_updatenotice.md"


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


def git_output(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip()


def current_branch() -> str:
    return git_output("rev-parse", "--abbrev-ref", "HEAD")


def command_adds_notice(command: str) -> bool:
    if re.search(r"git\s+add\s+(?:-A|--all|\.|-u)\b", command):
        return True
    if re.search(r"git\s+add\b[^\n]*enscapez_updatenotice\.md", command):
        return True
    if re.search(r"git\s+commit\b[^\n]*-a\b", command):
        return True
    return False


def remote_ref_is_main(command: str) -> bool:
    explicit = re.search(r"git\s+(?:push|pull)\s+origin\s+(\S+)", command)
    if explicit:
        dest = explicit.group(1).strip("'\"")
        dest = dest.rstrip(";,&|")
        return dest in ("main", "HEAD", "HEAD:main") or dest.endswith(":main")
    if re.search(r"origin/(?!main\b)\S+", command):
        return False
    return True


def main() -> None:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        allow()
        return

    command = str(payload.get("command") or "")
    is_push = bool(re.search(r"\bgit\s+push\b", command))
    is_pull = bool(re.search(r"\bgit\s+pull\b", command))
    is_commit = bool(re.search(r"\bgit\s+commit\b", command))

    if not (is_push or is_pull or is_commit):
        allow()
        return

    if is_push or is_pull:
        if current_branch() != "main":
            deny(
                "Nur Branch main (gleicher Branch wie Claude). "
                "git checkout main, dann git pull origin main / git push origin main."
            )
        if not remote_ref_is_main(command):
            deny(
                "Pull und Push nur origin/main. Keine Feature-Branches."
            )

    if is_commit and current_branch() != "main":
        deny(
            "Nur auf main committen. git checkout main, dann arbeiten."
        )

    if not (is_commit or is_push):
        allow()
        return

    notice = Path(NOTICE)
    if not notice.is_file():
        deny(
            f"{NOTICE} fehlt. Anlegen, auf main committen, git push origin main."
        )

    porcelain = git_output("status", "--porcelain", "--", NOTICE)
    if not porcelain:
        allow()
        return

    if is_push and not command_adds_notice(command) and "commit" not in command:
        deny(
            f"{NOTICE} ist nicht committed ({porcelain}). "
            "Erst git add enscapez_updatenotice.md, commit, dann git push origin main."
        )

    if is_commit and not command_adds_notice(command):
        untracked = porcelain.startswith("??")
        unstaged = len(porcelain) >= 2 and porcelain[1] in "M?"
        staged = len(porcelain) >= 1 and porcelain[0] in "AM"
        if untracked or (unstaged and not staged):
            deny(
                f"{NOTICE} ist nicht gestaged ({porcelain}). "
                "Vor jedem Commit: git add enscapez_updatenotice.md."
            )

    allow()


if __name__ == "__main__":
    main()

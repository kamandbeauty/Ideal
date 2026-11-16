#!/usr/bin/env python3
"""Publish build logs into a GitHub check run so they can be read through the API.

The sandbox that drives this project cannot download Actions artifacts or logs
(only api.github.com is reachable), so every CI step appends its output to a log
file and this helper PATCHes the combined text onto a dedicated check run.

Usage:
    diag.py init                       # create the check run (in_progress)
    diag.py append <file> <text>       # append text to the log file
    diag.py run <file> -- <command...> # run command, append output+status
    diag.py publish [--conclusion X]   # push buffered log to the check run
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

API = "https://api.github.com"
CHECK_NAME = "javidai diagnostics"
MAX_OUTPUT = 60000


def _token() -> str:
    tok = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not tok:
        sys.exit("no GITHUB_TOKEN in environment")
    return tok


def _repo() -> tuple[str, str]:
    full = os.environ.get("GITHUB_REPOSITORY", "")
    if "/" not in full:
        sys.exit("no GITHUB_REPOSITORY in environment")
    owner, name = full.split("/", 1)
    return owner, name


def _request(method: str, path: str, payload: dict | None = None) -> dict:
    url = API + path
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {_token()}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
            "User-Agent": "javidai-ci",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode()
    except urllib.error.HTTPError as exc:  # pragma: no cover - CI helper
        sys.exit(f"GitHub API {method} {path} failed: {exc.code} {exc.read().decode()[:500]}")
    return json.loads(body) if body else {}


def cmd_init() -> None:
    owner, repo = _repo()
    sha = os.environ["GITHUB_SHA"]
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    run_attempt = os.environ.get("GITHUB_RUN_ATTEMPT", "1")
    created = _request(
        "POST",
        f"/repos/{owner}/{repo}/check-runs",
        {
            "name": CHECK_NAME,
            "head_sha": sha,
            "status": "in_progress",
            "started_at": _now(),
            "output": {"title": "logs", "summary": f"run {run_id}.{run_attempt}"},
        },
    )
    with open("diag-check.json", "w", encoding="utf-8") as fh:
        json.dump({"id": created["id"], "sha": sha}, fh)
    print(f"check run {created['id']} created")


def _now() -> str:
    import datetime

    return datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def cmd_append(logfile: str, text: str) -> None:
    with open(logfile, "a", encoding="utf-8") as fh:
        fh.write(text)
        if not text.endswith("\n"):
            fh.write("\n")


def cmd_run(logfile: str, command: list[str]) -> int:
    header = f"\n$ {' '.join(command)}\n"
    proc = subprocess.run(command, capture_output=True, text=True)
    body = (proc.stdout or "") + (proc.stderr or "")
    cmd_append(logfile, header + body + f"\n[exit {proc.returncode}]")
    return proc.returncode


def cmd_publish(conclusion: str) -> None:
    with open("diag-check.json", encoding="utf-8") as fh:
        info = json.load(fh)
    owner, repo = _repo()
    with open("diag.log", encoding="utf-8") as fh:
        text = fh.read()
    if len(text) > MAX_OUTPUT:
        text = "[truncated to the last 60000 chars]\n" + text[-MAX_OUTPUT:]
    payload = {
        "status": "completed",
        "conclusion": conclusion if conclusion != "success" else "success",
        "completed_at": _now(),
        "output": {
            "title": "build log",
            "summary": text if len(text) <= 60000 else text[-60000:],
        },
    }
    _request("PATCH", f"/repos/{owner}/{repo}/check-runs/{info['id']}", payload)
    print("published diagnostics")


if __name__ == "__main__":
    argv = sys.argv[1:]
    if not argv:
        sys.exit(__doc__)
    match argv[0]:
        case "init":
            cmd_init()
        case "append":
            cmd_append(argv[1], sys.stdin.read())
        case "run":
            sep = argv.index("--") if "--" in argv else len(argv)
            sys.exit(cmd_run(argv[1], argv[sep + 1 :]))
        case "publish":
            cmd_publish(argv[1] if len(argv) > 1 else "success")
        case _:
            sys.exit(__doc__)

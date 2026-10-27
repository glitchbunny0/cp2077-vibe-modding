#!/usr/bin/env python3
"""Fetch the upstream sources listed in refs.toml into refs/.

    fetch_refs.py sync    [--group G ...] [--only NAME ...] [--with-heavy]
    fetch_refs.py update  [--group G ...] [--only NAME ...] [--with-heavy]
    fetch_refs.py status

sync    clones each git entry at the commit in refs.lock.json (or resolves its
        ref when the entry is not locked yet) and mirrors GitBook spaces that
        are missing. Re-running it is cheap: present checkouts are left alone.
update  re-resolves every selected ref, re-mirrors the selected GitBook
        spaces and rewrites their lock entries.
status  compares refs/ with the lock.

Only git and the standard library. Clones are shallow, never recurse into
submodules and run no code from the cloned repositories.
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import tomllib
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "refs.toml"
LOCK = ROOT / "refs.lock.json"
REFS = ROOT / "refs"
USER_AGENT = "cp2077-vibe-modding/fetch_refs (docs mirror; +https://github.com/glitchbunny0)"
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
GIT_ENV = {**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_LFS_SKIP_SMUDGE": "1"}


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def load_manifest() -> list[dict]:
    data = tomllib.loads(MANIFEST.read_text())
    entries = []
    for kind in ("git", "gitbook"):
        for e in data.get(kind, []):
            entries.append({**e, "kind": kind})
    names = [e["name"] for e in entries]
    dupes = {n for n in names if names.count(n) > 1}
    if dupes:
        sys.exit(f"duplicate names in refs.toml: {sorted(dupes)}")
    return entries


def load_lock() -> dict:
    return json.loads(LOCK.read_text()) if LOCK.exists() else {}


def save_lock(lock: dict) -> None:
    LOCK.write_text(json.dumps(dict(sorted(lock.items())), indent=2) + "\n")


def git(*args: str, cwd: Path | None = None) -> str:
    r = subprocess.run(["git", *args], cwd=cwd, env=GIT_ENV, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip() or r.stdout.strip()}")
    return r.stdout.strip()


def head_of(dest: Path) -> str | None:
    if not (dest / ".git").exists():
        return None
    try:
        return git("rev-parse", "HEAD", cwd=dest)
    except RuntimeError:
        return None


def du(path: Path) -> int:
    total = 0
    for p in path.rglob("*"):
        if p.is_file() and not p.is_symlink():
            total += p.stat().st_size
    return total


def clone_at(url: str, target: str, dest: Path) -> str:
    """Shallow-fetch `target` (branch, tag or full sha) of `url` into a fresh dest."""
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    git("init", "-q", cwd=dest)
    git("remote", "add", "origin", url, cwd=dest)
    git("-c", "protocol.version=2", "fetch", "-q", "--depth", "1", "--no-tags",
        "--no-recurse-submodules", "origin", target, cwd=dest)
    git("-c", "advice.detachedHead=false", "checkout", "-q", "--detach", "FETCH_HEAD", cwd=dest)
    return git("rev-parse", "HEAD", cwd=dest)


def sync_git(e: dict, lock: dict, update: bool) -> str:
    name, dest = e["name"], REFS / e["name"]
    locked = lock.get(name)
    if not update and locked and locked.get("ref") == e["ref"] and head_of(dest) == locked["commit"]:
        return f"{name}: ok {locked['commit'][:10]}"
    target = locked["commit"] if (locked and not update and locked.get("ref") == e["ref"]) else e["ref"]
    commit = clone_at(e["url"], target, dest)
    lock[name] = {
        "kind": "git",
        "url": e["url"],
        "ref": e["ref"],
        "commit": commit,
        "commit_date": git("log", "-1", "--format=%cI", cwd=dest),
        "fetched_at": now(),
        "bytes": du(dest),
    }
    how = "pinned" if target == commit else f"resolved {e['ref']} ->"
    return f"{name}: {how} {commit[:10]}"


def http_get(url: str, tries: int = 4) -> bytes:
    delay = 2.0
    for attempt in range(tries):
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as err:
            if err.code not in (429, 500, 502, 503, 504) or attempt == tries - 1:
                raise
        except (urllib.error.URLError, TimeoutError):
            if attempt == tries - 1:
                raise
        time.sleep(delay)
        delay *= 2
    raise RuntimeError("unreachable")


LLMS_LINK = re.compile(r"^\s*-\s*\[([^\]]*)\]\((\S+?\.md)\)(?::\s*(.*))?$")


def sync_gitbook(e: dict, lock: dict, update: bool) -> str:
    name, base = e["name"], e["base"].rstrip("/")
    dest = REFS / "docs" / name
    if not update and name in lock and not lock[name].get("failed") and (dest / "llms.txt").exists():
        return f"{name}: ok ({lock[name]['pages']} pages, {lock[name]['fetched_at'][:10]})"
    index = http_get(base + "/llms.txt").decode("utf-8")
    pages = []
    for line in index.splitlines():
        m = LLMS_LINK.match(line)
        if m and m.group(2).startswith(base + "/"):
            pages.append((m.group(1), m.group(2)))
    pages = list(dict.fromkeys(pages))
    tmp = dest.with_name(dest.name + ".partial")
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)
    (tmp / "llms.txt").write_text(index)

    def fetch(page: tuple[str, str]) -> tuple[str, str | None]:
        title, url = page
        rel = urllib.parse.unquote(url[len(base) + 1:])
        if ".." in Path(rel).parts:
            return url, "unsafe path"
        try:
            body = http_get(url)
        except urllib.error.HTTPError as err:
            # llms.txt spells a slug's ellipsis as "..." while the page lives under U+2026.
            if "..." not in url:
                return url, str(err)
            try:
                body = http_get(url.replace("...", "%E2%80%A6"))
            except Exception as err2:  # noqa: BLE001 - reported per page
                return url, f"{err}; ellipsis retry: {err2}"
        except Exception as err:  # noqa: BLE001 - reported per page
            return url, str(err)
        out = tmp / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(body)
        return url, None

    failed = []
    with cf.ThreadPoolExecutor(max_workers=4) as pool:
        for url, err in pool.map(fetch, pages):
            if err:
                failed.append({"url": url, "error": err})
    digest = hashlib.sha256()
    for p in sorted(tmp.rglob("*.md")):
        digest.update(str(p.relative_to(tmp)).encode())
        digest.update(p.read_bytes())
    if dest.exists():
        shutil.rmtree(dest)
    tmp.rename(dest)
    lock[name] = {
        "kind": "gitbook",
        "base": base,
        "pages": len(pages) - len(failed),
        "failed": failed,
        "content_sha256": digest.hexdigest(),
        "fetched_at": now(),
        "bytes": du(dest),
    }
    tail = f", {len(failed)} failed" if failed else ""
    return f"{name}: mirrored {len(pages) - len(failed)} pages{tail}"


def selected(entries: list[dict], args) -> list[dict]:
    out = []
    for e in entries:
        if args.only and e["name"] not in args.only:
            continue
        if args.group and e["group"] not in args.group:
            continue
        if not args.only and e["group"] == "heavy" and not args.with_heavy and "heavy" not in (args.group or []):
            continue
        out.append(e)
    unknown = set(args.only or []) - {e["name"] for e in entries}
    if unknown:
        sys.exit(f"unknown names: {sorted(unknown)}")
    return out


def cmd_fetch(args, update: bool) -> int:
    entries = selected(load_manifest(), args)
    lock = load_lock()
    REFS.mkdir(exist_ok=True)
    errors = 0
    for e in entries:
        try:
            fn = sync_git if e["kind"] == "git" else sync_gitbook
            print(fn(e, lock, update), flush=True)
            save_lock(lock)
        except Exception as err:  # noqa: BLE001 - one bad source must not stop the rest
            errors += 1
            print(f"{e['name']}: ERROR {err}", file=sys.stderr, flush=True)
    return 1 if errors else 0


def cmd_status(_args) -> int:
    entries = load_manifest()
    lock = load_lock()
    rows, bad = [], 0
    for e in entries:
        name, entry = e["name"], lock.get(e["name"])
        if e["kind"] == "git":
            head = head_of(REFS / name)
            if not entry:
                state = "unlocked"
            elif entry.get("ref") != e["ref"]:
                state = f"ref changed ({entry['ref']} -> {e['ref']})"
            elif head is None:
                state = "missing"
            elif head != entry["commit"]:
                state = f"drift (HEAD {head[:10]})"
            else:
                state = f"ok {head[:10]} {entry['commit_date'][:10]}"
            label = e["ref"]
        else:
            if entry and entry.get("failed"):
                state = f"partial: {len(entry['failed'])} pages failed"
            elif entry and (REFS / "docs" / name / "llms.txt").exists():
                state = f"ok {entry['pages']} pages {entry['fetched_at'][:10]}"
            else:
                state = "missing"
            label = "llms.txt"
        bad += not state.startswith("ok")
        size = f"{(entry or {}).get('bytes', 0) / 1e6:8.1f} MB"
        rows.append((e["group"], name, label, size, state))
    w = [max(len(r[i]) for r in rows) for i in range(4)]
    for r in rows:
        print("  ".join(r[i].ljust(w[i]) for i in range(4)), r[4])
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for c in ("sync", "update"):
        p = sub.add_parser(c)
        p.add_argument("--group", action="append")
        p.add_argument("--only", action="append")
        p.add_argument("--with-heavy", action="store_true")
    sub.add_parser("status")
    args = ap.parse_args()
    if args.cmd == "status":
        return cmd_status(args)
    return cmd_fetch(args, update=args.cmd == "update")


if __name__ == "__main__":
    sys.exit(main())

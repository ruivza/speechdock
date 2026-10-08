#!/usr/bin/env python3
"""Publish the fork's current documentation; preserve Wiki Git history."""

import argparse
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGES = {
    "index.md": "Home",
    "basics.md": "Getting-Started",
    "permissions.md": "Permissions",
    "advanced.md": "Privacy-and-Cache",
    "applescript.md": "AppleScript",
    "build-release.md": "Build-and-Release",
}


def render_pages():
    pages = {}
    for source, title in PAGES.items():
        text = (ROOT / "docs" / source).read_text(encoding="utf-8")
        if text.startswith("---\n"):
            text = text.split("---\n", 2)[2].lstrip()
        for filename, wiki_title in PAGES.items():
            text = text.replace("](" + filename + ")", "](" + wiki_title + ")")
        text = text.replace("](index_ja.md)", "](https://github.com/ruivza/speechdock/blob/main/docs/index_ja.md)")
        pages[title + ".md"] = text
    pages["_Sidebar.md"] = "\n".join(
        "- [" + label + "](" + title + ")" for label, title in [
            ("首页", "Home"), ("开始使用", "Getting-Started"),
            ("系统权限", "Permissions"), ("隐私与缓存", "Privacy-and-Cache"),
            ("AppleScript", "AppleScript"), ("编译与发布", "Build-and-Release"),
        ]
    ) + "\n"
    pages["_Footer.md"] = "当前指南按此分支重写。原项目：[yohasebe/speechdock](https://github.com/yohasebe/speechdock)。保留 Apache License 2.0 与原作者版权归属。\n"
    return pages


def git(directory, *args, capture=False):
    return subprocess.run(
        ["git", "-C", str(directory), *args], check=True,
        text=True, stdout=subprocess.PIPE if capture else None,
    ).stdout


def write_pages(directory):
    for filename, text in render_pages().items():
        (directory / filename).write_text(text, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="ruivza/speechdock")
    parser.add_argument("--preview", type=Path, help="Render into an empty local directory without Git or network")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        parser.error("Expected a GitHub owner/repository")
    if args.preview is not None:
        if args.preview.exists() and any(args.preview.iterdir()):
            parser.error("Preview directory must be empty")
        args.preview.mkdir(parents=True, exist_ok=True)
        write_pages(args.preview)
        print("Wiki preview: " + str(args.preview))
        return
    with tempfile.TemporaryDirectory(prefix="speechdock-wiki-") as temporary:
        checkout = Path(temporary) / "wiki"
        try:
            subprocess.run(["git", "clone", "https://github.com/" + args.repository + ".wiki.git", str(checkout)], check=True)
        except subprocess.CalledProcessError:
            raise SystemExit("Wiki unavailable. Enable Wiki and create its first Home page on GitHub, then retry.")
        # Replacing current pages is explicit. Every removed file remains in Git
        # history, and a normal push rejects concurrent changes.
        tracked = git(checkout, "ls-files", "-z", capture=True).split("\0")
        tracked = [path for path in tracked if path]
        if tracked:
            git(checkout, "rm", "--", *tracked)
        write_pages(checkout)
        for setting in ["user.name", "user.email"]:
            value = git(ROOT, "config", "--get", setting, capture=True).strip()
            if not value:
                raise SystemExit("Configure Git commit identity before synchronizing Wiki.")
            git(checkout, "config", setting, value)
        git(checkout, "add", "--", ".")
        changed = subprocess.run(["git", "-C", str(checkout), "diff", "--cached", "--quiet"])
        if changed.returncode == 0:
            print("Wiki already matches the current fork documentation.")
            return
        if changed.returncode != 1:
            raise SystemExit("Cannot inspect staged Wiki changes")
        git(checkout, "commit", "-m", "Rewrite Wiki for sandboxed SpeechDock fork")
        git(checkout, "push", "origin", "HEAD")
        print("Wiki published: https://github.com/" + args.repository + "/wiki")


if __name__ == "__main__":
    main()

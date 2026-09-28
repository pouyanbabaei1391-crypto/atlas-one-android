#!/usr/bin/env python3
"""Fail the workflow if the release APK violates essential security policy."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path


def main() -> None:
    apk = Path(sys.argv[1]).resolve()
    if not apk.is_file() or apk.stat().st_size == 0:
        raise SystemExit("Release APK is missing or empty")
    android_home = Path(os.environ["ANDROID_HOME"])
    versions = sorted(
        (path for path in (android_home / "build-tools").iterdir() if path.is_dir()),
        key=lambda path: tuple(int(x) for x in re.findall(r"\d+", path.name)),
    )
    aapt = versions[-1] / "aapt"
    output = subprocess.check_output(
        [str(aapt), "dump", "badging", str(apk)], text=True, errors="replace"
    )
    if "application-debuggable" in output:
        raise SystemExit("Refusing to publish a debuggable APK")
    if "package: name='com.atlas.one'" not in output:
        raise SystemExit("Unexpected Android application ID")
    print("Release policy verification passed")


if __name__ == "__main__":
    main()


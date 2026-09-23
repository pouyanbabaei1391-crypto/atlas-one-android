"""Build the native Hybrid edition without changing GitHub workflow files."""

from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import os
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / ".build" / "english_voice_source"


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise RuntimeError(f"Hybrid build anchor mismatch in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def prepare() -> Path:
    subprocess.run(
        [sys.executable, str(ROOT / "english_voice_addon" / "build.py"), "--prepare-only"],
        cwd=ROOT,
        check=True,
        env={**os.environ, "ATLAS_BUNDLE_MODEL": "false"},
    )
    gateway = os.environ.get("ATLAS_HYBRID_GATEWAY_URL", "").strip().rstrip("/")
    model = os.environ.get("ATLAS_HYBRID_CLOUD_MODEL", "llama-3.1-8b-instant").strip()
    settings = STAGE / "lib" / "core" / "settings_service.dart"
    if gateway:
        replace_once(
            settings,
            "static const groqBaseUrl = 'https://api.groq.com/openai/v1';",
            f"static const groqBaseUrl = {gateway!r};",
        )
        replace_once(
            settings,
            "return key.trim().isNotEmpty || url != groqBaseUrl;",
            "return true; // A trusted Gateway URL was supplied by the Hybrid build.",
        )
    if model != "llama-3.1-8b-instant":
        replace_once(
            settings,
            "static const groqFastModel = 'llama-3.1-8b-instant';",
            f"static const groqFastModel = {model!r};",
        )
    return STAGE


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("target", nargs="?", default="android", choices=["android"])
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    stage = prepare()
    if args.prepare_only:
        print(stage)
        return
    if not os.environ.get("ATLAS_HYBRID_GATEWAY_URL", "").strip():
        raise SystemExit("ATLAS_HYBRID_GATEWAY_URL is required by this Gateway build route")
    subprocess.run(["flutter", "pub", "get"], cwd=stage, check=True)
    subprocess.run(
        ["flutter", "analyze", "--no-fatal-infos", "--no-fatal-warnings", "lib", "test"],
        cwd=stage,
        check=True,
    )
    subprocess.run(["flutter", "test"], cwd=stage, check=True)
    subprocess.run([sys.executable, "build.py", args.target], cwd=stage, check=True)
    shutil.copytree(stage / "dist", ROOT / "dist", dirs_exist_ok=True)


if __name__ == "__main__":
    main()


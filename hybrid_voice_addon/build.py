"""Build an additive Hybrid edition without modifying the source project."""

from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / ".build" / "english_voice_source"


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise RuntimeError(f"Hybrid patch anchor mismatch in {path}: {old[:80]!r}")
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
    config = STAGE / "lib" / "core" / "hybrid_config.dart"
    config.write_text(
        "// Generated only in the disposable Hybrid build stage.\n"
        f"const hybridGatewayUrl = {json.dumps(gateway)};\n"
        f"const hybridCloudModel = {json.dumps(model)};\n"
        "const hybridCloudEnabled = hybridGatewayUrl.isNotEmpty;\n",
        encoding="utf-8",
    )

    ai = STAGE / "lib" / "core" / "ai_service.dart"
    replace_once(ai, "import 'gemma_prompt.dart';", "import 'gemma_prompt.dart';\nimport 'hybrid_config.dart';")
    replace_once(
        ai,
        "  AiService(this.settings);",
        "  AiService(this.settings);\n  static bool get hybridAvailable => hybridCloudEnabled;",
    )
    replace_once(
        ai,
        """      return local.ready ? 'Gemma 3 4B is ready on this phone. No AI server is used.'
          : 'Local Gemma is not loaded. Open Local AI setup and prepare the model.';""",
        """      return local.ready ? 'Gemma 3 4B is ready on this phone. No AI server is used.'
          : hybridCloudEnabled
              ? 'Hybrid cloud is ready while Gemma finishes local setup.'
              : 'Local Gemma is not loaded. Open Local AI setup and prepare the model.';""",
    )
    replace_once(
        ai,
        """    final base = (await settings.baseUrl).replaceAll(RegExp(r'/$'), '');
    final model = await settings.model;
    final key = await settings.apiKey;""",
        """    final wantsLocal = await settings.useLocalAi;
    final useReadyLocal = wantsLocal && local.ready;
    final useHybridCloud = wantsLocal && !local.ready && hybridCloudEnabled;
    final configuredBase = (await settings.baseUrl).replaceAll(RegExp(r'/$'), '');
    final base = useHybridCloud ? hybridGatewayUrl : configuredBase;
    final model = useHybridCloud ? hybridCloudModel : await settings.model;
    final key = useHybridCloud ? '' : await settings.apiKey;""",
    )
    replace_once(
        ai,
        """    if (await settings.useLocalAi) {
      if (imageBase64 != null) {""",
        """    if (useReadyLocal) {
      if (imageBase64 != null) {""",
    )

    controller = STAGE / "lib" / "core" / "assistant_controller.dart"
    replace_once(
        controller,
        """    if (value && localAiEnabled && !ai.local.ready) {
      status = 'Prepare Gemma 3 4B in Local AI setup first. No server is needed.';
      notifyListeners();
      return;
    }""",
        """    if (value && localAiEnabled && !ai.local.ready && !AiService.hybridAvailable) {
      status = 'Prepare Gemma 3 4B in Local AI setup first, or configure the Hybrid gateway.';
      notifyListeners();
      return;
    }""",
    )
    replace_once(
        controller,
        """    if (localAiEnabled) {
      try { await ai.local.refresh(); } catch (e) { status = _voiceError(e); }
    }""",
        """    if (localAiEnabled) {
      try {
        await ai.local.refresh();
        if (!ai.local.ready && AiService.hybridAvailable) {
          status = 'Hybrid cloud ready · preparing Gemma locally in the background';
          unawaited(ai.local.prepare().then((_) {
            if (_disposed) return;
            status = 'Gemma 3 4B ready · switched to private local AI';
            notifyListeners();
          }).catchError((Object error) {
            if (_disposed) return;
            status = 'Hybrid cloud active · local setup will retry later';
            notifyListeners();
          }));
        }
      } catch (e) { status = _voiceError(e); }
    }""",
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
        raise SystemExit("ATLAS_HYBRID_GATEWAY_URL is required for a functional Hybrid APK")
    subprocess.run(["flutter", "pub", "get"], cwd=stage, check=True)
    subprocess.run(
        ["flutter", "analyze", "--no-fatal-infos", "--no-fatal-warnings", "lib", "test"],
        cwd=stage,
        check=True,
    )
    subprocess.run(["flutter", "test"], cwd=stage, check=True)
    subprocess.run([sys.executable, "build.py", args.target], cwd=stage, check=True)
    shutil.copytree(
        stage / "dist",
        ROOT / "dist",
        dirs_exist_ok=True,
        copy_function=shutil.copy2,
    )


if __name__ == "__main__":
    main()

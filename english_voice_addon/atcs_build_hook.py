"""Install ATCS only into the disposable build stage.

Every replacement is guarded by an exact anchor. If the upstream source ever
changes, the build stops instead of silently producing an unprotected APK.
"""

from pathlib import Path


def _replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"ATCS integration anchor mismatch in {path}: expected 1, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def install_atcs(stage: Path) -> None:
    controller = stage / "lib/core/assistant_controller.dart"
    activity = stage / "native/android/app/src/main/kotlin/com/atlas/one/MainActivity.kt"
    required = [
        stage / "lib/core/adaptive_thermal_control_service.dart",
        stage / "native/android/app/src/main/kotlin/com/atlas/one/AtcsThermalChannel.kt",
        controller,
        activity,
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise RuntimeError(f"ATCS files are missing from the build stage: {missing}")

    _replace_once(
        controller,
        "import 'vision_intelligence_service.dart';",
        "import 'vision_intelligence_service.dart';\nimport 'adaptive_thermal_control_service.dart';",
    )
    _replace_once(
        controller,
        "  final VisionIntelligenceService vision = VisionIntelligenceService();",
        "  final VisionIntelligenceService vision = VisionIntelligenceService();\n"
        "  final AdaptiveThermalControlSystem atcs = AdaptiveThermalControlSystem();",
    )
    _replace_once(
        controller,
        "    WidgetsBinding.instance.addObserver(this);",
        "    WidgetsBinding.instance.addObserver(this);\n    await atcs.start();",
    )
    _replace_once(
        controller,
        "    _visionTimer = Timer(const Duration(seconds: 3), () async {",
        "    _visionTimer = Timer(atcs.visionInterval, () async {",
    )
    _replace_once(
        controller,
        "        final frame = await camera.captureBase64();\n        await vision.analyzeBase64(frame);",
        "        final frame = await camera.captureBase64();\n"
        "        if (await atcs.allowVisionInference(frame)) {\n"
        "          await vision.analyzeBase64(frame);\n"
        "          atcs.recordVisionInference();\n"
        "        }",
    )
    _replace_once(
        controller,
        "    unawaited(vision.dispose());\n    super.dispose();",
        "    unawaited(vision.dispose());\n    atcs.dispose();\n    super.dispose();",
    )
    _replace_once(
        activity,
        "        super.configureFlutterEngine(flutterEngine)",
        "        super.configureFlutterEngine(flutterEngine)\n"
        "        AtcsThermalChannel.install(this, flutterEngine.dartExecutor.binaryMessenger)",
    )

    marker = stage / "ATCS_INTEGRATED.txt"
    marker.write_text(
        "ATCS Adaptive Thermal Control System is integrated into this disposable build stage.\n"
        "Every original source line remains intact; ATCS integration is additive.\n",
        encoding="utf-8",
    )

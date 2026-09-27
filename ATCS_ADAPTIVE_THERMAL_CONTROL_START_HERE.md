# ATCS — Adaptive Thermal Control System

This release adds an on-device predictive thermal governor while retaining every original source line exactly. One additive hook is appended to the existing local build helper; no prior line is edited or removed.

## What ATCS does

- Reads Android thermal severity, battery temperature, thermal headroom, charging state, and power-save state locally.
- Smooths noisy readings and estimates the near-term temperature trend.
- Uses hysteresis and a three-sample recovery gate to avoid rapid switching.
- Adapts silent YOLO26x background analysis from 3 seconds to 5, 9, 18, or 30 seconds.
- Suspends silent background YOLO inference at emergency thermal severity.
- Skips redundant analysis for unchanged camera frames.
- Leaves user controls, Qwen3, memory, camera answers, TTS, security rules, and all existing behavior intact.
- Collects no identifiers and sends no thermal telemetry off the device.

## Integration guarantee

ATCS is installed only in the disposable build stage by a guarded additive hook. Each integration anchor must match exactly once; otherwise the build fails. This prevents a future source change from silently producing an APK without thermal protection.

Build with the existing single GitHub Actions workflow or the existing local build commands. No extra workflow or manual step is required.

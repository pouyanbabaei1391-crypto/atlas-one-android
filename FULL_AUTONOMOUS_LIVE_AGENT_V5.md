# Atlas One — Full Autonomous Live Phone Agent V5

This build adds a foreground, user-visible phone automation loop for **Google/Chrome, My Files/Files, and Notes/Keep**.

## Runtime loop
Observe structured Accessibility tree → identify active package and interactive nodes → choose app-specific action → execute visibly → observe again → verify state → retry/fallback or stop safely.

## Real source modules
- `lib/agent/live_phone_agent.dart` — autonomous orchestration and app-specific workflows.
- `lib/agent/live_ui_observer.dart` — live settle/wait state loop.
- `lib/agent/models/ui_state.dart` — structured UI model.
- `native/android/.../AtlasAccessibilityService.kt` — package/node/view-id/text/bounds observation and actions.
- `lib/core/assistant_controller.dart` — invokes the live agent when Apps is enabled.

## Security boundary
Only apps explicitly selected by the user can be launched. Password/PIN/OTP/card/payment/transfer/destructive requests are not auto-executed. Accessibility must be enabled by the user in Android Settings. Actions occur in the foreground and are visible.

## Device variability
Google/Chrome, Samsung My Files/Files, Keep/vendor Notes can change UI labels and accessibility trees. V5 uses view IDs when available, text/description fallbacks, state verification, and retries. No source-only build can truthfully guarantee every OEM/app version without device testing.

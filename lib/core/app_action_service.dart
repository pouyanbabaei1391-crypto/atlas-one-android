import 'package:url_launcher/url_launcher.dart';
import 'native_bridge.dart';

class AppActionService {
  final NativeBridge bridge;
  bool enabled = false;
  final Set<String> allowedAppIds = {};

  AppActionService(this.bridge);

  Future<bool> openSelectedApp(String id) async {
    if (!enabled || !allowedAppIds.contains(id)) return false;
    return bridge.launchApp(id);
  }

  Future<bool> openUri(String uri) async {
    if (!enabled) return false;
    final parsed = Uri.parse(uri);
    const allowed = {'https', 'http', 'mailto', 'tel', 'sms', 'geo'};
    if (!allowed.contains(parsed.scheme)) return false;
    return launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  Future<bool> accessibilityEnabled() => bridge.accessibilityEnabled();
  Future<void> requestAccessibility() => bridge.openAccessibilitySettings();
  Future<String> observeUi() => bridge.observeUi();
  Future<bool> clickText(String text) => bridge.clickText(text);
  Future<bool> setText(String text) => bridge.setFocusedText(text);
  Future<bool> scroll(int direction) => bridge.scrollUi(direction);
  Future<bool> back() => bridge.globalBack();
  Future<bool> home() => bridge.globalHome();
  Future<bool> pressEnter() => bridge.pressEnter();
  Future<bool> pressTab() => bridge.pressTab();

  void disable() {
    enabled = false;
    allowedAppIds.clear();
  }
}

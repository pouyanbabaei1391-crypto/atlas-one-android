import 'package:url_launcher/url_launcher.dart';
import 'native_bridge.dart';

class AppActionService {
  final NativeBridge bridge;
  bool enabled = true;
  final Set<String> allowedAppIds = {};

  AppActionService(this.bridge);

  Future<bool> openSelectedApp(String id) async {
    if (!enabled) return false;
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
  Future<String> observeUiStructured() => bridge.observeUiStructured();
  Future<bool> clickViewId(String id) => bridge.clickViewId(id);
  Future<bool> focusText(String text) => bridge.focusText(text);
  Future<bool> setFirstEditableText(String text) => bridge.setFirstEditableText(text);
  Future<bool> clickText(String text) => bridge.clickText(text);
  Future<bool> setText(String text) => bridge.setFocusedText(text);
  Future<bool> scroll(int direction) => bridge.scrollUi(direction);
  Future<bool> back() => bridge.globalBack();
  Future<bool> home() => bridge.globalHome();
  Future<bool> pressEnter() => bridge.pressEnter();
  Future<bool> pressTab() => bridge.pressTab();
  Future<bool> longClickFirstImage() => bridge.longClickFirstImage();
  Future<bool> clickFirstMeaningfulLink() => bridge.clickFirstMeaningfulLink();
  Future<bool> clickFirstFileCandidate() => bridge.clickFirstFileCandidate();
  Future<bool> openNotifications() => bridge.openNotifications();
  Future<bool> openRecents() => bridge.openRecents();

  void disable() {
    enabled = false;
    allowedAppIds.clear();
  }
}

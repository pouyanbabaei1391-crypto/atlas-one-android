import '../core/app_action_service.dart';
import 'agent_policy.dart';
import 'live_agent_result.dart';
import 'live_ui_observer.dart';
import 'models/ui_state.dart';
import 'tool_router.dart';

/// Foreground autonomous phone agent.
/// It uses Android intents for robust navigation and Accessibility for visible UI interaction.
class LivePhoneAgent {
  final AppActionService actions;
  late final LiveUiObserver observer = LiveUiObserver(actions);
  LivePhoneAgent(this.actions);

  Future<LiveAgentResult> run(String request, Map<String, String> installedApps, {String? generatedText}) async {
    final trace = <String>[];
    if (!actions.enabled) return const LiveAgentResult(false, 'کنترل دستگاه فعال نیست', []);
    if (AgentPolicy.destructiveIntent(request) || AgentPolicy.sensitiveText(request)) {
      return const LiveAgentResult(false, 'این درخواست به اقدام یا دادهٔ حساس مربوط است و خودکار اجرا نمی‌شود', []);
    }

    final q = request.toLowerCase();
    final wantsNotifications = _has(q, ['notification', 'notifications', 'اعلان', 'اعلان‌ها', 'نوتیفیکیشن']);
    final wantsRecents = _has(q, ['recent apps', 'recents', 'برنامه های اخیر', 'برنامه‌های اخیر', 'صفحه های اضافی', 'صفحه‌های اضافی']);
    if (wantsNotifications) {
      if (!await _ensureAccessibility()) return const LiveAgentResult(false, 'Accessibility را برای Atlas One فعال کنید', []);
      final ok = await actions.openNotifications();
      trace.add(ok ? 'OPEN NOTIFICATIONS' : 'FAILED NOTIFICATIONS');
      if (ok) await observer.settle();
      return LiveAgentResult(ok, ok ? 'اعلان‌ها باز و قابل مشاهده شدند' : 'باز کردن اعلان‌ها ممکن نشد', trace);
    }
    if (wantsRecents) {
      if (!await _ensureAccessibility()) return const LiveAgentResult(false, 'Accessibility را برای Atlas One فعال کنید', []);
      final ok = await actions.openRecents();
      trace.add(ok ? 'OPEN RECENTS' : 'FAILED RECENTS');
      if (ok) await observer.settle();
      return LiveAgentResult(ok, ok ? 'برنامه‌های اخیر باز شدند' : 'باز کردن برنامه‌های اخیر ممکن نشد', trace);
    }

    final image = _has(q, ['عکس', 'تصویر', 'image', 'photo', 'picture']);
    final download = _has(q, ['دانلود', 'download', 'save image', 'ذخیره']);
    final write = _has(q, ['note', 'notes', 'یادداشت', 'بنویس', 'paste', 'ثبت کن']);
    final article = _has(q, ['مقاله', 'article', 'research', 'تحقیق']);
    final research = _has(q, ['google', 'search', 'جستجو', 'جست‌وجو', 'پیدا کن', 'find']) || image || article;
    final openGoogleOnly = _has(q, ['open google', 'google را باز', 'گوگل را باز', 'باز کن google']) && !image && !article && !_has(q, ['search', 'جستجو', 'پیدا کن']);

    if (openGoogleOnly) {
      final ok = await actions.openUri('https://www.google.com/');
      trace.add(ok ? 'OPEN https://www.google.com/' : 'FAILED OPEN GOOGLE');
      return LiveAgentResult(ok, ok ? 'Google باز شد' : 'Google باز نشد', trace);
    }

    String? collectedArticle;
    if (research) {
      final query = _cleanQuery(request);
      final uri = image
          ? 'https://www.google.com/search?tbm=isch&q=${Uri.encodeQueryComponent(query)}'
          : 'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
      final opened = await actions.openUri(uri);
      trace.add(opened ? 'OPEN SEARCH $uri' : 'FAILED SEARCH URI');
      if (!opened) return LiveAgentResult(false, 'باز کردن جست‌وجوی Google ممکن نشد', trace);
      await Future.delayed(const Duration(milliseconds: 1100));

      if (image && download) {
        if (!await _ensureAccessibility()) return LiveAgentResult(false, 'برای دانلود قابل مشاهده، Accessibility را برای Atlas One فعال کنید', trace);
        await observer.settle();
        var ok = await actions.longClickFirstImage();
        trace.add(ok ? 'LONG_CLICK FIRST IMAGE' : 'NO IMAGE LONG_CLICK');
        if (ok) {
          await Future.delayed(const Duration(milliseconds: 500));
          ok = await _clickAny(['Download image', 'Download', 'Save image', 'دانلود تصویر', 'بارگیری تصویر', 'ذخیره تصویر'], trace);
        }
        if (!ok) {
          // Fallback: open a visible image result first, then try browser download menu again.
          final state = await observer.state();
          UiNodeState? candidate;
          for (final n in state.nodes) {
            if (n.clickable && (n.klass.toLowerCase().contains('image') || n.desc.toLowerCase().contains('image'))) {
              candidate = n;
              break;
            }
          }
          if (candidate != null) {
            final clicked = candidate.viewId.isNotEmpty ? await actions.clickViewId(candidate.viewId) : (candidate.text.isNotEmpty ? await actions.clickText(candidate.text) : false);
            trace.add(clicked ? 'OPEN IMAGE RESULT' : 'FAILED IMAGE RESULT');
            await Future.delayed(const Duration(milliseconds: 700));
            if (clicked) {
              final longOk = await actions.longClickFirstImage();
              trace.add(longOk ? 'LONG_CLICK OPEN IMAGE' : 'FAILED LONG_CLICK OPEN IMAGE');
              if (longOk) {
                await Future.delayed(const Duration(milliseconds: 400));
                ok = await _clickAny(['Download image', 'Download', 'Save image', 'دانلود تصویر', 'بارگیری تصویر', 'ذخیره تصویر'], trace);
              }
            }
          }
        }
        if (!ok) return LiveAgentResult(false, 'Google Images باز شد اما مرورگر گزینهٔ دانلود قابل اتکا نشان نداد', trace);
      }

      if (article && write) {
        if (!await _ensureAccessibility()) return LiveAgentResult(false, 'برای خواندن صفحه و نوشتن Note، Accessibility را برای Atlas One فعال کنید', trace);
        await observer.settle();
        final clicked = await actions.clickFirstMeaningfulLink();
        trace.add(clicked ? 'OPEN FIRST SEARCH RESULT' : 'FAILED FIRST SEARCH RESULT');
        if (clicked) {
          await Future.delayed(const Duration(milliseconds: 1000));
          collectedArticle = await _collectVisibleArticle(trace);
        }
      }
    }

    if (write) {
      if (!await _ensureAccessibility()) return LiveAgentResult(false, 'برای نوشتن Note، Accessibility را برای Atlas One فعال کنید', trace);
      final notesPackage = ToolRouter.notes(installedApps);
      if (notesPackage == null) return LiveAgentResult(false, 'برنامهٔ Notes/Keep روی گوشی پیدا نشد', trace);
      final text = (collectedArticle?.trim().isNotEmpty == true)
          ? collectedArticle!
          : (generatedText?.trim().isNotEmpty == true ? generatedText! : request);
      final ok = await _writeNote(notesPackage, text, trace);
      if (!ok) return LiveAgentResult(false, 'نوشتن Note کامل نشد', trace);
    }

    if (image && download && _has(q, ['show', 'نشان بده', 'نمایش بده', 'show it'])) {
      final filesPackage = ToolRouter.files(installedApps);
      if (filesPackage != null && await _ensureAccessibility()) {
        final ok = await _openDownloads(filesPackage, trace);
        if (!ok) {
          trace.add('DOWNLOADS NOT OPENED');
        } else {
          await Future.delayed(const Duration(milliseconds: 450));
          final openedFile = await actions.clickFirstFileCandidate();
          trace.add(openedFile ? 'OPEN DOWNLOADED FILE' : 'DOWNLOADS OPEN; FILE NOT AUTO-SELECTED');
        }
      }
    }

    // Generic app launch: "open Spotify", "Calculator را باز کن", etc.
    if (!research && !write && !wantsNotifications && !wantsRecents) {
      final package = _matchRequestedApp(request, installedApps);
      if (package != null) {
        final ok = await actions.openSelectedApp(package);
        trace.add(ok ? 'OPEN APP $package' : 'FAILED APP $package');
        return LiveAgentResult(ok, ok ? 'برنامه باز شد' : 'باز کردن برنامه ممکن نشد', trace);
      }
    }

    return LiveAgentResult(true, 'درخواست روی گوشی اجرا شد', trace);
  }


  String? _matchRequestedApp(String request, Map<String, String> apps) {
    final q = request.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff ._-]'), ' ');
    final stripped = q
        .replaceAll(RegExp(r'\b(open|launch|start|app|application|please)\b'), ' ')
        .replaceAll('باز کن', ' ')
        .replaceAll('بازش کن', ' ')
        .replaceAll('برنامه', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.isEmpty) return null;
    String? best;
    var bestScore = 0;
    for (final e in apps.entries) {
      final hay = '${e.key} ${e.value}'.toLowerCase();
      var score = 0;
      for (final token in stripped.split(' ')) {
        if (token.length >= 2 && hay.contains(token)) score += token.length;
      }
      if (score > bestScore) { bestScore = score; best = e.key; }
    }
    return bestScore >= 3 ? best : null;
  }

  Future<bool> _ensureAccessibility() async {
    if (await actions.accessibilityEnabled()) return true;
    await actions.requestAccessibility();
    return false;
  }

  bool _has(String q, List<String> xs) => xs.any(q.contains);

  String _cleanQuery(String q) {
    var x = q.replaceAll(RegExp(r'(?i)\b(open|google|search|download|show|save|find|from|and|to|me|a|an|the|write|note|notes|into|in)\b'), ' ');
    for (final token in ['جستجو', 'جست‌وجو', 'پیدا کن', 'گوگل', 'دانلود کن', 'نشان بده', 'نمایش بده', 'در اینترنت', 'توی note', 'توی نوت', 'در note', 'در نوت', 'بنویس']) {
      x = x.replaceAll(token, ' ');
    }
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x.isEmpty ? q.trim() : x;
  }

  Future<bool> _clickAny(List<String> labels, List<String> trace) async {
    var s = await observer.state();
    for (final label in labels) {
      final n = s.findAny([label]);
      if (n?.viewId.isNotEmpty == true && await actions.clickViewId(n!.viewId)) {
        trace.add('CLICK_ID ${n.viewId}');
        await observer.settle();
        return true;
      }
      if (await actions.clickText(label)) {
        trace.add('CLICK_TEXT $label');
        await observer.settle();
        return true;
      }
    }
    return false;
  }

  Future<bool> _open(String package, List<String> expected, List<String> trace) async {
    if (!await actions.openSelectedApp(package)) return false;
    trace.add('OPEN $package');
    await Future.delayed(const Duration(milliseconds: 700));
    final s = await observer.settle();
    trace.add('OBSERVE ${s.packageName} nodes=${s.nodes.length}');
    return s.packageName.isNotEmpty || expected.any(s.contains);
  }

  Future<bool> _type(String text, List<String> trace) async {
    var s = await observer.state();
    if (!s.hasEditable) {
      await _clickAny(['Search', 'Search Google', 'جستجو', 'جست‌وجو', 'Take a note', 'یادداشت', 'Title', 'عنوان'], trace);
      s = await observer.state();
    }
    final ok = await actions.setText(text) || await actions.setFirstEditableText(text);
    if (ok) {
      trace.add('TYPE ${text.length} chars');
      await Future.delayed(const Duration(milliseconds: 180));
    }
    return ok;
  }

  Future<String> _collectVisibleArticle(List<String> trace) async {
    final seen = <String>{};
    final out = <String>[];
    for (var page = 0; page < 4; page++) {
      final s = await observer.settle();
      for (final n in s.nodes) {
        final t = n.text.trim();
        if (t.length >= 18 && t.length <= 600 && seen.add(t)) out.add(t);
      }
      if (page < 3) {
        final ok = await actions.scroll(1);
        trace.add(ok ? 'SCROLL ARTICLE' : 'ARTICLE END');
        if (!ok) break;
        await Future.delayed(const Duration(milliseconds: 450));
      }
    }
    final text = out.join('\n\n');
    trace.add('COLLECT ARTICLE ${text.length} chars');
    return text.length > 6000 ? text.substring(0, 6000) : text;
  }

  Future<bool> _openDownloads(String package, List<String> trace) async {
    if (!await _open(package, ['files', 'my files', 'downloads', 'دانلود'], trace)) return false;
    final s = await observer.state();
    if (s.contains('downloads') || s.contains('دانلود')) {
      if (await _clickAny(['Downloads', 'Download', 'دانلودها', 'بارگیری‌ها'], trace)) return true;
      return true;
    }
    if (await _clickAny(['Downloads', 'Download', 'دانلودها', 'بارگیری‌ها'], trace)) return true;
    await actions.back();
    await Future.delayed(const Duration(milliseconds: 300));
    return _clickAny(['Downloads', 'دانلودها'], trace);
  }

  Future<bool> _writeNote(String package, String text, List<String> trace) async {
    if (!await _open(package, ['note', 'keep', 'یادداشت'], trace)) return false;
    await _clickAny(['Take a note', 'New note', 'Create', 'Add', '+', 'یادداشت جدید', 'ایجاد'], trace);
    if (!await _type(text, trace)) return false;
    trace.add('VERIFY NOTE TEXT');
    final probe = text.substring(0, text.length > 20 ? 20 : text.length);
    return observer.waitFor((s) => s.nodes.any((n) => n.text.contains(probe)), attempts: 5);
  }
}

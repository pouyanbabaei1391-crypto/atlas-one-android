import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'settings_service.dart';

class AiAction {
  final String type;
  final String? appId;
  final String? uri;

  const AiAction({required this.type, this.appId, this.uri});

  factory AiAction.fromJson(Map<String, dynamic> json) => AiAction(
        type: (json['type'] ?? '').toString(),
        appId: json['app_id']?.toString(),
        uri: json['uri']?.toString(),
      );
}

class AiTurn {
  final String reply;
  final List<AiAction> actions;

  const AiTurn({required this.reply, this.actions = const []});
}

class AiService {
  final SettingsService settings;
  AiService(this.settings);

  Future<AiTurn> chat({
    required List<ChatMessage> history,
    required String userText,
    String? imageBase64,
    String? memoryContext,
    Map<String, String> allowedApps = const {},
  }) async {
    final base = (await settings.baseUrl).replaceAll(RegExp(r'/$'), '');
    final model = await settings.model;
    final key = await settings.apiKey;

    final appLines = allowedApps.entries
        .map((entry) => '- ${entry.key}: ${entry.value}')
        .join('\n');

    final system = '''
تو Atlas One هستی؛ دستیار خصوصی فارسی‌زبان کاربر.
پاسخ مکالمه را فارسی روان، دقیق و طبیعی بنویس مگر اینکه کاربر زبان دیگری بخواهد.

امنیت و اختیار کاربر:
- فقط اپ‌هایی را می‌توانی باز کنی که کاربر صریحاً در Atlas انتخاب کرده است.
- هرگز ادعا نکن که می‌توانی محدودیت‌های Android یا iOS را دور بزنی.
- عملیات حساس مالی، حذف داده، تغییر حساب/رمز یا ارسال نهایی پیام باید قبل از اجرا به کاربر نشان داده و تأیید شوند.
- Screen Vision و Camera فقط با مجوز سیستم فعال‌اند.

اپ‌های مجاز در این لحظه:
${appLines.isEmpty ? '(هیچ اپی انتخاب نشده است)' : appLines}

اگر لازم است یک اپ مجاز فقط باز شود، یک action با type=open_app و app_id دقیق بده.
اگر لازم است یک URI امن باز شود، action با type=open_uri و uri بده. schemeهای مجاز عبارت‌اند از https/http/mailto/tel/sms/geo.
برای کنترل داخلی اپ‌ها action خیالی تولید نکن؛ فقط از API/Intent/Deep Link رسمی استفاده می‌شود.

فقط JSON معتبر با این ساختار برگردان:
{"reply":"پاسخ فارسی","actions":[{"type":"open_app","app_id":"..."},{"type":"open_uri","uri":"..."}]}
اگر اقدامی لازم نیست actions باید [] باشد.
${memoryContext == null || memoryContext.trim().isEmpty ? '' : '\nزمینه حافظه مرتبط:\n$memoryContext'}
''';

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      ...history.take(24).map((m) => {'role': m.role, 'content': m.content}),
    ];

    if (imageBase64 == null) {
      messages.add({'role': 'user', 'content': userText});
    } else {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userText},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'}
          }
        ]
      });
    }

    final endpoint = Uri.parse('$base/chat/completions');
    final headers = {
      'content-type': 'application/json',
      if (key.isNotEmpty) 'authorization': 'Bearer $key',
    };

    Future<http.Response> postChat({required bool requestJsonMode}) {
      return http
          .post(
            endpoint,
            headers: headers,
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': 0.25,
              'stream': false,
              if (requestJsonMode) 'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 90));
    }

    var response = await postChat(requestJsonMode: true);
    if (response.statusCode == 400 || response.statusCode == 422) {
      // Some OpenAI-compatible local servers do not implement response_format.
      response = await postChat(requestJsonMode: false);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final raw = _extractContent(decoded);
    return _parseTurn(raw);
  }

  String _extractContent(Map<String, dynamic> response) {
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('AI response has no choices');
    }
    final message = choices.first['message'];
    if (message is! Map) throw const FormatException('AI response has no message');
    final content = message['content'];
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((part) => part['text']?.toString() ?? '')
          .where((text) => text.isNotEmpty)
          .join('\n');
    }
    return content?.toString() ?? '';
  }

  AiTurn _parseTurn(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        final reply = (parsed['reply'] ?? '').toString().trim();
        final actionsRaw = parsed['actions'];
        final actions = <AiAction>[];
        if (actionsRaw is List) {
          for (final item in actionsRaw) {
            if (item is Map) {
              actions.add(AiAction.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        return AiTurn(reply: reply.isEmpty ? 'انجام شد.' : reply, actions: actions);
      }
    } catch (_) {
      // Some OpenAI-compatible local servers ignore response_format.
    }
    return AiTurn(reply: raw.trim().isEmpty ? 'پاسخی دریافت نشد.' : raw.trim());
  }

  Future<List<double>?> embedding(String text) async {
    try {
      final base = (await settings.baseUrl).replaceAll(RegExp(r'/$'), '');
      final key = await settings.apiKey;
      final embeddingModel = await settings.embeddingModel;
      final response = await http
          .post(
            Uri.parse('$base/embeddings'),
            headers: {
              'content-type': 'application/json',
              if (key.isNotEmpty) 'authorization': 'Bearer $key',
            },
            body: jsonEncode({'model': embeddingModel, 'input': text}),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final j = jsonDecode(utf8.decode(response.bodyBytes));
      return (j['data'][0]['embedding'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } catch (_) {
      return null;
    }
  }
}

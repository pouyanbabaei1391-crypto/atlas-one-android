import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'settings_service.dart';

class AiService {
  final SettingsService settings;
  AiService(this.settings);

  Future<String> chat({
    required List<ChatMessage> history,
    required String userText,
    String? imageBase64,
    String? memoryContext,
  }) async {
    final base = (await settings.baseUrl).replaceAll(RegExp(r'/$'), '');
    final model = await settings.model;
    final key = await settings.apiKey;
    final system = '''
تو Atlas One هستی؛ دستیار خصوصی فارسی‌زبان کاربر. پاسخ اصلی را به فارسی روان، دقیق و کوتاه بده مگر اینکه کاربر زبان دیگری بخواهد.
هیچ اقدام خارجی را بدون مجوز صریح کاربر انجام نده. برای کارهای حساس قبل از اجرا تأیید بگیر.
اگر زمینه حافظه ارائه شد، فقط در صورت ارتباط واقعی از آن استفاده کن.
${memoryContext == null ? '' : 'زمینه حافظه:\n$memoryContext'}
''';
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      ...history.take(20).map((m) => {'role': m.role, 'content': m.content}),
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

    final response = await http.post(
      Uri.parse('$base/chat/completions'),
      headers: {
        'content-type': 'application/json',
        if (key.isNotEmpty) 'authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.35,
        'stream': false,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI HTTP ${response.statusCode}: ${response.body}');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return json['choices'][0]['message']['content'] as String;
  }

  Future<List<double>?> embedding(String text) async {
    try {
      final base = (await settings.baseUrl).replaceAll(RegExp(r'/$'), '');
      final key = await settings.apiKey;
      final response = await http.post(
        Uri.parse('$base/embeddings'),
        headers: {
          'content-type': 'application/json',
          if (key.isNotEmpty) 'authorization': 'Bearer $key',
        },
        body: jsonEncode({'model': 'embeddinggemma', 'input': text}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final j = jsonDecode(utf8.decode(response.bodyBytes));
      return (j['data'][0]['embedding'] as List).map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }
}

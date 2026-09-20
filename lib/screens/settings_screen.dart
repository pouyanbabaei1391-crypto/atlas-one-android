import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/assistant_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final name = TextEditingController();
  final base = TextEditingController();
  final model = TextEditingController();
  final key = TextEditingController();
  bool loaded = false;

  Future<void> _load() async {
    if (loaded) return;
    final c = context.read<AssistantController>();
    name.text = await c.settings.userName;
    base.text = await c.settings.baseUrl;
    model.text = await c.settings.model;
    key.text = await c.settings.apiKey;
    loaded = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _load();
    final c = context.watch<AssistantController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'نام کاربر')),
        const SizedBox(height: 12),
        TextField(controller: base, decoration: const InputDecoration(labelText: 'OpenAI-compatible Base URL')),
        const SizedBox(height: 12),
        TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
        const SizedBox(height: 12),
        TextField(controller: key, obscureText: true, decoration: const InputDecoration(labelText: 'API key (optional)')),
        const SizedBox(height: 18),
        FilledButton(onPressed: () async {
          await c.settings.setUserName(name.text);
          await c.settings.setBaseUrl(base.text);
          await c.settings.setModel(model.text);
          await c.settings.setApiKey(key.text);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد')));
        }, child: const Text('ذخیره تنظیمات')),
        const Divider(height: 34),
        ListTile(title: const Text('حذف کامل حافظه Atlas'), subtitle: const Text('تمام مکالمات ذخیره‌شده در حافظه محلی رمز‌شده حذف می‌شوند.'), trailing: FilledButton.tonal(onPressed: () async { await c.wipeMemory(); }, child: const Text('DELETE'))),
      ]),
    );
  }
}

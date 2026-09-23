import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assistant_controller.dart';
import 'dart:io';
import 'local_ai_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final name = TextEditingController();
  final base = TextEditingController();
  final model = TextEditingController();
  final embeddingModel = TextEditingController();
  final key = TextEditingController();
  bool loaded = false;

  Future<void> _load() async {
    if (loaded) return;
    final c = context.read<AssistantController>();
    name.text = await c.settings.userName;
    base.text = await c.settings.baseUrl;
    model.text = await c.settings.model;
    embeddingModel.text = await c.settings.embeddingModel;
    key.text = await c.settings.apiKey;
    loaded = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    name.dispose();
    base.dispose();
    model.dispose();
    embeddingModel.dispose();
    key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _load();
    final c = context.watch<AssistantController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Atlas Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (Platform.isAndroid) ...[
            SwitchListTile(
              title: const Text('Hybrid: Cloud speed + local Gemma'),
              subtitle: const Text('Cloud answers voice turns first when configured; Gemma remains the private automatic fallback.'),
              value: c.localAiEnabled,
              onChanged: c.busy || c.microphoneEnabled || c.voiceStarting ? null : c.setLocalAiEnabled,
            ),
            ListTile(title: const Text('Local AI setup'), trailing: const Icon(Icons.chevron_right),
              onTap: c.busy || c.microphoneEnabled ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalAiScreen()))),
            const Divider(),
          ],
          TextField(
            controller: name,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: base,
            decoration: const InputDecoration(
              labelText: 'AI server URL',
              hintText: 'https://api.groq.com/openai/v1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: model,
            decoration: const InputDecoration(labelText: 'Chat and vision model'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: embeddingModel,
            decoration: const InputDecoration(labelText: 'Embedding model'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Groq API key (or leave empty for your secure Gateway)',
              helperText: 'Stored in Android encrypted storage. A Gateway is safer for public releases.',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              await c.settings.setUserName(name.text);
              await c.settings.setBaseUrl(base.text);
              await c.settings.setModel(model.text);
              await c.settings.setEmbeddingModel(embeddingModel.text);
              await c.settings.setApiKey(key.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved')),
                );
              }
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save settings'),
          ),
          const Divider(height: 34),
          SwitchListTile(
            value: c.memoryEnabled,
            onChanged: c.setMemoryEnabled,
            title: const Text('Long-term memory'),
            subtitle: const Text('Encrypted conversation storage and semantic recall'),
          ),
          ListTile(
            title: const Text('Clear Atlas memory'),
            subtitle: const Text(
              'Deletes all conversations stored in encrypted local memory.',
            ),
            trailing: FilledButton.tonal(
              onPressed: () async {
                await c.wipeMemory();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Memory cleared')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }
}

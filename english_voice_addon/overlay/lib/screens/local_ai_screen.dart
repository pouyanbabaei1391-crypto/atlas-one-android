import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/assistant_controller.dart';
import '../core/local_gemma_service.dart';

class LocalAiScreen extends StatefulWidget {
  const LocalAiScreen({super.key});
  @override
  State<LocalAiScreen> createState() => _LocalAiScreenState();
}
class _LocalAiScreenState extends State<LocalAiScreen> {
  bool accepted = false;
  @override
  void initState() {
    super.initState();
    final c = context.read<AssistantController>();
    c.settings.modelTermsAccepted.then((value) { if (mounted) setState(() => accepted = value); });
  }
  @override
  Widget build(BuildContext context) {
    final c = context.read<AssistantController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Local AI setup')),
      body: AnimatedBuilder(
        animation: LocalGemmaService.instance,
        builder: (context, _) {
          final model = LocalGemmaService.instance;
          final labels = {'not_installed': 'Model not installed', 'installing': 'Installing model…',
            'verifying': 'Verifying model integrity…', 'installed': 'Installed; ready to load',
            'loading': 'Loading and warming Qwen3…', 'ready': 'Ready on this phone', 'generating': 'Generating locally…'};
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text('Qwen3 · 1.7B · Q4_K_M', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text('Qwen3 runs directly on your phone and becomes the primary voice model after setup. Cloud remains only the existing fallback when configured.'),
            const SizedBox(height: 12),
            const Text('Model size: 1.11 GB. An already verified model is reused and loaded without another download. If it is absent, setup downloads it once and resumes interrupted downloads.'),
            const SizedBox(height: 8),
            const Text('Allow at least 1.5 GB of free storage in addition to the APK. The model also needs available RAM; other apps and your phone hardware affect speed.'),
            const SizedBox(height: 18),
            Text(labels[model.state] ?? model.state, style: Theme.of(context).textTheme.titleMedium),
            if (model.preparing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: model.state == 'installing' ? model.progress.clamp(0.0, 1.0).toDouble() : null),
              if (model.state == 'installing') Text('${(model.progress * 100).toStringAsFixed(1)}%'),
            ],
            if (model.error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: SelectableText(model.error!)),
            if (!model.ready && !model.preparing) ...[
              CheckboxListTile(value: accepted, onChanged: (value) => setState(() => accepted = value ?? false),
                contentPadding: EdgeInsets.zero, title: const Text('I agree to the Qwen3 Apache 2.0 license and model terms.')),
              TextButton(onPressed: () => launchUrl(Uri.parse('https://huggingface.co/Qwen/Qwen3-1.7B/blob/main/LICENSE')), child: const Text('Read Qwen3 license')),
              TextButton(onPressed: () => launchUrl(Uri.parse('https://huggingface.co/Qwen/Qwen3-1.7B')), child: const Text('Read model card')),
              FilledButton.icon(onPressed: !accepted ? null : () async {
                await c.settings.acceptModelTerms();
                await c.prepareLocalAi();
              }, icon: const Icon(Icons.download_rounded),
                label: Text(model.installed ? 'Load Qwen3 on this phone' : 'Install and prepare Qwen3')),
            ],
            if (model.preparing) TextButton(onPressed: () => model.cancel(), child: const Text('Cancel setup')),
            if (model.ready) FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Continue to voice chat')),
          ]);
        },
      ),
    );
  }
}

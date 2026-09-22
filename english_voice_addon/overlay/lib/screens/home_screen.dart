import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assistant_controller.dart';
import '../models/app_target.dart';
import 'settings_screen.dart';
import 'local_ai_screen.dart';
import '../core/local_gemma_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AssistantController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atlas Local · Gemma 3'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.busy ? Colors.amber : Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.status,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (c.busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 78,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _FeatureCard(
                    icon: Icons.mic_rounded,
                    title: 'Microphone',
                    subtitle: 'Speak in English',
                    active: c.microphoneEnabled,
                    onChanged: c.toggleMicrophone,
                  ),
                  _FeatureCard(
                    icon: Icons.visibility_rounded,
                    title: 'Screen Vision',
                    subtitle: 'With your permission',
                    active: c.screenVisionEnabled,
                    onChanged: c.toggleScreenVision,
                  ),
                  _FeatureCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'Camera',
                    subtitle: 'Preview hidden',
                    active: c.cameraEnabled,
                    onChanged: c.toggleCamera,
                  ),
                  _FeatureCard(
                    icon: Icons.apps_rounded,
                    title: 'Apps',
                    subtitle: 'Selected apps',
                    active: c.appActions.enabled,
                    onChanged: (enabled) async {
                      if (enabled) {
                        await c.loadApps();
                        if (context.mounted) _showApps(context);
                      } else {
                        for (final app in [...c.apps]) {
                          if (app.selected) c.setAppSelected(app.id, false);
                        }
                      }
                    },
                  ),
                  _FeatureCard(
                    icon: Icons.memory_rounded,
                    title: 'Memory',
                    subtitle: 'Encrypted memory',
                    active: c.memoryEnabled,
                    onChanged: (enabled) async => c.setMemoryEnabled(enabled),
                  ),
                ],
              ),
            ),
            if (c.localAiEnabled)
              AnimatedBuilder(
                animation: LocalGemmaService.instance,
                builder: (context, _) => ListTile(
                  leading: const Icon(Icons.memory_rounded),
                  title: Text(c.ai.local.ready ? 'Gemma 3 4B · On this phone' : 'Prepare your local AI'),
                  subtitle: Text(c.ai.local.ready ? 'No AI server required' : 'One-time model setup required'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: c.busy || c.microphoneEnabled ? null : () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LocalAiScreen())),
                ),
              ),
            if (c.liveTranscript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 65),
                    child: SingleChildScrollView(
                      child: Text(c.liveTranscript, textDirection: TextDirection.ltr),
                    ),
                  ),
                ),
              ),
            if (c.voiceWarning != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(c.voiceWarning!, textDirection: TextDirection.ltr),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: c.messages.length + (c.streamingReply.isEmpty ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == c.messages.length) {
                    return Padding(
                      padding: const EdgeInsets.all(13),
                      child: Text(c.streamingReply, textDirection: TextDirection.ltr),
                    );
                  }
                  final message = c.messages[index];
                  final mine = message.role == 'user';
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(message.content, textDirection: TextDirection.ltr),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                children: [
                  if (c.screenVisionEnabled || c.cameraEnabled)
                    Row(
                      children: [
                        if (c.screenVisionEnabled)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: c.busy
                                  ? null
                                  : () => c.inspectScreen(
                                        'Analyze the current screen and explain the key points and available actions.',
                                      ),
                              icon: const Icon(Icons.visibility_rounded),
                              label: const Text('Analyze screen'),
                            ),
                          ),
                        if (c.screenVisionEnabled && c.cameraEnabled)
                          const SizedBox(width: 8),
                        if (c.cameraEnabled)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: c.busy
                                  ? null
                                  : () => c.inspectCamera(
                                        'Briefly and accurately describe what the camera sees.',
                                      ),
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: const Text('Analyze camera'),
                            ),
                          ),
                      ],
                    ),
                  if (c.cameraEnabled)
                    TextButton(
                      onPressed: c.busy ? null : c.switchCamera,
                      child: const Text('Switch front and rear cameras'),
                    ),
                  if (c.busy)
                    TextButton.icon(
                      onPressed: c.interruptAndListen,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(c.microphoneEnabled
                          ? 'Interrupt and speak'
                          : 'Stop response'),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => c.killSwitch(revokeOsPermissions: true),
                        icon: const Icon(Icons.power_settings_new_rounded),
                        tooltip: 'Turn everything off',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: c.voiceStarting || c.testingSpeaker ? null : () => c.toggleMicrophone(!c.microphoneEnabled),
                          icon: Icon(c.microphoneEnabled ? Icons.mic_off_rounded : Icons.mic_rounded),
                          label: Text(c.voiceStarting ? 'Starting voice…' : c.microphoneEnabled ? 'End voice chat' : 'Start voice chat'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Speak naturally in English.', textAlign: TextAlign.center),
                  if (c.firstSpeechMilliseconds != null)
                    Text('Speech started in ${c.firstSpeechMilliseconds} ms'),
                  if (c.microphoneEnabled) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: c.microphoneLevel),
                    const Text('Microphone input level'),
                  ],
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: c.microphoneEnabled || c.voiceStarting || c.busy || c.testingSpeaker ? null : c.testSpeaker,
                        icon: const Icon(Icons.volume_up_rounded),
                        label: Text(c.testingSpeaker ? 'Testing speaker…' : 'Test speaker'),
                      ),
                      TextButton.icon(
                        onPressed: c.busy ? null : c.testAiConnection,
                        icon: const Icon(Icons.network_check),
                        label: Text(c.localAiEnabled ? 'Check local model' : 'Test AI connection'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Retained for source compatibility; the voice-only screen never builds this.
  // ignore: unused_element
  Widget _legacyComposer(AssistantController c) {
    return Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => c.killSwitch(revokeOsPermissions: true),
                        icon: const Icon(Icons.power_settings_new_rounded),
                        tooltip: 'Turn everything off',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textDirection: TextDirection.ltr,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Talk to Atlas…',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _send(c),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: c.busy ? null : () => _send(c),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  );
  }

  void _send(AssistantController controller) {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    controller.send(text);
  }

  void _showApps(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Consumer<AssistantController>(
        builder: (_, c, __) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .78,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Text(
                    'Your allowed apps',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Atlas opens only the apps you select, using their official features.',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: c.apps.isEmpty
                      ? const Center(child: Text('No accessible apps found.'))
                      : ListView.builder(
                          itemCount: c.apps.length,
                          itemBuilder: (_, index) {
                            final app = c.apps[index];
                            return _AppTile(app: app, controller: c);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final AppTarget app;
  final AssistantController controller;

  const _AppTile({required this.app, required this.controller});

  @override
  Widget build(BuildContext context) {
    Widget leading = const CircleAvatar(child: Icon(Icons.apps_rounded));
    if (app.iconBase64 != null && app.iconBase64!.isNotEmpty) {
      try {
        leading = CircleAvatar(
          backgroundColor: Colors.transparent,
          backgroundImage: MemoryImage(base64Decode(app.iconBase64!)),
        );
      } catch (_) {}
    }

    return CheckboxListTile(
      value: app.selected,
      onChanged: (value) => controller.setAppSelected(app.id, value ?? false),
      secondary: leading,
      title: Text(app.name),
      subtitle: Text(app.id, maxLines: 1, overflow: TextOverflow.ellipsis),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      shape: const Border(bottom: BorderSide(width: .15)),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final Future<void> Function(bool) onChanged;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 176,
    child: SwitchListTile(
      dense: true,
      title: Text(title, textDirection: TextDirection.ltr),
      value: active,
      onChanged: onChanged,
    ),
  );
}

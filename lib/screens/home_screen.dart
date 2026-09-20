import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assistant_controller.dart';
import '../models/app_target.dart';
import 'settings_screen.dart';

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ATLAS ONE', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('PRIVATE MOBILE AI', style: TextStyle(fontSize: 10, letterSpacing: 1.5)),
          ],
        ),
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
                      textDirection: TextDirection.rtl,
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
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _FeatureCard(
                    icon: Icons.mic_rounded,
                    title: 'Microphone',
                    subtitle: 'Persian STT + TTS',
                    active: c.microphoneEnabled,
                    onChanged: c.toggleMicrophone,
                  ),
                  _FeatureCard(
                    icon: Icons.visibility_rounded,
                    title: 'Screen Vision',
                    subtitle: 'Live frame with OS consent',
                    active: c.screenVisionEnabled,
                    onChanged: c.toggleScreenVision,
                  ),
                  _FeatureCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'Camera',
                    subtitle: 'Front-camera Vision',
                    active: c.cameraEnabled,
                    onChanged: c.toggleCamera,
                  ),
                  _FeatureCard(
                    icon: Icons.apps_rounded,
                    title: 'Autonomous Apps',
                    subtitle: 'User-selected integrations',
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
                    subtitle: 'Encrypted long-term memory',
                    active: c.memoryEnabled,
                    onChanged: (enabled) async => c.setMemoryEnabled(enabled),
                  ),
                ],
              ),
            ),
            if (c.cameraEnabled && c.camera.controller?.value.isInitialized == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: CameraPreview(c.camera.controller!),
                  ),
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
                  child: Text(
                    '🎙 ${c.liveTranscript}',
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: c.messages.length,
                itemBuilder: (context, index) {
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
                      child: Text(message.content, textDirection: TextDirection.rtl),
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
                                        'صفحه‌ای که الان می‌بینی را تحلیل کن و مهم‌ترین نکات و اقدام‌های ممکن را بگو.',
                                      ),
                              icon: const Icon(Icons.visibility_rounded),
                              label: const Text('تحلیل صفحه'),
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
                                        'آنچه دوربین می‌بیند را دقیق و کوتاه توضیح بده.',
                                      ),
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: const Text('تحلیل دوربین'),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => c.killSwitch(revokeOsPermissions: true),
                        icon: const Icon(Icons.power_settings_new_rounded),
                        tooltip: 'Kill Switch',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textDirection: TextDirection.rtl,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'با Atlas صحبت کن…',
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                    'Autonomous Work with Applications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'فقط اپ‌هایی که خودت انتخاب می‌کنی در allow-list قرار می‌گیرند. Atlas می‌تواند آن‌ها را باز کند و از Intent / Deep Link / API رسمی استفاده کند؛ سیستم‌عامل اجازه کنترل مخفی و نامحدود UI همه اپ‌ها را نمی‌دهد.',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: c.apps.isEmpty
                      ? const Center(child: Text('اپ قابل دسترسی پیدا نشد.'))
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
  Widget build(BuildContext context) => Container(
        width: 184,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
                    Theme.of(context).colorScheme.surface.withValues(alpha: .9),
                  ],
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const Spacer(),
                Switch(value: active, onChanged: onChanged),
              ],
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

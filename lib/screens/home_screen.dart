import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/assistant_controller.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _input = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AssistantController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ATLAS ONE'),
        actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.tune))],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Expanded(child: Text(c.status, style: Theme.of(context).textTheme.bodySmall)),
                if (c.busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
            ),
            SizedBox(
              height: 154,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _FeatureCard(icon: Icons.mic, title: 'Microphone', subtitle: 'STT + TTS فارسی', active: c.microphoneEnabled, onChanged: c.toggleMicrophone),
                  _FeatureCard(icon: Icons.visibility, title: 'Screen Vision', subtitle: 'با تأیید سیستم', active: c.screenVisionEnabled, onChanged: c.toggleScreenVision),
                  _FeatureCard(icon: Icons.camera_alt, title: 'Camera', subtitle: 'Vision زنده درون اپ', active: c.cameraEnabled, onChanged: c.toggleCamera),
                  _FeatureCard(icon: Icons.apps, title: 'Autonomous Apps', subtitle: 'فقط اپ‌های انتخاب‌شده', active: c.appActions.enabled, onChanged: (v) async { if (v) { await c.loadApps(); _showApps(context); } else { for (final a in [...c.apps]) { if (a.selected) c.setAppSelected(a.id, false); } } }),
                  _FeatureCard(icon: Icons.memory, title: 'Memory', subtitle: 'رمزشده روی دستگاه', active: c.memoryEnabled, onChanged: (v) async { c.setMemoryEnabled(v); }),
                ],
              ),
            ),
            if (c.cameraEnabled && c.camera.controller?.value.isInitialized == true)
              SizedBox(height: 170, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CameraPreview(c.camera.controller!))),
            if (c.liveTranscript.isNotEmpty)
              Padding(padding: const EdgeInsets.all(8), child: Text('🎙 ${c.liveTranscript}', textDirection: TextDirection.rtl)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: c.messages.length,
                itemBuilder: (context, i) {
                  final m = c.messages[i];
                  final mine = m.role == 'user';
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(m.content, textDirection: TextDirection.rtl),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                if (c.screenVisionEnabled || c.cameraEnabled)
                  Row(children: [
                    if (c.screenVisionEnabled) Expanded(child: OutlinedButton.icon(onPressed: () => c.inspectScreen('صفحه‌ای که الان می‌بینی را تحلیل کن و بگو چه چیزی مهم است.'), icon: const Icon(Icons.visibility), label: const Text('تحلیل صفحه'))),
                    if (c.screenVisionEnabled && c.cameraEnabled) const SizedBox(width: 8),
                    if (c.cameraEnabled) Expanded(child: OutlinedButton.icon(onPressed: () => c.inspectCamera('آنچه دوربین می‌بیند را دقیق و کوتاه توضیح بده.'), icon: const Icon(Icons.camera_alt), label: const Text('تحلیل دوربین'))),
                  ]),
                const SizedBox(height: 6),
                Row(children: [
                  IconButton.filledTonal(onPressed: () => c.killSwitch(revokeOsPermissions: true), icon: const Icon(Icons.power_settings_new), tooltip: 'Kill Switch'),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _input, textDirection: TextDirection.rtl, decoration: const InputDecoration(hintText: 'با Atlas صحبت کن…', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: c.busy ? null : () { final t = _input.text.trim(); if (t.isNotEmpty) { _input.clear(); c.send(t); } }, icon: const Icon(Icons.send)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showApps(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Consumer<AssistantController>(builder: (_, c, __) => SafeArea(child: SizedBox(
        height: MediaQuery.of(context).size.height * .72,
        child: Column(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('اپ‌هایی که Atlas اجازه دارد باز کند', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('کنترل هر اپ فقط از طریق API / Intent / Deep Link رسمی آن اپ انجام می‌شود.')),
          Expanded(child: ListView.builder(itemCount: c.apps.length, itemBuilder: (_, i) {
            final a = c.apps[i];
            return CheckboxListTile(value: a.selected, onChanged: (v) => c.setAppSelected(a.id, v ?? false), title: Text(a.name), subtitle: Text(a.id));
          })),
        ]),
      ))),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final Future<void> Function(bool) onChanged;
  const _FeatureCard({required this.icon, required this.title, required this.subtitle, required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    width: 176,
    margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon), const Spacer(), Switch(value: active, onChanged: onChanged)]),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}

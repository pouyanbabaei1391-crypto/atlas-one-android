import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../language/english_coach_controller.dart';
import '../language/lesson_turn.dart';
import '../widgets/veltrix_avatar.dart';

const _bg = Color(0xFF0B1119);
const _surface = Color(0xFF131D28);
const _border = Color(0xFF334454);
const _secondary = Color(0xFF96AFC2);
const _white = Color(0xFFF1F5FA);

class VeltrixHomeScreen extends StatefulWidget {
  const VeltrixHomeScreen({super.key});
  @override
  State<VeltrixHomeScreen> createState() => _VeltrixHomeScreenState();
}

class _VeltrixHomeScreenState extends State<VeltrixHomeScreen> {
  final _input = TextEditingController();
  @override
  void dispose() { _input.dispose(); super.dispose(); }

  void _send(EnglishCoachController coach, [String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    coach.send(text);
  }

  void _settings(EnglishCoachController coach) {
    final controller = TextEditingController(text: coach.endpoint);
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF14202D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 26),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MODEL CONNECTION', style: TextStyle(color: veltrixMint, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 14),
          const Text('Gemma 3 · 4B', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Connect to Ollama running on a computer or local server. Use the computer’s LAN IP, not localhost, when testing on a phone.',
            style: TextStyle(color: _secondary, height: 1.55)),
          const SizedBox(height: 18),
          TextField(controller: controller, keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputStyle('http://192.168.1.10:11434/v1')),
          const SizedBox(height: 12),
          const Text('On the host: ollama pull gemma3:4b. Configure Ollama to listen on your LAN and allow your phone through its firewall. Treat the model endpoint as private.',
            style: TextStyle(color: _secondary, fontSize: 12, height: 1.55)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () async {
              await coach.setEndpoint(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: veltrixMint, foregroundColor: _bg,
              padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Save & test connection'),
          )),
        ]),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final coach = context.watch<EnglishCoachController>();
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        final header = _Header(coach: coach, onSettings: () => _settings(coach));
        if (wide) {
          return Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1640),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                header,
                Expanded(child: Row(children: [
                  Expanded(flex: 51, child: VeltrixStage(state: coach.state, status: coach.message)),
                  Container(width: 1, color: _border),
                  Expanded(flex: 49, child: _TeachingPanel(coach: coach,
                    input: _input, onSend: (text) => _send(coach, text), compact: false)),
                ])),
              ]),
            ),
          ));
        }
        return Container(
          decoration: BoxDecoration(border: Border.all(color: _border)),
          child: Column(children: [
            header,
            Expanded(child: SingleChildScrollView(
              child: Column(children: [
                SizedBox(height: constraints.maxWidth < 450 ? 270 : 340,
                  child: VeltrixStage(state: coach.state, status: coach.message)),
                _TeachingPanel(coach: coach, input: _input,
                  onSend: (text) => _send(coach, text), compact: true),
              ]),
            )),
          ]),
        );
      })),
    );
  }
}

class _Header extends StatelessWidget {
  final EnglishCoachController coach;
  final VoidCallback onSettings;
  const _Header({required this.coach, required this.onSettings});
  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 19),
    decoration: const BoxDecoration(color: Color(0xFF141C27),
      border: Border(bottom: BorderSide(color: _border))),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: const BoxDecoration(
        shape: BoxShape.circle, color: veltrixMint)),
      const SizedBox(width: 11),
      const Text('VELTRIX AI', style: TextStyle(color: Colors.white,
        fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.25)),
      const SizedBox(width: 11),
      Container(height: 17, width: 1, color: _border),
      const SizedBox(width: 11),
      const Flexible(child: Text('ENGLISH MASTERY', overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Color(0xFFA0BDDC), fontSize: 10, letterSpacing: 1.2))),
      const Spacer(),
      if (MediaQuery.sizeOf(context).width > 690)
        const Text('GEMMA 3:4B · LANGUAGE STUDIO', style: TextStyle(color: _secondary, fontSize: 9)),
      IconButton(icon: const Icon(Icons.tune, size: 21),
        tooltip: 'Model settings', onPressed: onSettings, color: _secondary),
    ]),
  );
}

class _TeachingPanel extends StatelessWidget {
  final EnglishCoachController coach;
  final TextEditingController input;
  final ValueChanged<String?> onSend;
  final bool compact;
  const _TeachingPanel({required this.coach, required this.input,
    required this.onSend, required this.compact});

  @override
  Widget build(BuildContext context) {
    final head = Padding(padding: const EdgeInsets.fromLTRB(26, 29, 26, 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('INTERACTIVE AI / LANGUAGE MODEL', style: TextStyle(
            fontSize: 10, color: Color(0xFF86A1B7), letterSpacing: 1.8, fontWeight: FontWeight.w700)),
          const Spacer(),
          Icon(coach.modelAvailable ? Icons.check : Icons.wifi_off,
            color: coach.modelAvailable ? veltrixMint : const Color(0xFFE4AD78), size: 15),
          const SizedBox(width: 6),
          Flexible(child: Text(coach.modelAvailable ? 'MODEL ONLINE' : 'CONNECT MODEL',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: coach.modelAvailable ? veltrixMint : const Color(0xFFE4AD78),
              fontSize: 10, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 19),
        const Text('Meet your AI.', style: TextStyle(color: _white,
          fontSize: 37, height: 1.06, letterSpacing: -1.9, fontWeight: FontWeight.w800)),
        const Text('Master your English.', style: TextStyle(color: veltrixMint,
          fontSize: 37, height: 1.14, letterSpacing: -2.0, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('Speak naturally. VELTRIX corrects your sentences, explains grammar, teaches powerful vocabulary and quizzes you after every turn.',
          style: TextStyle(color: Color(0xFFBDD1E2), height: 1.65, fontSize: 12)),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF1C2936), border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: coach.modelAvailable ? veltrixMint : const Color(0xFFE5B16F))),
            const SizedBox(width: 8),
            Expanded(child: Text(coach.modelAvailable ? 'Gemma 3 is connected. Your English coach is ready.' :
              'Configure Ollama with gemma3:4b in model settings.',
              style: const TextStyle(color: Color(0xFFB5CDEA), fontSize: 11))),
            IconButton(onPressed: coach.refreshConnection,
              tooltip: 'Retry connection', icon: const Icon(Icons.refresh, size: 17), color: _secondary),
          ])),
      ]));

    final body = Padding(padding: const EdgeInsets.fromLTRB(26, 0, 26, 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _LessonArea(coach: coach),
        if (coach.errorMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF422A2C), border: Border.all(color: const Color(0xFFB66B6B))),
            child: SelectableText(coach.errorMessage,
              style: const TextStyle(color: Color(0xFFFFCED1), fontSize: 12))),
        ],
      ]));

    final controls = Padding(padding: const EdgeInsets.fromLTRB(26, 0, 26, 22),
      child: _ControlBar(coach: coach, input: input, onSend: onSend));

    return Container(color: const Color(0xFF111A24), child: compact
      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, body, controls])
      : Column(children: [head, Expanded(child: SingleChildScrollView(child: body)), controls]));
  }
}

class _LessonArea extends StatelessWidget {
  final EnglishCoachController coach;
  const _LessonArea({required this.coach});
  @override
  Widget build(BuildContext context) {
    final lesson = coach.latest;
    if (coach.state == CoachState.thinking && lesson == null) {
      return _Frame(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 18),
        const CircularProgressIndicator(color: veltrixMint, strokeWidth: 2),
        const SizedBox(height: 17),
        const Text('Building your personalized English lesson…',
          textAlign: TextAlign.center, style: TextStyle(color: _white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text('${coach.tokenCount} streamed chunks', style: const TextStyle(color: _secondary, fontSize: 11)),
        const SizedBox(height: 18),
      ]));
    }
    if (lesson == null) {
      return _Frame(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 18),
        const Text('Ask VELTRIX to improve your English.',
          style: TextStyle(color: _white, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 11),
        const Text('Try “I didn’t care how difficult it was.”\nI’ll correct it, upgrade it and quiz you.',
          textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFABC8EC), height: 1.65, fontSize: 12)),
        const SizedBox(height: 18),
      ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (coach.state == CoachState.thinking) ...[
        const LinearProgressIndicator(color: veltrixMint, backgroundColor: _surface, minHeight: 2),
        const SizedBox(height: 9),
        Text('Generating the next lesson · ${coach.tokenCount} chunks',
          style: const TextStyle(color: _secondary, fontSize: 11)),
        const SizedBox(height: 9),
      ],
      _Frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Heading('01 / SENTENCE CORRECTION', icon: Icons.auto_fix_high),
        const SizedBox(height: 9),
        Text(lesson.userSentence, style: const TextStyle(color: _secondary, fontSize: 12)),
        const SizedBox(height: 8),
        Text(lesson.corrected, style: const TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(lesson.wasCorrect ? '✓ Grammatically correct' : '✓ Natural corrected version',
          style: const TextStyle(color: veltrixMint, fontSize: 11)),
        const SizedBox(height: 12),
        _Heading('02 / LEVEL UPGRADE', icon: Icons.trending_up),
        const SizedBox(height: 7),
        Text(lesson.upgraded, style: const TextStyle(color: Color(0xFF8ACBFF), fontSize: 15, height: 1.4, fontWeight: FontWeight.w600)),
      ])),
      const SizedBox(height: 10),
      _Frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Heading('03 / GRAMMAR, EXPLAINED SIMPLY', icon: Icons.menu_book_outlined),
        const SizedBox(height: 8),
        Text(lesson.grammarRule, style: const TextStyle(color: _white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 5),
        Directionality(textDirection: TextDirection.rtl,
          child: Text(lesson.explanationFa, textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFFBBD0E0), height: 1.8, fontSize: 12))),
      ])),
      if (lesson.vocabulary.isNotEmpty) ...[
        const SizedBox(height: 10),
        _Frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Heading('04 / POWER VOCABULARY', icon: Icons.auto_awesome),
          const SizedBox(height: 11),
          ...lesson.vocabulary.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Vocabulary(v),
          )),
        ])),
      ],
      const SizedBox(height: 10),
      _Frame(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Heading('05 / YOUR PRACTICE & QUIZ', icon: Icons.psychology_alt_outlined),
        if (lesson.quizFeedback.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Previous answer: ${lesson.quizFeedback}',
            style: const TextStyle(color: veltrixMint, height: 1.5, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Text(lesson.practice, style: const TextStyle(color: _secondary, fontSize: 12, height: 1.55)),
        const SizedBox(height: 8),
        Text(lesson.quizQuestion, style: const TextStyle(color: _white,
          fontSize: 15, height: 1.45, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        const Text('Answer by voice or text. VELTRIX will evaluate it on your next turn.',
          style: TextStyle(color: veltrixMint, fontSize: 11)),
      ])),
    ]);
  }
}

class _Vocabulary extends StatelessWidget {
  final VocabularyItem item;
  const _Vocabulary(this.item);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Flexible(child: Text(item.word, style: const TextStyle(color: veltrixMint, fontSize: 14, fontWeight: FontWeight.w700))),
      const SizedBox(width: 8),
      Text(item.level, style: const TextStyle(color: _secondary, fontSize: 10)),
    ]),
    Directionality(textDirection: TextDirection.rtl,
      child: Align(alignment: Alignment.centerRight,
        child: Text(item.meaningFa, style: const TextStyle(color: _secondary, fontSize: 12)))),
    if (item.collocation.isNotEmpty)
      Text(item.collocation, style: const TextStyle(color: Color(0xFFB9D6F0), fontSize: 12)),
    if (item.example.isNotEmpty)
      Text(item.example, style: const TextStyle(color: _white, fontSize: 12, height: 1.4)),
  ]);
}

class _Heading extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Heading(this.label, {required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: veltrixMint),
    const SizedBox(width: 7),
    Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF8EAFC6),
      fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1))),
  ]);
}

class _Frame extends StatelessWidget {
  final Widget child;
  const _Frame({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF111923),
      border: Border.all(color: const Color(0xFF35485A)),
      borderRadius: BorderRadius.circular(14)),
    child: child,
  );
}

class _ControlBar extends StatelessWidget {
  final EnglishCoachController coach;
  final TextEditingController input;
  final ValueChanged<String?> onSend;
  const _ControlBar({required this.coach, required this.input, required this.onSend});
  @override
  Widget build(BuildContext context) {
    final busy = coach.state == CoachState.thinking;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 7, runSpacing: 7, children: [
        _QuickChip('Correct my English', () => onSend('I am agree with your opinion.')),
        _QuickChip('Teach advanced words', () => onSend('Teach me sophisticated but natural English collocations.')),
        _QuickChip('Start a CEFR quiz', () => onSend('Start a ${coach.currentLevel} English speaking quiz.')),
      ]),
      const SizedBox(height: 12),
      Container(decoration: BoxDecoration(border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: TextField(controller: input,
            minLines: 1, maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: busy ? null : (value) => onSend(value),
            style: const TextStyle(color: _white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Speak or type a sentence in English…',
              hintStyle: TextStyle(color: Color(0xFF8A9AAA), fontSize: 12),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: InputBorder.none, enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none, filled: false))),
          SizedBox(height: 48, width: 49, child: FilledButton(
            onPressed: busy ? null : () => onSend(null),
            style: FilledButton.styleFrom(backgroundColor: veltrixMint,
              foregroundColor: _bg, padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(10)))),
            child: const Icon(Icons.arrow_forward, size: 19))),
        ])),
      const SizedBox(height: 9),
      Row(children: [
        Expanded(child: _ActionButton(
          icon: coach.state == CoachState.listening ? Icons.graphic_eq : Icons.mic_none,
          label: coach.state == CoachState.listening ? 'Listening' : 'Speak',
          highlighted: coach.state == CoachState.listening,
          onTap: coach.state == CoachState.listening ? coach.stop : coach.startListening)),
        const SizedBox(width: 7),
        Expanded(child: _ActionButton(icon: coach.voiceEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
          label: coach.voiceEnabled ? 'Voice on' : 'Voice off', onTap: () => coach.setVoice(!coach.voiceEnabled))),
        const SizedBox(width: 7),
        Expanded(child: _ActionButton(icon: Icons.power_settings_new, label: 'Stop', onTap: coach.stop)),
        const SizedBox(width: 7),
        Expanded(child: _ActionButton(icon: Icons.close, label: 'Clear', onTap: coach.clear)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        const Text('YOUR LEVEL', style: TextStyle(color: _secondary, fontSize: 9, letterSpacing: 1.1)),
        const SizedBox(width: 10),
        DropdownButton<String>(value: coach.currentLevel,
          dropdownColor: const Color(0xFF243444),
          isDense: true, underline: const SizedBox.shrink(),
          style: const TextStyle(color: veltrixMint, fontSize: 12, fontWeight: FontWeight.bold),
          items: const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']
            .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) { if (value != null) coach.setLevel(value); }),
        const Spacer(),
        const Text('HANDS-FREE', style: TextStyle(color: _secondary, fontSize: 9)),
        Switch.adaptive(value: coach.handsFree,
          activeTrackColor: veltrixMint, onChanged: coach.setHandsFree),
      ]),
      if (coach.partialTranscript.isNotEmpty)
        Text('Heard: ${coach.partialTranscript}',
          style: const TextStyle(color: veltrixMint, fontSize: 12)),
      const Text('English STT: device recognizer (network may be required) · TTS: device voice · Gemma 3 4B: your Ollama host',
        style: TextStyle(color: Color(0xFF728EA3), fontSize: 9, height: 1.5)),
    ]);
  }
}

class _QuickChip extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _QuickChip(this.title, this.onTap);
  @override
  Widget build(BuildContext context) => OutlinedButton(onPressed: onTap,
    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC0D9F5),
      side: const BorderSide(color: _border),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      shape: const StadiumBorder(), visualDensity: VisualDensity.compact),
    child: Text(title, style: const TextStyle(fontSize: 10)));
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.highlighted = false});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: highlighted ? veltrixMint : _border),
      foregroundColor: highlighted ? veltrixMint : const Color(0xFFC4DBF6),
      backgroundColor: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    icon: Icon(icon, size: 14),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 10)),
  );
}

InputDecoration _inputStyle(String hint) => InputDecoration(
  hintText: hint,
  filled: true, fillColor: const Color(0xFF0A141D),
  hintStyle: const TextStyle(color: _secondary),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: _border)),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: _border)),
);

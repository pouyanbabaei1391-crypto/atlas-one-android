import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../language/english_coach_controller.dart';

const veltrixMint = Color(0xFF72E3D3);
const veltrixBlue = Color(0xFF5D9EFF);

/// Animated original vector character inspired by the supplied reference:
/// chrome-shelled robot, dark faceplate and expressive electric-blue features.
class VeltrixAvatar extends StatefulWidget {
  final CoachState state;
  const VeltrixAvatar({super.key, required this.state});

  @override
  State<VeltrixAvatar> createState() => _VeltrixAvatarState();
}

class _VeltrixAvatarState extends State<VeltrixAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => CustomPaint(
        painter: _VeltrixPainter(_pulse.value, widget.state),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _VeltrixPainter extends CustomPainter {
  final double phase;
  final CoachState state;
  const _VeltrixPainter(this.phase, this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 340, size.height / 340);
    canvas.save();
    canvas.translate((size.width - 340 * scale) / 2, (size.height - 340 * scale) / 2);
    canvas.scale(scale);
    final t = phase * 2 * math.pi;
    canvas.translate(0, math.sin(t) * 3);

    final halo = Paint()
      ..shader = RadialGradient(colors: [
        veltrixBlue.withValues(alpha: .16),
        const Color(0xFF12314B).withValues(alpha: .08),
        Colors.transparent,
      ]).createShader(const Rect.fromLTWH(-5, -5, 350, 355));
    canvas.drawCircle(const Offset(170, 162), 168, halo);

    // Soft shadow behind the metallic shell.
    final shadow = Path()
      ..moveTo(76, 118)
      ..cubicTo(88, 50, 151, 25, 233, 43)
      ..cubicTo(278, 55, 293, 111, 292, 197)
      ..cubicTo(291, 261, 267, 294, 192, 301)
      ..cubicTo(110, 311, 62, 278, 65, 201)
      ..close();
    canvas.drawShadow(shadow, Colors.black, 20, true);

    // Polished silver rim, with the slanted capsule silhouette from reference.
    final chrome = Path()
      ..moveTo(69, 121)
      ..cubicTo(79, 67, 126, 36, 194, 38)
      ..cubicTo(248, 39, 286, 69, 292, 125)
      ..lineTo(305, 231)
      ..cubicTo(312, 289, 273, 307, 210, 309)
      ..lineTo(140, 313)
      ..cubicTo(88, 314, 62, 293, 60, 236)
      ..close();
    canvas.drawPath(chrome, Paint()
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE7F8FF), Color(0xFF76A8BF), Color(0xFF1D303B), Color(0xFFB8CDD7), Color(0xFF1B232B)],
        stops: [0, .24, .59, .81, 1]).createShader(const Rect.fromLTWH(55, 34, 260, 285)));

    // Black glossy faceplate.
    final face = Path()
      ..moveTo(84, 126)
      ..cubicTo(94, 72, 141, 48, 198, 51)
      ..cubicTo(254, 53, 277, 100, 278, 156)
      ..lineTo(283, 222)
      ..cubicTo(282, 256, 265, 275, 218, 281)
      ..lineTo(144, 286)
      ..cubicTo(98, 287, 82, 262, 79, 222)
      ..close();
    canvas.drawPath(face, Paint()
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF1B2631), Color(0xFF070B11), Color(0xFF0D111A), Color(0xFF182B38)],
        stops: [0, .35, .78, 1]).createShader(const Rect.fromLTWH(80, 50, 205, 230)));

    final light = Path()
      ..moveTo(102, 92)
      ..quadraticBezierTo(135, 55, 183, 59)
      ..quadraticBezierTo(121, 105, 107, 179)
      ..close();
    canvas.drawPath(light, Paint()..color = Colors.white.withValues(alpha: .055));

    // Expressive brow movement: raised in listening, furrowed in thinking.
    final browOffset = state == CoachState.listening ? -8.0
        : state == CoachState.thinking ? 5.0 : math.sin(t) * 1.5;
    final brow = Paint()..color = const Color(0xFF6CAFFF)
      ..style = PaintingStyle.stroke..strokeWidth = 9..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(120, 126 + browOffset, 41, 20), math.pi * 1.07,
      math.pi * .52, false, brow);
    canvas.drawArc(Rect.fromLTWH(205, 120 + browOffset, 43, 24), math.pi * 1.38,
      math.pi * .5, false, brow);

    final blink = math.sin(t + .4) > .995 ? .09 : 1.0;
    final attentive = state == CoachState.listening ? 1.09 : 1.0;
    final thinking = state == CoachState.thinking ? .7 : 1.0;
    void eye(Offset center, double radiusX) {
      final radiusY = 29 * blink * attentive * thinking;
      canvas.drawOval(Rect.fromCenter(center: center, width: radiusX * 2.35, height: radiusY * 2.45),
        Paint()..color = veltrixBlue.withValues(alpha: .23)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      canvas.drawOval(Rect.fromCenter(center: center, width: radiusX * 2, height: math.max(3, radiusY * 2)),
        Paint()..shader = const LinearGradient(begin: Alignment.topLeft,
          end: Alignment.bottomRight, colors: [Color(0xFF77B7FF), Color(0xFF438BFF)])
          .createShader(Rect.fromCircle(center: center, radius: 32)));
    }
    eye(const Offset(148, 185), 17);
    eye(const Offset(223, 182), 18);

    // Facial speech gestures: a moving mouth aperture synchronized to TTS state
    // (speech-state driven; actual per-phoneme lip sync would require audio levels).
    final mouthWave = (.5 + .5 * math.sin(4 * t));
    final open = state == CoachState.speaking ? 5 + 19 * mouthWave
        : state == CoachState.listening ? 6.0
        : state == CoachState.thinking ? 3.0 : 4 + math.sin(t) * 1.1;
    final mouthY = 251.0;
    canvas.drawOval(Rect.fromCenter(center: Offset(189, mouthY), width: 35,
        height: open), Paint()..color = veltrixBlue.withValues(alpha: .2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawArc(Rect.fromCenter(center: Offset(189, mouthY - 3), width: 35, height: open + 4),
      state == CoachState.thinking ? math.pi : .15,
      state == CoachState.thinking ? math.pi : math.pi - .3, false,
      Paint()..color = const Color(0xFF5DA6FF)
        ..strokeWidth = 4..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);

    // Chin lightbar with reflection.
    final chin = Path()..moveTo(116, 291)..quadraticBezierTo(219, 281, 283, 270)
      ..lineTo(284, 286)..quadraticBezierTo(197, 300, 120, 306)..close();
    canvas.drawPath(chin, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFFCBDEEA), Color(0xFF4B6573), Color(0xFF141E28)])
      .createShader(const Rect.fromLTWH(116, 270, 170, 37)));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VeltrixPainter old) =>
    old.phase != phase || old.state != state;
}

class VeltrixStage extends StatelessWidget {
  final CoachState state;
  final String status;
  const VeltrixStage({super.key, required this.state, required this.status});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(center: Alignment(.04, .38), radius: .94,
        colors: [Color(0xFF192B3D), Color(0xFF101D2A), Color(0xFF0D1621)]),
    ),
    child: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _GridPainter())),
      Center(child: Opacity(opacity: .038, child: FittedBox(fit: BoxFit.scaleDown,
        child: Text('VELTRIX', style: TextStyle(fontSize: 136,
          fontWeight: FontWeight.w900, letterSpacing: -8, color: Colors.white))))),
      Positioned(top: 20, left: 20, right: 20,
        child: Row(children: [
          const Text('VELTRIX / LANGUAGE ENVIRONMENT',
            style: TextStyle(fontSize: 9, letterSpacing: 1.6, color: Color(0xFF96ACC0), fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(state == CoachState.listening ? 'LISTENING' : state == CoachState.thinking ? 'THINKING' :
            state == CoachState.speaking ? 'SPEAKING' : 'READY',
            style: const TextStyle(fontSize: 9, letterSpacing: 1.2, color: veltrixMint)),
        ])),
      const Positioned(left: 38, top: 114, child: _FloatIcon(Icons.mic_none)),
      const Positioned(right: 38, top: 163, child: _FloatIcon(Icons.verified_user_outlined)),
      const Positioned(right: 83, bottom: 80, child: _FloatIcon(Icons.memory)),
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 370, maxHeight: 370),
        child: AspectRatio(aspectRatio: 1, child: VeltrixAvatar(state: state)))),
      Positioned(bottom: 20, left: 22, right: 22, child: Row(children: [
        Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: veltrixMint)),
        const SizedBox(width: 10),
        Expanded(child: Text(status.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, letterSpacing: 1.2,
            fontWeight: FontWeight.w700, color: Color(0xFFC5DEEB)))),
        const Text('▮▮▮▮▮▮', style: TextStyle(color: veltrixMint, fontSize: 12, letterSpacing: 1)),
      ])),
    ]),
  );
}

class _FloatIcon extends StatelessWidget {
  final IconData icon;
  const _FloatIcon(this.icon);
  @override
  Widget build(BuildContext context) => Container(
    width: 43, height: 43,
    decoration: BoxDecoration(color: const Color(0xFF1B3545).withValues(alpha: .78),
      border: Border.all(color: const Color(0xFF41667A).withValues(alpha: .65)),
      borderRadius: BorderRadius.circular(15)),
    child: Icon(icon, color: const Color(0xFF75B9D5), size: 19));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFF6A91A8).withValues(alpha: .055)
      ..strokeWidth = .6;
    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width / 2, size.height / 2),
      width: size.width * .62, height: size.height * .36),
      Paint()..color = const Color(0xFF6A99B7).withValues(alpha: .11)
        ..style = PaintingStyle.stroke..strokeWidth = .8);
  }
  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

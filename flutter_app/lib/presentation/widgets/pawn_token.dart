import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A ludo token drawn the way Ludo King draws it: a map-pin drop - round head,
/// tapered point, and a white ring punched through the head.
class PawnToken extends StatelessWidget {
  const PawnToken({
    super.key,
    required this.size,
    required this.color,
    this.glowing = false,
    this.hop = 0.0,
  });

  /// Token width as a fraction of [size]. The drop is taller than it is wide.
  static const double widthRatio = 0.72;

  /// Total height as a fraction of [size]; kept under 1 so a piece fills its
  /// square instead of poking into the row above.
  static const double heightRatio = 0.80;

  final double size;
  final Color color;
  final bool glowing;
  final double hop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * heightRatio,
      child: CustomPaint(
        painter: _PawnPainter(
          color: color,
          glowing: glowing,
          hop: hop,
        ),
      ),
    );
  }
}

class _PawnPainter extends CustomPainter {
  _PawnPainter({
    required this.color,
    required this.glowing,
    required this.hop,
  });

  final Color color;
  final bool glowing;
  final double hop;

  Color get _ink => const Color(0xFF2B2B2B);

  // Ludo King tokens are almost flat - just a hint of shading so they read as
  // moulded. Any more and a dark crescent appears under the white ring.
  Color get _light => Color.lerp(color, Colors.white, 0.18)!;
  Color get _shade => Color.lerp(color, Colors.black, 0.10)!;
  Color get _dark => Color.lerp(color, Colors.black, 0.24)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final groundY = h;
    // The drop lifts only a little as it travels - enough to separate it from
    // the square without it appearing to leap.
    final rise = hop * h * 0.11;

    _paintShadow(canvas, cx, groundY, w);
    if (glowing) _paintGlow(canvas, cx, h * 0.45, w);

    // The whole drop lifts; only the shadow stays on the square.
    final body = _drop(cx, rise, w, groundY - rise);

    canvas.drawPath(
      body.shift(Offset(0, h * 0.025 * (1.0 - hop * 0.6))),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22 * (1.0 - hop * 0.5))
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, w * (0.028 + hop * 0.030)),
    );

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_light, color, _shade],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    // White ring punched through the head.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawCircle(
      Offset(cx, rise + w * 0.36),
      w * 0.20,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx, rise + w * 0.36),
      w * 0.20,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..color = _dark.withValues(alpha: 0.35),
    );
    // Gloss on the upper-left of the head.
    canvas.drawOval(
      Rect.fromLTWH(cx - w * 0.30, rise + w * 0.14, w * 0.16, w * 0.20),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02),
    );
    canvas.restore();

    // Bold dark keyline - the thing that lifts a token off a white square.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..strokeJoin = StrokeJoin.round
        ..color = glowing ? AppColors.gold : _ink,
    );
  }

  void _paintShadow(Canvas canvas, double cx, double groundY, double w) {
    final shrink = 1.0 - hop * 0.28;
    final r = w * 0.26 * shrink;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY),
        width: r * 2,
        height: r * 0.62,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30 * (1.0 - hop * 0.35))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.018),
    );
  }

  void _paintGlow(Canvas canvas, double cx, double cy, double w) {
    for (final (blur, alpha) in const [
      (26.0, 0.18),
      (13.0, 0.32),
      (6.0, 0.55)
    ]) {
      canvas.drawCircle(
        Offset(cx, cy),
        w * blur / 26,
        Paint()
          ..color = AppColors.gold.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.07),
      );
    }
  }

  /// Map-pin silhouette: circular head with a point at the bottom.
  Path _drop(double cx, double top, double w, double bottom) {
    final headR = w * 0.38;
    final headC = Offset(cx, top + headR);
    // The tip is pulled in from the head so the sides taper like a pin.
    final tip = Offset(cx, bottom - w * 0.03);
    final waist = Offset(cx, top + headR * 1.55);

    return Path()
      ..arcTo(
        Rect.fromCircle(center: headC, radius: headR),
        math.pi * 0.62,
        math.pi * 1.76,
        false,
      )
      ..quadraticBezierTo(cx + w * 0.30, waist.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(cx - w * 0.30, waist.dy, cx, headC.dy - headR)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _PawnPainter old) =>
      old.color != color ||
      old.glowing != glowing ||
      (old.hop - hop).abs() > 0.01;
}

/// Outlined star used for the safe squares and the board centre.
void paintStar(
  Canvas canvas,
  Offset center,
  double radius, {
  Color color = const Color(0xFF3A3A3A),
  Color? outline,
  double points = 5,
}) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / points;
    final r = i.isEven ? radius : radius * 0.45;
    final p = Offset(
      center.dx + r * math.cos(a),
      center.dy + r * math.sin(a),
    );
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  if (outline == null) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.18
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    return;
  }
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16
      ..strokeJoin = StrokeJoin.round
      ..color = outline,
  );
}

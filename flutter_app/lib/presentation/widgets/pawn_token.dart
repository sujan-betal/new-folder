import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A glossy 3D ludo pawn, painted rather than stacked from boxes so the
/// silhouette stays crisp at any board size.
///
/// [hop] is 0 while the pawn rests on a square and 1 at the top of a hop; it
/// drives the arc, the scale pop and the shrinking ground shadow.
class PawnToken extends StatelessWidget {
  const PawnToken({
    super.key,
    required this.size,
    required this.color,
    this.glowing = false,
    this.hop = 0.0,
  });

  /// Pawn height as a fraction of [size]. Kept well under 1 so a piece fills
  /// its square instead of towering into the one above, and exposed so the
  /// board can place the foot without duplicating the number.
  static const double heightRatio = 0.88;

  final double size;
  final Color color;

  /// Gold halo + rim for the tokens the current player may move.
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

  Color get _light => Color.lerp(color, Colors.white, 0.52)!;
  Color get _shade => Color.lerp(color, Colors.black, 0.46)!;
  Color get _outline => Color.lerp(color, const Color(0xFF1B1B1B), 0.62)!;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    // Ground line stays put while the pawn rises.
    final groundY = size.height;
    final rise = hop * s * 0.34;
    // Head and foot move together - the whole pawn leaves the board, only the
    // shadow stays glued to the square.
    final top = rise;
    final pawnGround = groundY - rise;

    _paintShadow(canvas, cx, groundY, s);
    if (glowing) _paintGlow(canvas, cx, (top + pawnGround) / 2, s);

    final body = _silhouette(s, top, pawnGround);

    // Drop shadow / contact darkening - tightens onto the square as the pawn
    // lifts away from it.
    final contact = body.shift(Offset(0, s * 0.035 * (1.0 - hop * 0.6)));
    canvas.drawPath(
      contact,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28 * (1.0 - hop * 0.5))
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, s * (0.035 + hop * 0.05)),
    );

    // Body: light from the upper left, falling into shade at the lower right.
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_light, color, _shade],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // White bands, clipped to the body: a collar under the head plus a thin
    // ring at the foot - the two stripes a real ludo counter has.
    canvas.save();
    canvas.clipPath(body);
    final collarTop = top + s * 0.40;
    canvas.drawRect(
      Rect.fromLTWH(0, collarTop, size.width, s * 0.10),
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, collarTop + s * 0.10, size.width, s * 0.020),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );
    final footRing = pawnGround - s * 0.20;
    canvas.drawRect(
      Rect.fromLTWH(0, footRing, size.width, s * 0.032),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    // Vertical ambient occlusion on the right side of the stem.
    canvas.drawRect(
      Rect.fromLTWH(cx + s * 0.02, top, s * 0.3, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
        ).createShader(Rect.fromLTWH(cx, top, s * 0.3, size.height)),
    );
    // Specular streak down the left of the head and stem.
    canvas.drawOval(
      Rect.fromLTWH(cx - s * 0.215, top + s * 0.05, s * 0.12, s * 0.30),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.46)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.022),
    );
    canvas.restore();

    // Bold cartoon outline - the thing that makes a token pop off the board.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeJoin = StrokeJoin.round
        ..color = glowing ? AppColors.gold : _outline,
    );

    if (glowing) {
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.028
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  void _paintShadow(Canvas canvas, double cx, double groundY, double s) {
    final shrink = 1.0 - hop * 0.5;
    final r = s * 0.30 * shrink;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, groundY), width: r * 2, height: r * 0.72),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34 * (1.0 - hop * 0.55))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );
  }

  void _paintGlow(Canvas canvas, double cx, double cy, double s) {
    for (final pass in const [(26.0, 0.16), (14.0, 0.30), (7.0, 0.55)]) {
      canvas.drawCircle(
        Offset(cx, cy),
        s * pass.$1 / 26,
        Paint()
          ..color = AppColors.gold.withValues(alpha: pass.$2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.07),
      );
    }
  }

  /// Rounded pawn silhouette: domed head, short fat stem, wide flared foot.
  /// Deliberately squat - a tall thin pawn reads as a chess piece, this reads
  /// as the counter you remember from a physical ludo set.
  Path _silhouette(double s, double top, double ground) {
    final w = s;
    final headR = w * 0.26;
    final headC = Offset(w / 2, top + headR);
    final neckY = top + headR * 1.45;
    final footR = w * 0.36;
    // Sit the foot ellipse so its underside lands exactly on `ground`.
    final footTop = ground - footR * 0.31;

    final stem = Path()
      ..moveTo(w / 2 - w * 0.27, footTop)
      ..quadraticBezierTo(
          w / 2 - w * 0.25, neckY + w * 0.10, w / 2 - w * 0.175, neckY)
      ..lineTo(w / 2 + w * 0.175, neckY)
      ..quadraticBezierTo(
          w / 2 + w * 0.25, neckY + w * 0.10, w / 2 + w * 0.27, footTop)
      ..close();

    final head = Path()..addOval(Rect.fromCircle(center: headC, radius: headR));

    final foot = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(w / 2, footTop),
        width: footR * 2,
        height: footR * 0.62,
      ));

    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, stem, head),
      foot,
    );
  }

  @override
  bool shouldRepaint(covariant _PawnPainter old) =>
      old.color != color ||
      old.glowing != glowing ||
      (old.hop - hop).abs() > 0.01;
}

/// Star used for safe squares and the centre medallion.
void paintStar(
  Canvas canvas,
  Offset center,
  double radius, {
  Color color = AppColors.gold,
  Color? outline,
  double points = 5,
}) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final angle = -math.pi / 2 + i * math.pi / points;
    final r = i.isEven ? radius : radius * 0.45;
    final point = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  canvas.drawPath(
    path,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          Color.lerp(color, Colors.white, 0.5)!,
          color,
          Color.lerp(color, Colors.black, 0.30)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
  if (outline != null) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.16
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
    );
  }
}

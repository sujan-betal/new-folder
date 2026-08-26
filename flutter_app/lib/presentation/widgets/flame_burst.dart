import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ludo King style one-shot effects played over a board square.
enum FxStyle { flame, sparkle }

/// Self-removing burst of fire (token kill) or golden sparks (home entry).
class FlameBurst extends StatefulWidget {
  const FlameBurst({
    super.key,
    required this.size,
    this.style = FxStyle.flame,
    this.onFinished,
  });

  final double size;
  final FxStyle style;
  final VoidCallback? onFinished;

  @override
  State<FlameBurst> createState() => _FlameBurstState();
}

class _FlameBurstState extends State<FlameBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _BurstPainter(
            progress: _controller.value,
            style: widget.style,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.delay,
    required this.life,
    required this.sizeFrac,
    required this.wobble,
    required this.seed,
  });

  final double angle;
  final double delay;
  final double life;
  final double sizeFrac;
  final double wobble;
  final double seed;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.style})
      : _rng = math.Random(style == FxStyle.flame ? 7 : 13) {
    for (var i = 0; i < 18; i++) {
      _particles.add(_Particle(
        angle: style == FxStyle.flame
            ? -math.pi / 2 + (_rng.nextDouble() - 0.5) * 1.15
            : _rng.nextDouble() * 2 * math.pi,
        delay: _rng.nextDouble() * 0.3,
        life: 0.55 + _rng.nextDouble() * 0.4,
        sizeFrac: 0.16 + _rng.nextDouble() * 0.2,
        wobble: 4 + _rng.nextDouble() * 4,
        seed: _rng.nextDouble() * 10,
      ));
    }
    if (style == FxStyle.flame) {
      for (var i = 0; i < 5; i++) {
        _smoke.add(math.Point(_rng.nextDouble(), 0.35 + _rng.nextDouble() * 0.3));
      }
    }
  }

  final double progress;
  final FxStyle style;
  final math.Random _rng;
  final List<_Particle> _particles = [];
  final List<math.Point> _smoke = [];

  static const List<Color> _fireStops = [
    Color(0xFFFFF6C8),
    Color(0xFFFFD54A),
    Color(0xFFFF9100),
    Color(0xFFE53935),
    Color(0xFF7B1A12),
  ];

  static const List<Color> _sparkStops = [
    Color(0xFFFFFFFF),
    Color(0xFFFFE082),
    Color(0xFFFFC93C),
    Color(0xFFF5A623),
    Color(0xFFB26A00),
  ];

  Color _ramp(List<Color> stops, double t, double alpha) {
    final clamped = t.clamp(0.0, 0.999);
    final seg = (clamped * (stops.length - 1)).floor();
    final local = clamped * (stops.length - 1) - seg;
    return Color.lerp(stops[seg], stops[seg + 1], local)!
        .withValues(alpha: alpha);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final s = size.shortestSide;
    final t = progress;

    if (style == FxStyle.flame) _paintSmoke(canvas, center, s, t);

    // Ignition flash.
    if (t < 0.22) {
      final k = 1 - t / 0.22;
      canvas.drawCircle(
        center,
        s * (0.25 + 0.17 * (1 - k)),
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.95 * k),
            _ramp(style == FxStyle.flame ? _fireStops : _sparkStops, 0.25,
                0.75 * k),
          ]).createShader(Rect.fromCircle(center: center, radius: s * 0.45)),
      );
    }

    // Shockwave ring.
    if (t < 0.42) {
      final k = t / 0.42;
      canvas.drawCircle(
        center,
        s * (0.24 + k * 0.72),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1 - k) + 0.6
          ..color = const Color(0xFFFFD54A).withValues(alpha: 0.7 * (1 - k)),
      );
    }

    for (final p in _particles) {
      final local = (t - p.delay) / p.life;
      if (local <= 0 || local >= 1) continue;

      final flicker =
          0.82 + 0.18 * math.sin(t * 42 + p.seed * math.pi);
      var radius = s * p.sizeFrac * (1 - local * 0.85) * flicker;
      final alpha = math.pow(1 - local, 1.2).toDouble();

      final Offset pos;
      if (style == FxStyle.flame) {
        pos = center +
            Offset(
              math.cos(p.angle) * local * s * 0.12 +
                  math.sin(local * p.wobble * math.pi + p.seed) * s * 0.06,
              math.sin(p.angle).abs() * -local * s * 0.78,
            );
      } else {
        pos = center +
            Offset(
              math.cos(p.angle) * local * s * 0.72,
              math.sin(p.angle) * local * s * 0.72,
            );
        radius *= 0.55;
      }

      canvas.drawCircle(
        pos,
        radius * 1.7,
        Paint()
          ..color = _ramp(style == FxStyle.flame ? _fireStops : _sparkStops,
              local, alpha * 0.28),
      );
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = _ramp(style == FxStyle.flame ? _fireStops : _sparkStops,
              local, alpha),
      );
    }
  }

  void _paintSmoke(Canvas canvas, Offset center, double s, double t) {
    for (var i = 0; i < _smoke.length; i++) {
      final delay = _smoke[i].x * 0.2;
      final speed = _smoke[i].y;
      final local = (t - delay) / speed;
      if (local <= 0 || local >= 1) continue;
      final sway = math.sin(local * 5 + i * 1.7) * s * 0.05;
      canvas.drawCircle(
        Offset(center.dx + sway, center.dy - s * (0.55 + local * 0.5)),
        s * (0.1 + local * 0.24),
        Paint()
          ..color = const Color(0xFF555555)
              .withValues(alpha: 0.22 * (1 - local)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.style != style;
}

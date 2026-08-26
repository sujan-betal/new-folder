import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ludo King style dice: a glossy 3D white cube sitting on a colored
/// circular tray. Tap to roll - it tumbles and lands on the result.
class DiceWidget extends StatefulWidget {
  const DiceWidget({
    super.key,
    required this.value,
    required this.rolling,
    required this.color,
    required this.size,
    this.onTap,
    this.enabled = false,
    this.tray = true,
  });

  final int value;
  final bool rolling;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final bool enabled;

  /// Show the colored player tray behind the cube.
  final bool tray;

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  );
  int _displayValue = 1;
  bool _wasRolling = false;
  double _spinDir = 1;
  int _seed = 3;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value <= 0 ? 1 : widget.value;
    _wasRolling = widget.rolling;
    if (_wasRolling) _beginRoll();
  }

  void _beginRoll() {
    _spinDir = (_seed.isEven ? 1 : -1).toDouble();
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rolling && !_wasRolling) {
      _seed = (_displayValue * 7 + widget.size.round()) % 13 + 2;
      _beginRoll();
    }
    _wasRolling = widget.rolling;
    if (!widget.rolling && widget.value > 0 && !_controller.isAnimating) {
      _displayValue = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final rollingNow =
              widget.rolling || (_controller.isAnimating && _wasRolling);

          var value = _displayValue;
          double angle = 0;
          double scale = 1;
          double lift = 0;
          if (rollingNow) {
            value = _tumbleFace(t);
            // Continuous eased spin - fast at first, gliding to a stop.
            final easeOut = Curves.easeOutQuart.transform(t);
            angle = (1 - easeOut) * math.pi * 4 * _spinDir;
            // Pop up, then settle with a soft landing bounce.
            scale =
                1 + math.sin(math.pi * t) * 0.15 * (1 - t * 0.65);
            lift = math.sin(math.pi * t) * widget.size * 0.18;
          }

          final cube = _Cube(
            size: widget.size,
            value: value,
            pipColor: Colors.black87,
            tilt: angle,
            lift: lift,
          );

          return Transform.translate(
            offset: Offset(0, -lift),
            child: SizedBox(
              width: widget.tray ? widget.size * 1.62 : widget.size * 1.25,
              height: widget.tray ? widget.size * 1.62 : widget.size * 1.25,
              child: Center(
                child: widget.tray
                    ? _Tray(
                        color: widget.color,
                        child:
                            Transform.scale(scale: scale, child: cube))
                    : Transform.scale(scale: scale, child: cube),
              ),
            ),
          );
        },
      ),
    );
  }

  int _tumbleFace(double t) {
    // Faces flip rapidly early on and slow down as the die settles.
    if (t > 0.86) return _targetOrDisplay();
    final phase =
        (Curves.easeOutQuad.transform(t) * 9).floor();
    return 1 + (phase * 5 + _seed) % 6;
  }

  int _targetOrDisplay() => widget.value > 0 ? widget.value : _displayValue;
}

/// Colored circular holder under the dice, Ludo King tray style.
class _Tray extends StatelessWidget {
  const _Tray({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.28)!,
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
          stops: const [0.0, 0.62, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Glossy white cube with beveled edges and inset pips.
class _Cube extends StatelessWidget {
  const _Cube({
    required this.size,
    required this.value,
    required this.pipColor,
    required this.tilt,
    required this.lift,
  });

  final double size;
  final int value;
  final Color pipColor;
  final double tilt;
  final double lift;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFF6F6F6),
              Color(0xFFDCDCDC),
              Color(0xFFBFBFBF),
            ],
            stops: [0.0, 0.45, 0.8, 1.0],
          ),
          border: Border.all(color: const Color(0xFF9E9E9E), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 9,
              offset: Offset(0, 4 + lift * 0.25),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top-left sheen.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.55],
                    colors: [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.15),
              child: CustomPaint(
                size: Size(size * 0.7, size * 0.7),
                painter: _DiceFacePainter(value: value, color: pipColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiceFacePainter extends CustomPainter {
  _DiceFacePainter({required this.value, required this.color});

  final int value;
  final Color color;

  static const Map<int, List<Offset>> _pips = {
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.26, 0.26), Offset(0.74, 0.74)],
    3: [Offset(0.26, 0.26), Offset(0.5, 0.5), Offset(0.74, 0.74)],
    4: [
      Offset(0.26, 0.26),
      Offset(0.74, 0.26),
      Offset(0.26, 0.74),
      Offset(0.74, 0.74)
    ],
    5: [
      Offset(0.26, 0.26),
      Offset(0.74, 0.26),
      Offset(0.5, 0.5),
      Offset(0.26, 0.74),
      Offset(0.74, 0.74)
    ],
    6: [
      Offset(0.26, 0.24),
      Offset(0.74, 0.24),
      Offset(0.26, 0.5),
      Offset(0.74, 0.5),
      Offset(0.26, 0.76),
      Offset(0.74, 0.76)
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.105;
    for (final pip in _pips[value] ?? const <Offset>[]) {
      final c = Offset(pip.dx * size.width, pip.dy * size.height);
      // Inset well under each pip.
      canvas.drawCircle(
        c.translate(r * 0.18, r * 0.22),
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
      // Glossy pip body.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 1.05,
            colors: [
              Color.lerp(color, Colors.white, 0.42)!,
              color,
              Color.lerp(color, Colors.black, 0.45)!,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      // Tiny specular highlight.
      canvas.drawCircle(
        c.translate(-r * 0.32, -r * 0.34),
        r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

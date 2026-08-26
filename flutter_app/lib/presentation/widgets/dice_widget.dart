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
  // Multi-phase animation: 1000ms total
  // Phase 1 (0 - 0.65): fast tumbling
  // Phase 2 (0.65 - 0.82): decelerating
  // Phase 3 (0.82 - 1.0): bounce and settle
  static const _totalMs = 1000;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );

  late Animation<double> _spinAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _liftAnim;
  late Animation<double> _bounceAnim;

  int _displayValue = 1;
  bool _wasRolling = false;
  double _spinDir = 1;
  int _seed = 3;
  int _tumblePhaseCount = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value <= 0 ? 1 : widget.value;
    _wasRolling = widget.rolling;
    _buildAnimations();
    if (_wasRolling) _beginRoll();
  }

  void _buildAnimations() {
    // Spin: fast start, smooth deceleration, slight overshoot bounce at end
    _spinAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: math.pi * 6)
            .chain(CurveTween(curve: Curves.easeOutQuart)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: math.pi * 6, end: math.pi * 6 + 0.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: math.pi * 6 + 0.15, end: math.pi * 6)
            .chain(CurveTween(curve: Curves.easeInOutBack)),
        weight: 14,
      ),
    ]).animate(_controller);

    // Scale: pop up big, then bounce settle
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.28, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 39,
      ),
    ]).animate(_controller);

    // Lift: rise up then fall with bounce
    _liftAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutSine)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: -0.08)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.08, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 29,
      ),
    ]).animate(_controller);

    // Rotation wobble on landing
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.06)
            .chain(CurveTween(curve: Curves.easeOutSine)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.06, end: -0.03)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.03, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 10,
      ),
    ]).animate(_controller);
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
      _buildAnimations();
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
          double tilt = 0;
          double scale = 1;
          double lift = 0;

          if (rollingNow) {
            value = _tumbleFace(t);
            tilt = _spinAnim.value * _spinDir + _bounceAnim.value;
            scale = _scaleAnim.value;
            lift = _liftAnim.value * widget.size * 0.25;
          }

          final cubeSize = widget.size * (rollingNow ? scale : 1.0);

          final cube = _Cube(
            size: cubeSize,
            value: value,
            pipColor: Colors.black87,
            tilt: tilt,
            lift: lift,
            rolling: rollingNow,
          );

          return Transform.translate(
            offset: Offset(0, -lift),
            child: SizedBox(
              width: widget.tray ? widget.size * 1.7 : widget.size * 1.3,
              height: widget.tray ? widget.size * 1.7 : widget.size * 1.3,
              child: Center(
                child: widget.tray
                    ? _Tray(
                        color: widget.color,
                        child: cube,
                      )
                    : cube,
              ),
            ),
          );
        },
      ),
    );
  }

  int _tumbleFace(double t) {
    // During fast tumble (0 - 0.65), cycle faces rapidly
    // During deceleration (0.65 - 0.82), slow down face changes
    // During settle (0.82+), show final value

    if (t > 0.82) return _targetOrDisplay();

    if (t < 0.55) {
      // Fast tumble: change face every ~60ms equivalent
      _tumblePhaseCount = (t * 18).floor();
      return 1 + (_tumblePhaseCount * 5 + _seed) % 6;
    } else if (t < 0.72) {
      // Decelerating: slower face changes
      _tumblePhaseCount = (t * 10).floor();
      return 1 + (_tumblePhaseCount * 3 + _seed) % 6;
    } else {
      // Almost settled: flash between current and target
      final showTarget = (t * 20).floor().isEven;
      return showTarget ? _targetOrDisplay() : 1 + (_seed + 2) % 6;
    }
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
            Color.lerp(color, Colors.white, 0.32)!,
            color,
            Color.lerp(color, Colors.black, 0.40)!,
          ],
          stops: const [0.0, 0.58, 1.0],
        ),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.88), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 2,
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
    required this.rolling,
  });

  final double size;
  final int value;
  final Color pipColor;
  final double tilt;
  final double lift;
  final bool rolling;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: AnimatedContainer(
        duration: rolling
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFF8F8F8),
              Color(0xFFE8E8E8),
              Color(0xFFD0D0D0),
            ],
            stops: [0.0, 0.35, 0.72, 1.0],
          ),
          border: Border.all(color: const Color(0xFFAAAAAA), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10 + (rolling ? 4 : 0),
              offset: Offset(0, 5 + lift * 0.3),
              spreadRadius: rolling ? 1 : 0,
            ),
            // Subtle inner highlight
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.6),
              blurRadius: 2,
              offset: const Offset(-1, -1),
              spreadRadius: -1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top-left sheen
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment(0.6, 0.6),
                    stops: const [0.0, 0.5],
                    colors: [
                      Colors.white.withValues(alpha: 0.9),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Pip face
            Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: CustomPaint(
                size: Size(size * 0.76, size * 0.76),
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

  // Wider pip spacing for better visibility
  static const Map<int, List<Offset>> _pips = {
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
    3: [Offset(0.25, 0.25), Offset(0.5, 0.5), Offset(0.75, 0.75)],
    4: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75),
    ],
    5: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.5, 0.5),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75),
    ],
    6: [
      Offset(0.25, 0.22),
      Offset(0.75, 0.22),
      Offset(0.25, 0.5),
      Offset(0.75, 0.5),
      Offset(0.25, 0.78),
      Offset(0.75, 0.78),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    // Larger pips for visibility
    final r = size.shortestSide * 0.125;
    for (final pip in _pips[value] ?? const <Offset>[]) {
      final c = Offset(pip.dx * size.width, pip.dy * size.height);
      // Drop shadow under pip
      canvas.drawCircle(
        c.translate(r * 0.15, r * 0.20),
        r * 1.05,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );
      // Pip body - dark and bold
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 1.1,
            colors: [
              const Color(0xFF444444),
              const Color(0xFF1A1A1A),
              Colors.black,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      // Specular highlight
      canvas.drawCircle(
        c.translate(-r * 0.30, -r * 0.32),
        r * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

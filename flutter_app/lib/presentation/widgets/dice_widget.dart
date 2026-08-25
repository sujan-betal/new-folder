import 'dart:math' as math;

import 'package:flutter/material.dart';

class DiceWidget extends StatefulWidget {
  const DiceWidget({
    super.key,
    required this.value,
    required this.rolling,
    required this.color,
    required this.size,
    this.onTap,
    this.enabled = false,
  });

  final int value;
  final bool rolling;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  int _displayValue = 1;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value == 0 ? 1 : widget.value;
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rolling && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.rolling && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
    if (!widget.rolling && widget.value > 0) {
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
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          var value = _displayValue;
          if (widget.rolling) {
            final t = _controller.value;
            value = 1 + ((t * 97).floor() + _displayValue) % 6;
          }
          return Transform.rotate(
            angle:
                widget.rolling ? math.sin(_controller.value * math.pi * 4) * 0.35 : 0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(widget.size * 0.22),
                border: Border.all(color: widget.color, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: EdgeInsets.all(widget.size * 0.14),
              child: CustomPaint(
                painter: _DiceFacePainter(value: value, color: widget.color),
              ),
            ),
          );
        },
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
    2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
    3: [Offset(0.25, 0.25), Offset(0.5, 0.5), Offset(0.75, 0.75)],
    4: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75)
    ],
    5: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.5, 0.5),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75)
    ],
    6: [
      Offset(0.25, 0.22),
      Offset(0.75, 0.22),
      Offset(0.25, 0.5),
      Offset(0.75, 0.5),
      Offset(0.25, 0.78),
      Offset(0.75, 0.78)
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final pip in _pips[value] ?? const <Offset>[]) {
      canvas.drawCircle(
        Offset(pip.dx * size.width, pip.dy * size.height),
        size.shortestSide * 0.09,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

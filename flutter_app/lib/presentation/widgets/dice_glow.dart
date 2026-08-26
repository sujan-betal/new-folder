import 'package:flutter/material.dart';

/// Halo around the tray dice of whoever's turn it is - Ludo King never
/// explains turns with text, the glowing dice says it all.
class DiceGlow extends StatefulWidget {
  const DiceGlow({
    super.key,
    required this.active,
    required this.color,
    required this.child,
  });

  final bool active;
  final Color color;
  final Widget child;

  @override
  State<DiceGlow> createState() => _DiceGlowState();
}

class _DiceGlowState extends State<DiceGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    lowerBound: 0.35,
    upperBound: 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant DiceGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = widget.active ? _controller.value : 0.0;
        return Transform.scale(
          scale: 1 + glow * 0.07,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.75 * glow),
                  blurRadius: 26 * glow + 2,
                  spreadRadius: 6 * glow,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

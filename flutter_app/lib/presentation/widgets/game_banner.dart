import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The loud centre-screen callout a ludo player expects after a big moment:
/// "KILL!", "EXTRA TURN", "HOME!" - it stacks on the board, then gets out of
/// the way on its own.
class GameBanner extends StatelessWidget {
  const GameBanner({
    super.key,
    required this.message,
    this.subtitle,
    this.color = AppColors.gold,
    this.icon,
  });

  final String message;
  final String? subtitle;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
          ),
          child: Transform.rotate(
            angle: -0.06,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(color, Colors.white, 0.35)!,
                    color,
                    Color.lerp(color, Colors.black, 0.32)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                  ],
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 5, color: Colors.black54),
                          ],
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hosts a banner for a fixed time, then removes it.
class BannerHost extends StatefulWidget {
  const BannerHost({super.key, required this.child});

  final Widget child;

  @override
  State<BannerHost> createState() => BannerHostState();
}

class BannerHostState extends State<BannerHost> {
  _Banner? _current;
  int _seq = 0;

  void show(
    String message, {
    String? subtitle,
    Color color = AppColors.gold,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 1150),
  }) {
    final id = ++_seq;
    setState(() {
      _current = _Banner(
        id: id,
        message: message,
        subtitle: subtitle,
        color: color,
        icon: icon,
      );
    });
    Future<void>.delayed(duration, () {
      if (!mounted) return;
      setState(() {
        if (_current?.id == id) _current = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _current;
    return Stack(
      children: [
        widget.child,
        if (b != null)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.sizeOf(context).height * 0.30,
            child: GameBanner(
              message: b.message,
              subtitle: b.subtitle,
              color: b.color,
              icon: b.icon,
            ),
          ),
      ],
    );
  }
}

class _Banner {
  _Banner({
    required this.id,
    required this.message,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final int id;
  final String message;
  final String? subtitle;
  final Color color;
  final IconData? icon;
}

/// Rotating rays behind the crown on the victory screen.
class RotatingRaysPainter extends CustomPainter {
  const RotatingRaysPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 12; i++) {
      final a0 = progress * math.pi * 2 + i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a0), c.dy + r * math.sin(a0))
        ..lineTo(
          c.dx + r * math.cos(a0 + math.pi / 12),
          c.dy + r * math.sin(a0 + math.pi / 12),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RotatingRaysPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

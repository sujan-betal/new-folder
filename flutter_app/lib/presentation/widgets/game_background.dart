import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Deep, softly-lit backdrop for a match: a navy vertical gradient with a warm
/// halo behind the board and a vignette to keep the eyes on the tokens.
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child, this.glow});

  final Widget child;

  /// Colour of the halo; usually the active player's colour.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2A63), Color(0xFF0D1441), Color(0xFF070B26)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.95,
                  colors: [
                    (glow ?? AppColors.gold).withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

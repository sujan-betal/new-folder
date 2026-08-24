import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
          child: Text(
            'LUDO',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 6,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 6)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MASTER',
          style: TextStyle(
            fontSize: size * 0.28,
            fontWeight: FontWeight.w600,
            letterSpacing: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

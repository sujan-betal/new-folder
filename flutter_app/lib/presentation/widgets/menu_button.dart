import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class MenuButton extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldDark.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.brown.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A2C00),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF4A2C00)),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

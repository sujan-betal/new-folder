import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

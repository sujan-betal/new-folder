import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'board_painter.dart';
import 'dice_glow.dart';
import 'dice_widget.dart';

/// One player's corner station, Ludo King style: avatar, name, home pips
/// and THEIR OWN dice. The active player's dice glows and rolls in place.
class PlayerDicePanel extends StatelessWidget {
  const PlayerDicePanel({
    super.key,
    required this.colorName,
    required this.name,
    required this.avatar,
    required this.tokensHome,
    required this.active,
    required this.glowing,
    required this.diceValue,
    required this.rolling,
    required this.canRoll,
    this.onRollTap,
    this.diceSize = 46,
  });

  final String colorName;
  final String name;
  final String avatar;
  final int tokensHome;

  /// True while it is this player's turn.
  final bool active;

  /// True to pulse the dice halo.
  final bool glowing;
  final int diceValue;
  final bool rolling;
  final bool canRoll;
  final VoidCallback? onRollTap;
  final double diceSize;

  @override
  Widget build(BuildContext context) {
    final color = BoardPainter.colorOf(colorName);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: active ? 0.85 : 0.42),
            Color.lerp(color, Colors.black, 0.38)!
                .withValues(alpha: active ? 0.92 : 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.gold : Colors.white24,
          width: active ? 2.2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: CircleAvatar(
              radius: 13,
              backgroundColor: color,
              child: Text(avatar, style: const TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: List.generate(4, (i) {
                    final done = i < tokensHome;
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 1.2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? Colors.white : Colors.white24,
                        border: Border.all(
                            color: Colors.white70, width: 0.8),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DiceGlow(
            active: glowing,
            color: AppColors.gold,
            child: DiceWidget(
              value: diceValue <= 0 ? 1 : diceValue,
              rolling: rolling,
              color: color,
              size: diceSize,
              enabled: canRoll,
              onTap: onRollTap,
            ),
          ),
        ],
      ),
    );
  }
}

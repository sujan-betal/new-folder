import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'board_painter.dart';
import 'dice_glow.dart';
import 'dice_widget.dart';
import 'pawn_token.dart';

/// What the dock is asking its owner to do right now.
enum DicePrompt { roll, pickToken, waiting }

extension on DicePrompt {
  String get label => switch (this) {
        DicePrompt.roll => 'TAP TO ROLL',
        DicePrompt.pickToken => 'PICK A TOKEN',
        DicePrompt.waiting => '',
      };
}

/// One player's own dice, parked in their own corner of the board.
///
/// Ludo King gives every seat its own die rather than one shared die in the
/// middle, so you can see at a glance who has rolled and what. The box on turn
/// is gold-outlined and tappable; the rest are dimmed.
class PlayerDock extends StatelessWidget {
  const PlayerDock({
    super.key,
    required this.colorName,
    required this.name,
    required this.avatar,
    required this.tokensHome,
    required this.diceValue,
    required this.rolling,
    required this.prompt,
    this.onRollTap,
    this.pinFirst = false,
  });

  final String colorName;
  final String name;
  final String avatar;
  final int tokensHome;
  final int diceValue;
  final bool rolling;
  final DicePrompt prompt;
  final VoidCallback? onRollTap;

  /// True when this dock belongs to a right-hand base, so the token sits on
  /// the far side from the player's corner.
  final bool pinFirst;

  @override
  Widget build(BuildContext context) {
    final color = BoardPainter.colorOf(colorName);
    final active = prompt != DicePrompt.waiting;

    final pin = SizedBox(
      width: 30,
      child: PawnToken(size: 28, color: color, glowing: active),
    );
    final die = DiceWidget(
      value: diceValue <= 0 ? 1 : diceValue,
      rolling: rolling,
      color: color,
      size: 30,
      enabled: onRollTap != null,
      onTap: onRollTap,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: active ? 1.0 : 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: active ? AppColors.gold : Colors.white30,
                width: active ? 2.4 : 1.2,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.55),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pinFirst) ...[pin, const SizedBox(width: 5)],
                DiceGlow(
                  active: prompt == DicePrompt.roll,
                  color: AppColors.gold,
                  child: die,
                ),
                if (!pinFirst) ...[const SizedBox(width: 5), pin],
              ],
            ),
          ),
          const SizedBox(height: 3),
          if (active)
            Text(
              prompt.label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 3, color: Colors.black)],
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                final done = i < tokensHome;
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? color : Colors.transparent,
                    border: Border.all(
                      color: done ? color : Colors.white38,
                      width: 1,
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'board_painter.dart';
import 'dice_glow.dart';
import 'dice_widget.dart';

/// What the dock is asking the player to do right now.
enum DicePrompt { roll, pickToken, waiting }

extension on DicePrompt {
  String get _label => switch (this) {
        DicePrompt.roll => 'TAP TO ROLL',
        DicePrompt.pickToken => 'PICK A TOKEN',
        DicePrompt.waiting => 'THINKING...',
      };
}

/// Bottom dock: the turn prompt on the left, the live dice on the right.
///
/// This is the one place the player looks to know what to do, so the prompt
/// is loud, the dice is big, and the whole dock tints with the player on turn.
class DiceDock extends StatelessWidget {
  const DiceDock({
    super.key,
    required this.colorName,
    required this.name,
    required this.avatar,
    required this.prompt,
    required this.diceValue,
    required this.rolling,
    this.onRollTap,
    this.trailing,
  });

  final String colorName;
  final String name;
  final String avatar;
  final DicePrompt prompt;
  final int diceValue;
  final bool rolling;
  final VoidCallback? onRollTap;

  /// Optional widget pinned to the far left (e.g. a turn timer).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = BoardPainter.colorOf(colorName);
    final isMe = prompt != DicePrompt.waiting;

    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.34),
          ],
        ),
      ),
      child: Row(
        children: [
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: color, width: 2.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(avatar, style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black),
                              ],
                            ),
                          ),
                          Text(
                            isMe ? 'Your turn' : "Let's go",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color.withValues(alpha: 0.95),
                              shadows: const [
                                Shadow(blurRadius: 4, color: Colors.black),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _PromptPill(prompt: prompt, color: color),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DiceGlow(
            active: prompt == DicePrompt.roll,
            color: AppColors.gold,
            child: DiceWidget(
              value: diceValue <= 0 ? 1 : diceValue,
              rolling: rolling,
              color: color,
              size: 62,
              // Always tappable - the controller answers an early or illegal
              // tap with a cue instead of swallowing it.
              enabled: onRollTap != null,
              onTap: onRollTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptPill extends StatefulWidget {
  const _PromptPill({required this.prompt, required this.color});

  final DicePrompt prompt;
  final Color color;

  @override
  State<_PromptPill> createState() => _PromptPillState();
}

class _PromptPillState extends State<_PromptPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.prompt == DicePrompt.roll) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PromptPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prompt == DicePrompt.roll) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = Curves.easeInOut.transform(_controller.value);
    final live = widget.prompt == DicePrompt.roll;
    return Opacity(
      opacity: live ? 0.72 + pulse * 0.28 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: live ? AppColors.goldGradient : null,
          color: live ? null : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: live ? null : Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live) ...[
              const Icon(Icons.casino_rounded,
                  size: 15, color: Color(0xFF4A2C00)),
              const SizedBox(width: 6),
            ],
            Text(
              widget.prompt._label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: live ? const Color(0xFF4A2C00) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

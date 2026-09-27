import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'board_painter.dart';

/// One player chip in the top strip: avatar, name and the four home pips.
/// The active player is lifted, ringed in gold and marked with a bouncing
/// chevron, so the turn is readable without reading any text.
class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.colorName,
    required this.name,
    required this.avatar,
    required this.tokensHome,
    required this.active,
    required this.isMe,
  });

  final String colorName;
  final String name;
  final String avatar;
  final int tokensHome;
  final bool active;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final color = BoardPainter.colorOf(colorName);
    return AnimatedScale(
      scale: active ? 1.12 : 0.88,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: active ? 1.0 : 0.62,
        duration: const Duration(milliseconds: 260),
        child: SizedBox(
          width: 66,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 16,
                child: active ? const _TurnArrow() : null,
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer gold halo for the player on turn.
                  if (active)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.75),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          BoardPainter.lightOf(color),
                          BoardPainter.darkOf(color),
                        ],
                      ),
                      border: Border.all(
                        color: active ? Colors.white : Colors.white24,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        avatar,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  // Finished count badge.
                  if (tokensHome == 4)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold,
                        ),
                        child: const Icon(Icons.emoji_events,
                            size: 10, color: Color(0xFF4A2C00)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                isMe ? 'YOU' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: active
                      ? Colors.white
                      : (isMe ? AppColors.goldLight : Colors.white70),
                  shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final done = i < tokensHome;
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: done ? Colors.white : Colors.white38,
                        width: 1,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouncing chevron above the active player.
class _TurnArrow extends StatefulWidget {
  const _TurnArrow();

  @override
  State<_TurnArrow> createState() => _TurnArrowState();
}

class _TurnArrowState extends State<_TurnArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 2.5 * Curves.easeInOut.transform(_controller.value)),
        child: child,
      ),
      child: const Icon(Icons.keyboard_arrow_down_rounded,
          size: 20, color: AppColors.gold),
    );
  }
}

/// The row of player chips across the top of the board.
class PlayerStrip extends StatelessWidget {
  const PlayerStrip({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.42),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Celebration overlay shown when a match ends: confetti rain, a bouncing
/// winner medallion, the final standings and the reward earned.
class VictoryOverlay extends StatefulWidget {
  const VictoryOverlay({
    super.key,
    required this.winnerName,
    required this.winnerColor,
    required this.standings,
    required this.iWon,
    this.rewardLabel = '+50 coins',
    this.onPlayAgain,
    this.onHome,
  });

  final String winnerName;
  final Color winnerColor;

  /// Ranked [(name, color)] - first entry is the winner.
  final List<(String, Color)> standings;
  final bool iWon;
  final String rewardLabel;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onHome;

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final List<_Confetto> _pieces = _buildConfetti();

  @override
  void dispose() {
    _confetti.dispose();
    _entrance.dispose();
    super.dispose();
  }

  static List<_Confetto> _buildConfetti() {
    final rng = math.Random(2024);
    const palette = [
      AppColors.gold,
      AppColors.goldLight,
      AppColors.red,
      AppColors.green,
      AppColors.blue,
      AppColors.yellow,
      Colors.white,
    ];
    return List.generate(90, (i) {
      return _Confetto(
        x: rng.nextDouble(),
        start: rng.nextDouble(),
        drift: (rng.nextDouble() - 0.5) * 0.30,
        size: 6.0 + rng.nextDouble() * 7.0,
        spin: (rng.nextDouble() - 0.5) * 8,
        color: palette[rng.nextInt(palette.length)],
        square: rng.nextBool(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(
                  pieces: _pieces,
                  t: _confetti.value,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutBack,
                builder: (context, s, child) => Transform.scale(
                  scale: 0.7 + 0.3 * s,
                  child: Opacity(opacity: s.clamp(0.0, 1.0), child: child),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2B3E86), Color(0xFF111B3C)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.75),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 26,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WinnerBadge(color: widget.winnerColor),
                      const SizedBox(height: 10),
                      Text(
                        widget.iWon ? 'YOU WIN!' : 'GAME OVER',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: AppColors.gold,
                          shadows: [
                            Shadow(blurRadius: 12, color: Colors.black54),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.winnerName} takes the crown',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RewardChip(label: widget.rewardLabel),
                      const SizedBox(height: 16),
                      ...List.generate(widget.standings.length, (i) {
                        final (name, color) = widget.standings[i];
                        return _StandingRow(
                          rank: i + 1,
                          name: name,
                          color: color,
                          medal: _medal(i),
                        );
                      }),
                      const SizedBox(height: 20),
                      if (widget.onPlayAgain != null)
                        _BigButton(
                          label: 'PLAY AGAIN',
                          onTap: widget.onPlayAgain!,
                        ),
                      const SizedBox(height: 10),
                      if (widget.onHome != null)
                        _BigButton(
                          label: 'HOME',
                          ghost: true,
                          onTap: widget.onHome!,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _medal(int index) => switch (index) {
        0 => '\u{1F947}',
        1 => '\u{1F948}',
        2 => '\u{1F949}',
        _ => '\u{1F3C9}',
      };
}

/// Bouncing crown + coloured disc for the winner.
class _WinnerBadge extends StatefulWidget {
  const _WinnerBadge({required this.color});

  final Color color;

  @override
  State<_WinnerBadge> createState() => _WinnerBadgeState();
}

class _WinnerBadgeState extends State<_WinnerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [
                  Color.lerp(widget.color, Colors.white, 0.45)!,
                  widget.color,
                  Color.lerp(widget.color, Colors.black, 0.45)!,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              border: Border.all(color: AppColors.gold, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.55),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Text('\u{1F451}', style: TextStyle(fontSize: 46)),
            ),
          ),
        );
      },
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\u{1FA99}', style: TextStyle(fontSize: 17)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.name,
    required this.color,
    required this.medal,
  });

  final int rank;
  final String name;
  final Color color;
  final String medal;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: rank == 1
            ? AppColors.gold.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank == 1
              ? AppColors.gold.withValues(alpha: 0.7)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(medal, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.lerp(color, Colors.white, 0.4)!,
                  color,
                ],
              ),
              border: Border.all(color: Colors.white70, width: 1.2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.onTap,
    this.ghost = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: ghost ? null : AppColors.goldGradient,
          color: ghost ? Colors.white.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(15),
          border: ghost ? Border.all(color: Colors.white38) : null,
          boxShadow: ghost
              ? null
              : [
                  BoxShadow(
                    color: AppColors.goldDark.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: ghost ? Colors.white : const Color(0xFF4A2C00),
          ),
        ),
      ),
    );
  }
}

class _Confetto {
  _Confetto({
    required this.x,
    required this.start,
    required this.drift,
    required this.size,
    required this.spin,
    required this.color,
    required this.square,
  });

  final double x;
  final double start;
  final double drift;
  final double size;
  final double spin;
  final Color color;
  final bool square;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.pieces, required this.t});

  final List<_Confetto> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      // Each piece falls over its own window of the loop so the rain is even.
      final local = (t + p.start) % 1.0;
      final y = (local * 1.25 - 0.1) * size.height;
      final x = (p.x + p.drift * local) * size.width;
      final wobble = math.sin(local * 8 + p.x * 20) * 10;
      final fade = local > 0.85 ? (1.0 - (local - 0.85) / 0.15) : 1.0;

      canvas.save();
      canvas.translate(x + wobble, y);
      canvas.rotate(p.spin * local * math.pi);
      final w = p.size * (p.square ? 1.0 : 0.55);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: p.size * 1.5),
          const Radius.circular(1.5),
        ),
        Paint()..color = p.color.withValues(alpha: 0.9 * fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../game/board_geometry.dart';
import 'board_painter.dart';

class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.tokens,
    required this.currentColor,
    required this.movable,
    this.onTokenTap,
    this.highlightCurrent = true,
  });

  /// Map of color -> list of 4 positions (-1 base .. 57 home).
  final Map<String, List<int>> tokens;
  final String currentColor;
  final Set<int> movable;

  /// (color, tokenIndex) -> tap
  final void Function(String color, int tokenIndex)? onTokenTap;
  final bool highlightCurrent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ludo King style outer frame around the playing grid.
        const framePad = 9.0;
        final outer = constraints.biggest.shortestSide;
        final side = outer - framePad * 2;
        final cell = side / BoardGeometry.gridSize;

        final entries = <_TokenEntry>[];
        tokens.forEach((color, positions) {
          for (var i = 0; i < positions.length; i++) {
            final center = BoardGeometry.tokenCenter(
              color: color,
              pos: positions[i],
              tokenIndex: i,
              cell: cell,
            );
            entries.add(_TokenEntry(color, i, center));
          }
        });

        // Group tokens sharing nearly the same spot so they fan out slightly.
        final grouped = <String, List<_TokenEntry>>{};
        for (final e in entries) {
          final key = '${e.center.dx.toStringAsFixed(1)}:'
              '${e.center.dy.toStringAsFixed(1)}';
          grouped.putIfAbsent(key, () => []).add(e);
        }
        for (final group in grouped.values) {
          if (group.length <= 1) continue;
          final spread = cell * 0.22;
          for (var i = 0; i < group.length; i++) {
            final angle = 2 * math.pi * i / group.length;
            group[i].center = Offset(
              group[i].center.dx + spread * math.cos(angle),
              group[i].center.dy + spread * math.sin(angle),
            );
          }
        }

        return Container(
          width: outer,
          height: outer,
          padding: const EdgeInsets.all(framePad),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF243B6B), Color(0xFF14213D)],
            ),
            borderRadius: BorderRadius.circular(framePad * 2.4),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.55),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: BoardPainter(
                      activeColor: highlightCurrent ? currentColor : null,
                    ),
                  ),
                ),
                for (final e in entries)
                  _token(e, cell),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _token(_TokenEntry entry, double cell) {
    final color = BoardPainter.colorOf(entry.color);
    final isMine = entry.color == currentColor;
    final canMove = isMine && movable.contains(entry.tokenIndex);
    final size = cell * 0.74;

    final token = _PawnToken(size: size, color: color, glowing: canMove);

    Widget result = AnimatedPositioned(
      key: ValueKey('${entry.color}_${entry.tokenIndex}'),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      left: entry.center.dx - size / 2,
      top: entry.center.dy - size / 2,
      child: canMove
          ? _PulsingBox(cell: cell, child: token)
          : token,
    );

    if (canMove && onTokenTap != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTokenTap!(entry.color, entry.tokenIndex),
        child: AnimatedPositioned(
          key: ValueKey('hit_${entry.color}_${entry.tokenIndex}'),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          left: entry.center.dx - cell * 0.75,
          top: entry.center.dy - cell * 0.75,
          child: SizedBox(
            width: cell * 1.5,
            height: cell * 1.5,
            child: Center(child: _PulsingBox(cell: cell, child: token)),
          ),
        ),
      );
    }

    return result;
  }
}

/// Glossy pawn token, Ludo King style.
class _PawnToken extends StatelessWidget {
  const _PawnToken({
    required this.size,
    required this.color,
    required this.glowing,
  });

  final double size;
  final Color color;
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Drop shadow.
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.86,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Body.
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                radius: 1.1,
                colors: [
                  Color.lerp(color, Colors.white, 0.55)!,
                  color,
                  Color.lerp(color, Colors.black, 0.35)!,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: glowing ? AppColors.gold : Colors.white,
                width: glowing ? 2.6 : 1.8,
              ),
              boxShadow: glowing
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.85),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
          ),
          // White collar ring.
          Container(
            width: size * 0.44,
            height: size * 0.44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(
                color: Color.lerp(color, Colors.black, 0.25)!,
                width: 1.2,
              ),
            ),
          ),
          // Head sphere.
          Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: [
                  Color.lerp(color, Colors.white, 0.65)!,
                  color,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gentle heartbeat animation for tokens the player can move.
class _PulsingBox extends StatefulWidget {
  const _PulsingBox({required this.cell, required this.child});

  final double cell;
  final Widget child;

  @override
  State<_PulsingBox> createState() => _PulsingBoxState();
}

class _PulsingBoxState extends State<_PulsingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    lowerBound: 0.94,
    upperBound: 1.08,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _controller, child: widget.child);
  }
}

class _TokenEntry {
  _TokenEntry(this.color, this.tokenIndex, this.center);

  final String color;
  final int tokenIndex;
  Offset center;
}

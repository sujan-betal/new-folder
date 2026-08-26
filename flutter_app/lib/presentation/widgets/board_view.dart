import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../game/board_geometry.dart';
import '../../game/ludo_engine.dart';
import 'board_painter.dart';
import 'flame_burst.dart';

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.tokens,
    required this.currentColor,
    required this.movable,
    this.onTokenTap,
    this.highlightCurrent = true,
    this.boardFx,
  });

  /// Map of color -> list of 4 positions (-1 base .. 57 home).
  final Map<String, List<int>> tokens;
  final String currentColor;
  final Set<int> movable;

  /// (color, tokenIndex) -> tap
  final void Function(String color, int tokenIndex)? onTokenTap;
  final bool highlightCurrent;

  /// Latest visual event (kill flames / home sparkles).
  final BoardFx? boardFx;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  int? _lastFxId;
  final List<_ActiveBurst> _bursts = [];

  void _consumeFx(double cell) {
    final fx = widget.boardFx;
    if (fx == null || fx.id == _lastFxId) return;
    _lastFxId = fx.id;
    _bursts.clear();
    for (final spot in fx.spots) {
      final center = BoardGeometry.tokenCenter(
        color: spot.color,
        pos: spot.pos,
        tokenIndex: spot.tokenIndex,
        cell: cell,
      );
      _bursts.add(_ActiveBurst(
        key: ValueKey('fx_${fx.id}_${spot.color}_${spot.tokenIndex}'),
        center: center,
        style: fx.kind == FxKind.flame ? FxStyle.flame : FxStyle.sparkle,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ludo King style outer frame around the playing grid.
        const framePad = 9.0;
        final outer = constraints.biggest.shortestSide;
        final side = outer - framePad * 2;
        final cell = side / BoardGeometry.gridSize;

        _consumeFx(cell);

        final tokens = widget.tokens;
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
                      activeColor:
                          widget.highlightCurrent ? widget.currentColor : null,
                    ),
                  ),
                ),
                for (final e in entries) _token(e, cell),
                for (final burst in _bursts)
                  Positioned(
                    key: burst.key,
                    left: burst.center.dx - cell * 1.1,
                    top: burst.center.dy - cell * 1.1,
                    width: cell * 2.2,
                    height: cell * 2.2,
                    child: FlameBurst(
                      size: cell * 2.2,
                      style: burst.style,
                      onFinished: () => _removeBurst(burst.key),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeBurst(Key key) {
    if (!mounted) return;
    setState(() {
      _bursts.removeWhere((b) => b.key == key);
    });
  }

  Widget _token(_TokenEntry entry, double cell) {
    final color = BoardPainter.colorOf(entry.color);
    final isMine = entry.color == widget.currentColor;
    final canMove = isMine && widget.movable.contains(entry.tokenIndex);
    final size = cell * 0.88;

    final token = _PawnToken(size: size, color: color, glowing: canMove);

    return AnimatedPositioned(
      key: ValueKey('${entry.color}_${entry.tokenIndex}'),
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOutCubic,
      left: entry.center.dx - size / 2,
      top: entry.center.dy - size / 2,
      child: canMove && widget.onTokenTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => widget.onTokenTap!(entry.color, entry.tokenIndex),
              child: _PulsingBox(cell: cell, child: token),
            )
          : canMove
              ? _PulsingBox(cell: cell, child: token)
              : token,
    );
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
          // Drop shadow ellipse.
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.88,
              height: size * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Outer colored disc - makes the token more visible on the board.
          Container(
            width: size * 0.90,
            height: size * 0.90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.35),
                radius: 1.15,
                colors: [
                  Color.lerp(color, Colors.white, 0.45)!,
                  color,
                  Color.lerp(color, Colors.black, 0.40)!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(
                color: glowing ? AppColors.gold : Colors.white,
                width: glowing ? 3.0 : 2.2,
              ),
              boxShadow: glowing
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.9),
                        blurRadius: 14,
                        spreadRadius: 3,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
          ),
          // White collar ring.
          Container(
            width: size * 0.48,
            height: size * 0.48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.95),
              border: Border.all(
                color: Color.lerp(color, Colors.black, 0.20)!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          // Head sphere.
          Container(
            width: size * 0.30,
            height: size * 0.30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                radius: 1.1,
                colors: [
                  Color.lerp(color, Colors.white, 0.60)!,
                  color,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(-0.5, -0.5),
                ),
              ],
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
    duration: const Duration(milliseconds: 480),
    lowerBound: 0.92,
    upperBound: 1.12,
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

class _ActiveBurst {
  const _ActiveBurst({
    required this.key,
    required this.center,
    required this.style,
  });

  final Key key;
  final Offset center;
  final FxStyle style;
}

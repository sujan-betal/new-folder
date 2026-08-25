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
        final side = constraints.biggest.shortestSide;
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

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: const BoardPainter()),
              ),
              for (final e in entries) _token(e, cell),
            ],
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

    final token = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
        ),
        border: Border.all(
          color: canMove ? AppColors.gold : Colors.white,
          width: canMove ? 2.6 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          if (canMove)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.9),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.42,
          height: size * 0.42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );

    Widget result = AnimatedPositioned(
      key: ValueKey('${entry.color}_${entry.tokenIndex}'),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      left: entry.center.dx - size / 2,
      top: entry.center.dy - size / 2,
      child: token,
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
            child: Center(child: token),
          ),
        ),
      );
    }

    return result;
  }
}

class _TokenEntry {
  _TokenEntry(this.color, this.tokenIndex, this.center);

  final String color;
  final int tokenIndex;
  Offset center;
}

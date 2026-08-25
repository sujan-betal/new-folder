import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../game/board_geometry.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter();

  static Color colorOf(String name) {
    switch (name) {
      case 'red':
        return AppColors.red;
      case 'green':
        return AppColors.green;
      case 'yellow':
        return AppColors.yellow;
      default:
        return AppColors.blue;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / BoardGeometry.gridSize;

    _drawBases(canvas, cell);
    _drawTrack(canvas, cell);
    _drawHomeColumns(canvas, cell);
    _drawCenter(canvas, cell);
  }

  Rect _rect(int row, int col, double cell) =>
      Rect.fromLTWH(col * cell, row * cell, cell, cell);

  void _drawBases(Canvas canvas, double cell) {
    BoardGeometry.baseOrigins.forEach((name, origin) {
      final color = colorOf(name);
      final baseRect = Rect.fromLTWH(
        origin.dx * cell,
        origin.dy * cell,
        cell * 6,
        cell * 6,
      );
      canvas.drawRect(baseRect, Paint()..color = color);

      final inner = Rect.fromLTWH(
        (origin.dx + 1) * cell,
        (origin.dy + 1) * cell,
        cell * 4,
        cell * 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.45)),
        Paint()..color = Colors.white,
      );

      final slots = const [
        Offset(2, 2),
        Offset(2, 4),
        Offset(4, 2),
        Offset(4, 4),
      ];
      for (final s in slots) {
        final center = Offset(
          (origin.dx + s.dx) * cell,
          (origin.dy + s.dy) * cell,
        );
        canvas.drawCircle(
          center,
          cell * 0.55,
          Paint()..color = color.withValues(alpha: 0.16),
        );
        canvas.drawCircle(
          center,
          cell * 0.55,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = color.withValues(alpha: 0.5),
        );
      }
    });
  }

  void _drawTrack(Canvas canvas, double cell) {
    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.grey.shade400;

    for (var i = 0; i < BoardGeometry.ringCells.length; i++) {
      final rc = BoardGeometry.ringCells[i];
      canvas.drawRect(_rect(rc[0], rc[1], cell), fill);

      final startColor = BoardGeometry.startOffsets.entries
          .where((e) => e.value == i)
          .map((e) => e.key)
          .toList();
      if (startColor.isNotEmpty) {
        canvas.drawRect(_rect(rc[0], rc[1], cell),
            Paint()..color = colorOf(startColor.first).withValues(alpha: 0.85));
      } else if (BoardGeometry.safeSquares.contains(i)) {
        final center = Offset((rc[1] + 0.5) * cell, (rc[0] + 0.5) * cell);
        _drawStar(canvas, center, cell * 0.34);
      }

      canvas.drawRect(_rect(rc[0], rc[1], cell), stroke);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? radius : radius * 0.45;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = AppColors.gold.withValues(alpha: 0.75));
  }

  void _drawHomeColumns(Canvas canvas, double cell) {
    BoardGeometry.laneCells.forEach((name, cells) {
      for (final rc in cells) {
        canvas.drawRect(_rect(rc[0], rc[1], cell),
            Paint()..color = colorOf(name).withValues(alpha: 0.78));
        canvas.drawRect(
          _rect(rc[0], rc[1], cell),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.grey.shade400,
        );
      }
    });
  }

  void _drawCenter(Canvas canvas, double cell) {
    final center = Offset(7.5 * cell, 7.5 * cell);
    final triangles = <String, List<Offset>>{
      'red': [
        Offset(6 * cell, 6 * cell),
        Offset(6 * cell, 9 * cell),
        center,
      ],
      'green': [
        Offset(6 * cell, 6 * cell),
        Offset(9 * cell, 6 * cell),
        center,
      ],
      'yellow': [
        Offset(9 * cell, 6 * cell),
        Offset(9 * cell, 9 * cell),
        center,
      ],
      'blue': [
        Offset(6 * cell, 9 * cell),
        Offset(9 * cell, 9 * cell),
        center,
      ],
    };

    triangles.forEach((name, points) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, Paint()..color = colorOf(name));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

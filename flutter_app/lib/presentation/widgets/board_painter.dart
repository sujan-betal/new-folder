import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../game/board_geometry.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter({this.activeColor});

  /// Color of the player whose turn it is - their base gets a glow.
  final String? activeColor;

  // Ludo King palette: crisp dark outlines on a clean white track.
  static const _line = Color(0xFF546E7A);
  static const _trackFill = Colors.white;

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

  static Color darkOf(Color c) => Color.lerp(c, Colors.black, 0.32)!;

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
      final isActive = name == activeColor;
      final baseRect = Rect.fromLTWH(
        origin.dx * cell,
        origin.dy * cell,
        cell * 6,
        cell * 6,
      );

      // Soft golden glow behind the active player's quadrant.
      if (isActive) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(baseRect.deflate(cell * 0.12),
              Radius.circular(cell * 0.5)),
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.55)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.55),
        );
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(baseRect, Radius.circular(cell * 0.35)),
        Paint()..color = color,
      );
      // Dark outer ring like Ludo King's raised quadrants.
      canvas.drawRRect(
        RRect.fromRectAndRadius(baseRect.deflate(cell * 0.1),
            Radius.circular(cell * 0.3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.22
          ..color = darkOf(color),
      );
      // Subtle top-light bevel.
      canvas.drawRect(
        baseRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.18),
            ],
          ).createShader(baseRect),
      );

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
      // Thick colored ring around the white panel.
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.45)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.3
          ..color = color,
      );

      const slots = [
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
        // Solid token cradle with a white gap ring, exactly like LK.
        canvas.drawCircle(center, cell * 0.62, Paint()..color = Colors.white);
        canvas.drawCircle(
          center,
          cell * 0.5,
          Paint()..color = color.withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          center,
          cell * 0.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..color = darkOf(color),
        );
      }
    });
  }

  void _drawTrack(Canvas canvas, double cell) {
    final fill = Paint()..color = _trackFill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.055
      ..color = _line;

    for (var i = 0; i < BoardGeometry.ringCells.length; i++) {
      final rc = BoardGeometry.ringCells[i];
      canvas.drawRect(_rect(rc[0], rc[1], cell), fill);

      final startEntry = BoardGeometry.startOffsets.entries
          .where((e) => e.value == i)
          .map((e) => e.key)
          .toList();
      if (startEntry.isNotEmpty) {
        final color = colorOf(startEntry.first);
        canvas.drawRect(_rect(rc[0], rc[1], cell), Paint()..color = color);
        _drawArrow(canvas, rc[0], rc[1], startEntry.first, cell);
      } else if (BoardGeometry.safeSquares.contains(i)) {
        final center = Offset((rc[1] + 0.5) * cell, (rc[0] + 0.5) * cell);
        _drawStar(canvas, center, cell * 0.36);
      }

      canvas.drawRect(_rect(rc[0], rc[1], cell), stroke);
    }
  }

  /// White direction arrow on a colored starting square, Ludo King style.
  void _drawArrow(
    Canvas canvas,
    int row,
    int col,
    String colorName,
    double cell,
  ) {
    // Movement direction leaving each start square.
    final angles = <String, double>{
      'red': 0, // east
      'green': math.pi / 2, // south
      'yellow': math.pi, // west
      'blue': -math.pi / 2, // north
    };
    final center = Offset((col + 0.5) * cell, (row + 0.5) * cell);
    final r = cell * 0.28;
    final path = Path()
      ..moveTo(center.dx + r, center.dy)
      ..lineTo(center.dx - r * 0.5, center.dy - r * 0.75)
      ..lineTo(center.dx - r * 0.25, center.dy)
      ..lineTo(center.dx - r * 0.5, center.dy + r * 0.75)
      ..close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angles[colorName] ?? 0);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.restore();
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
    canvas.drawPath(path, Paint()..color = AppColors.gold);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.14
        ..color = darkOf(AppColors.goldDark),
    );
  }

  void _drawHomeColumns(Canvas canvas, double cell) {
    BoardGeometry.laneCells.forEach((name, cells) {
      for (final rc in cells) {
        canvas.drawRect(_rect(rc[0], rc[1], cell),
            Paint()..color = colorOf(name).withValues(alpha: 0.92));
        canvas.drawRect(
          _rect(rc[0], rc[1], cell),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.055
            ..color = _line,
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
    });

    // Bold white cross separating the four triangles.
    final cross = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.16
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(6 * cell, 6 * cell), Offset(9 * cell, 9 * cell), cross);
    canvas.drawLine(
        Offset(9 * cell, 6 * cell), Offset(6 * cell, 9 * cell), cross);

    // Center medallion with a star, like the Ludo King home.
    final medallionR = cell * 1.05;
    canvas.drawCircle(
      center,
      medallionR,
      Paint()
        ..color = Colors.white
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.06),
    );
    canvas.drawCircle(center, medallionR * 0.86, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      medallionR * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.09
        ..color = AppColors.gold,
    );
    _drawStar(canvas, center, medallionR * 0.52);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.activeColor != activeColor;
}

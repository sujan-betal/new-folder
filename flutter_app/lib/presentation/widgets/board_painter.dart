import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../game/board_geometry.dart';

/// Ludo King style board painter.
///
/// The house style is deliberately flat: solid fills, one hairline grid, and
/// almost no shading. Everything reads as printed ink rather than moulded
/// plastic, which is what separates a ludo board from a chess one.
class BoardPainter extends CustomPainter {
  const BoardPainter({this.activeColor});

  /// Color of the player whose turn it is - their base gets a keyline.
  final String? activeColor;

  /// Hairline grid. Ludo King uses one thin line everywhere, so any heavier
  /// and the board turns into a comic.
  static const _line = Color(0xFF6B6B6B);
  static const _lineWidthRatio = 0.045;

  /// Star outline on the safe squares - an outline, not a gold sticker.
  static const _starInk = Color(0xFF3A3A3A);

  static const _trackFill = Color(0xFFFDFDFD);

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

  static Color darkOf(Color c) => Color.lerp(c, Colors.black, 0.22)!;

  static Color lightOf(Color c) => Color.lerp(c, Colors.white, 0.28)!;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / BoardGeometry.gridSize;

    _paintSurface(canvas, size, cell);
    _drawTrack(canvas, cell);
    _drawHomeColumns(canvas, cell);
    _drawBases(canvas, cell);
    _drawCenter(canvas, cell);
  }

  Rect _rect(int row, int col, double cell) =>
      Rect.fromLTWH(col * cell, row * cell, cell, cell);

  /// Flat white surface, hairline border, nothing else.
  void _paintSurface(Canvas canvas, Size size, double cell) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _trackFill);
    canvas.drawRect(
      rect.deflate(cell * 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.08
        ..color = _line,
    );
  }

  void _drawTrack(Canvas canvas, double cell) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * _lineWidthRatio
      ..color = _line;

    for (var i = 0; i < BoardGeometry.ringCells.length; i++) {
      final rc = BoardGeometry.ringCells[i];
      final rect = _rect(rc[0], rc[1], cell);
      final startEntry = BoardGeometry.startOffsets.entries
          .where((e) => e.value == i)
          .map((e) => e.key)
          .firstOrNull;

      // Start squares are white with a coloured arrow, not solid colour.
      canvas.drawRect(rect, Paint()..color = _trackFill);

      if (startEntry != null) {
        _drawStartArrow(canvas, rect.center, startEntry, cell);
      } else if (BoardGeometry.safeSquares.contains(i)) {
        _drawSafeStar(canvas, rect.center, cell);
      }
      canvas.drawRect(rect, stroke);
    }
  }

  /// Outlined arrowhead in the owner's colour.
  void _drawStartArrow(
    Canvas canvas,
    Offset center,
    String colorName,
    double cell,
  ) {
    const angles = <String, double>{
      'red': 0, // east
      'green': math.pi / 2, // south
      'yellow': math.pi, // west
      'blue': -math.pi / 2, // north
    };
    final r = cell * 0.34;
    final path = Path()
      ..moveTo(center.dx + r, center.dy)
      ..lineTo(center.dx - r * 0.55, center.dy - r * 0.85)
      ..lineTo(center.dx - r * 0.22, center.dy)
      ..lineTo(center.dx - r * 0.55, center.dy + r * 0.85)
      ..close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angles[colorName] ?? 0);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.085
        ..strokeJoin = StrokeJoin.round
        ..color = colorOf(colorName),
    );
    canvas.restore();
  }

  /// Safe square: a plain outlined star, like the print on a real board.
  void _drawSafeStar(Canvas canvas, Offset center, double cell) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = (i.isEven ? cell * 0.30 : cell * 0.145);
      final p = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.055
        ..strokeJoin = StrokeJoin.round
        ..color = _starInk,
    );
  }

  /// Home columns: solid colour, hairline separators, no arrows.
  void _drawHomeColumns(Canvas canvas, double cell) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * _lineWidthRatio
      ..color = _line;
    BoardGeometry.laneCells.forEach((name, cells) {
      final color = colorOf(name);
      for (final rc in cells) {
        final rect = _rect(rc[0], rc[1], cell);
        canvas.drawRect(rect, Paint()..color = color);
        canvas.drawRect(rect, stroke);
      }
    });
  }

  void _drawBases(Canvas canvas, double cell) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * _lineWidthRatio
      ..color = _line;

    BoardGeometry.baseOrigins.forEach((name, origin) {
      final color = colorOf(name);
      final baseRect = Rect.fromLTWH(
        origin.dx * cell,
        origin.dy * cell,
        cell * 6,
        cell * 6,
      );

      // Turn indicator: a gold keyline around the block, not a fill - a
      // translucent slab over the base washes the colour out.
      if (name == activeColor) {
        canvas.drawRect(
          baseRect.inflate(cell * 0.12),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.14
            ..color = AppColors.gold,
        );
      }

      // Flat colour block with a hairline edge.
      canvas.drawRect(baseRect, Paint()..color = color);
      canvas.drawRect(baseRect, stroke);

      // White panel the four tokens wait in.
      final inner = Rect.fromLTWH(
        (origin.dx + 1) * cell,
        (origin.dy + 1) * cell,
        cell * 4,
        cell * 4,
      );
      canvas.drawRect(inner, Paint()..color = _trackFill);
      canvas.drawRect(inner, stroke);

      // Four plain slots - solid dots, no ring, no halo.
      const slots = [Offset(2, 2), Offset(2, 4), Offset(4, 2), Offset(4, 4)];
      for (final s in slots) {
        final center = Offset(
          (origin.dx + s.dx) * cell,
          (origin.dy + s.dy) * cell,
        );
        canvas.drawCircle(center, cell * 0.30, Paint()..color = color);
      }
    });
  }

  /// Four flat triangles meeting at a point, plus a small diamond.
  void _drawCenter(Canvas canvas, double cell) {
    final center = Offset(7.5 * cell, 7.5 * cell);
    const corners = {
      'red': [Offset(6, 6), Offset(6, 9)],
      'yellow': [Offset(9, 6), Offset(9, 9)],
      'green': [Offset(6, 6), Offset(9, 6)],
      'blue': [Offset(6, 9), Offset(9, 9)],
    };

    corners.forEach((name, pts) {
      final path = Path()
        ..moveTo(pts[0].dx * cell, pts[0].dy * cell)
        ..lineTo(pts[1].dx * cell, pts[1].dy * cell)
        ..lineTo(center.dx, center.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = colorOf(name));
    });

    canvas.drawRect(
      Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * _lineWidthRatio
        ..color = _line,
    );

    // Small diamond hub where the four triangles meet.
    final d = cell * 0.34;
    final hub = Path()
      ..moveTo(center.dx, center.dy - d)
      ..lineTo(center.dx + d, center.dy)
      ..lineTo(center.dx, center.dy + d)
      ..lineTo(center.dx - d, center.dy)
      ..close();
    canvas.drawPath(hub, Paint()..color = const Color(0xFF7FD4F5));
    canvas.drawPath(
      hub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.05
        ..color = _line,
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.activeColor != activeColor;
}

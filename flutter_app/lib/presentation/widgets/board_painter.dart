import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../game/board_geometry.dart';
import 'pawn_token.dart' show paintStar;

class BoardPainter extends CustomPainter {
  const BoardPainter({this.activeColor});

  /// Color of the player whose turn it is - their base gets a glow.
  final String? activeColor;

  // Ludo King draws the board flat and cartoon-bold: near-black outlines on
  // every element, light shading only to suggest depth.
  static const _line = Color(0xFF37474F);
  static const _outline = Color(0xFF1A1A1A);
  static const _trackFill = Colors.white;
  static const _boardEdge = Color(0xFF37474F);

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

  static Color darkOf(Color c) => Color.lerp(c, Colors.black, 0.24)!;

  static Color lightOf(Color c) => Color.lerp(c, Colors.white, 0.34)!;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / BoardGeometry.gridSize;

    _paintBoardBed(canvas, size, cell);
    _drawTrack(canvas, cell);
    _drawHomeColumns(canvas, cell);
    _drawBases(canvas, cell);
    _drawCenter(canvas, cell);
    _paintTopGloss(canvas, size);
  }

  Rect _rect(int row, int col, double cell) =>
      Rect.fromLTWH(col * cell, row * cell, cell, cell);

  /// Flat white playing surface with a hard edge - a printed board, not a
  /// shaded one.
  void _paintBoardBed(Canvas canvas, Size size, double cell) {
    final bed = Offset.zero & size;
    canvas.drawRect(bed, Paint()..color = _trackFill);
    canvas.drawRect(
      bed.deflate(cell * 0.07),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.14
        ..color = _boardEdge,
    );
  }

  void _drawTrack(Canvas canvas, double cell) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.07
      ..color = _outline;

    for (var i = 0; i < BoardGeometry.ringCells.length; i++) {
      final rc = BoardGeometry.ringCells[i];
      final rect = _rect(rc[0], rc[1], cell);
      final isStart = BoardGeometry.startOffsets.containsValue(i);
      final isSafe = BoardGeometry.safeSquares.contains(i);

      canvas.drawRect(
          rect, Paint()..color = isStart ? Colors.transparent : _trackFill);

      if (isStart) {
        final startEntry = BoardGeometry.startOffsets.entries
            .where((e) => e.value == i)
            .map((e) => e.key)
            .first;
        final color = colorOf(startEntry);
        _paintCellGloss(canvas, rect, color);
        _drawArrow(canvas, rect.center, startEntry, cell);
      } else {
        // Faint decorative notch so plain track cells are not dead space.
        canvas.drawRect(
          rect.deflate(cell * 0.28),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.035
            ..color = _line.withValues(alpha: 0.16),
        );
        if (isSafe) {
          paintStar(
            canvas,
            rect.center,
            cell * 0.34,
            color: AppColors.gold,
            outline: AppColors.goldDark,
          );
        }
      }

      canvas.drawRect(rect, stroke);
    }
  }

  /// Vertical gloss used on the start squares and home lanes.
  void _paintCellGloss(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lightOf(color), color, darkOf(color)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.26),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  /// White direction arrow on a colored starting square.
  void _drawArrow(
    Canvas canvas,
    Offset center,
    String colorName,
    double cell,
  ) {
    final angles = <String, double>{
      'red': 0, // east
      'green': math.pi / 2, // south
      'yellow': math.pi, // west
      'blue': -math.pi / 2, // north
    };
    // Solid chunky arrowhead, the way LK marks each start square.
    final r = cell * 0.32;
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
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06
        ..strokeJoin = StrokeJoin.round
        ..color = _outline,
    );
    canvas.restore();
  }

  void _drawHomeColumns(Canvas canvas, double cell) {
    BoardGeometry.laneCells.forEach((name, cells) {
      final color = colorOf(name);
      final pointsToward = <String, double>{
        'red': 0, // east, toward the centre
        'green': math.pi / 2,
        'yellow': math.pi,
        'blue': -math.pi / 2,
      }[name]!;

      cells.asMap().forEach((index, rc) {
        final rect = _rect(rc[0], rc[1], cell);
        _paintCellGloss(canvas, rect, color);
        // The last lane square is the finish tile: crown it with a star.
        if (index == cells.length - 1) {
          paintStar(
            canvas,
            rect.center,
            cell * 0.32,
            color: Colors.white,
            outline: Colors.white,
          );
        } else {
          canvas.save();
          canvas.translate(rect.center.dx, rect.center.dy);
          canvas.rotate(pointsToward);
          final r = cell * 0.26;
          final chevron = Path()
            ..moveTo(-r * 0.55, -r * 0.9)
            ..lineTo(r * 0.6, 0)
            ..lineTo(-r * 0.55, r * 0.9)
            ..close();
          canvas.drawPath(
            chevron,
            Paint()..color = Colors.white.withValues(alpha: 0.92),
          );
          canvas.drawPath(
            chevron,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.05
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black.withValues(alpha: 0.18),
          );
          canvas.restore();
        }
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.07
            ..color = _outline,
        );
      });
    });
  }

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

      if (isActive) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              baseRect.inflate(cell * 0.18), Radius.circular(cell * 0.5)),
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.5),
        );
      }

      // Raised coloured block: one light-to-shade ramp, no bevel ring.
      canvas.drawRRect(
        RRect.fromRectAndRadius(baseRect, Radius.circular(cell * 0.30)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lightOf(color), color, darkOf(color)],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(baseRect),
      );
      // Bold cartoon outline - what makes the board read as LK.
      canvas.drawRRect(
        RRect.fromRectAndRadius(baseRect, Radius.circular(cell * 0.30)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.14
          ..color = _outline,
      );
      // Top-left sheen.
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(baseRect, Radius.circular(cell * 0.30)),
      );
      canvas.drawRect(
        Rect.fromLTWH(baseRect.left, baseRect.top, baseRect.width,
            baseRect.height * 0.30),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(baseRect),
      );
      canvas.restore();

      // White yard panel the tokens sit in.
      final inner = Rect.fromLTWH(
        (origin.dx + 1) * cell,
        (origin.dy + 1) * cell,
        cell * 4,
        cell * 4,
      );
      final rrect =
          RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.40));
      canvas.drawRRect(rrect, Paint()..color = Colors.white);
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.22
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
        // Flat coloured disc with a bold ring - the way a printed ludo board
        // marks the four parking spots.
        final r = cell * 0.56;
        canvas.drawCircle(
          center,
          r,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          center,
          r * 0.88,
          Paint()..color = color,
        );
        // Small gloss arc, top-left, just enough to read as moulded plastic.
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r * 0.60),
          math.pi * 1.05,
          math.pi * 0.55,
          true,
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
        canvas.drawCircle(
          center,
          r * 0.88,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.09
            ..color = _outline,
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
      final color = colorOf(name);
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lightOf(color), color, darkOf(color)],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
      );
      // A soft wedge of light per triangle.
      canvas.save();
      canvas.clipPath(path);
      canvas.drawCircle(
        Offset(7.0 * cell, 7.0 * cell),
        cell * 1.9,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.26),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(
              center: Offset(7.0 * cell, 7.0 * cell), radius: cell * 1.9)),
      );
      canvas.restore();
    });

    // Bold white cross separating the four triangles.
    final cross = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.18
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(6 * cell, 6 * cell), Offset(9 * cell, 9 * cell), cross);
    canvas.drawLine(
        Offset(9 * cell, 6 * cell), Offset(6 * cell, 9 * cell), cross);

    // Hard outline around the whole centre block.
    canvas.drawRect(
      Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.09
        ..color = _outline,
    );

    // Centre medallion.
    final medallionR = cell * 1.02;
    canvas.drawCircle(
      center,
      medallionR * 1.12,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08),
    );
    canvas.drawCircle(
      center,
      medallionR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFFF1C9)],
        ).createShader(Rect.fromCircle(center: center, radius: medallionR)),
    );
    canvas.drawCircle(
      center,
      medallionR * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.10
        ..color = AppColors.gold,
    );
    paintStar(
      canvas,
      center,
      medallionR * 0.52,
      color: AppColors.gold,
      outline: AppColors.goldDark,
    );
  }

  /// Faint sheen over the whole board - enough to look moulded, not enough to
  /// soften the outlines.
  void _paintTopGloss(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment(0.75, 1.0),
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.32, 0.62, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.activeColor != activeColor;
}

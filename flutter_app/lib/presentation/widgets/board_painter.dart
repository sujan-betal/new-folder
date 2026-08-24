import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter();

  static const List<List<int>> _track = [
    [6, 1], [6, 2], [6, 3], [6, 4], [6, 5],
    [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6],
    [0, 7], [0, 8],
    [1, 8], [2, 8], [3, 8], [4, 8], [5, 8],
    [6, 9], [6, 10], [6, 11], [6, 12], [6, 13], [6, 14],
    [7, 14], [8, 14],
    [8, 13], [8, 12], [8, 11], [8, 10], [8, 9],
    [9, 8], [10, 8], [11, 8], [12, 8], [13, 8],
    [14, 8], [14, 7], [14, 6],
    [13, 6], [12, 6], [11, 6], [10, 6], [9, 6],
    [8, 5], [8, 4], [8, 3], [8, 2], [8, 1], [8, 0],
    [7, 0], [6, 0],
  ];

  static const Map<String, int> _startIndices = {
    'red': 0,
    'green': 13,
    'yellow': 26,
    'blue': 39,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;

    _drawBases(canvas, cell);
    _drawTrack(canvas, cell);
    _drawHomeColumns(canvas, cell);
    _drawCenter(canvas, cell);
  }

  Rect _rect(int row, int col, double cell) =>
      Rect.fromLTWH(col * cell, row * cell, cell, cell);

  Color _color(String name) {
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

  void _drawBases(Canvas canvas, double cell) {
    final bases = <String, Offset>{
      'red': const Offset(0, 0),
      'green': const Offset(9, 0),
      'yellow': const Offset(9, 9),
      'blue': const Offset(0, 9),
    };

    bases.forEach((name, origin) {
      final color = _color(name);
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
        RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.4)),
        Paint()..color = Colors.white,
      );

      final slots = [
        Offset(origin.dx + 2, origin.dy + 2),
        Offset(origin.dx + 2, origin.dy + 4),
        Offset(origin.dx + 4, origin.dy + 2),
        Offset(origin.dx + 4, origin.dy + 4),
      ];
      for (final s in slots) {
        canvas.drawCircle(
          Offset(s.dx * cell, s.dy * cell),
          cell * 0.55,
          Paint()..color = color.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          Offset(s.dx * cell, s.dy * cell),
          cell * 0.55,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.black26,
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

    for (var i = 0; i < _track.length; i++) {
      final r = _track[i][0];
      final c = _track[i][1];
      canvas.drawRect(_rect(r, c, cell), fill);

      final startColor = _startIndices.entries
          .where((e) => e.value == i)
          .map((e) => e.key)
          .toList();
      if (startColor.isNotEmpty) {
        canvas.drawRect(_rect(r, c, cell), Paint()..color = _color(startColor.first));
      } else if (i % 13 == 0 || i == 8 || i == 21 || i == 34 || i == 47) {
        canvas.drawCircle(
          Offset((c + 0.5) * cell, (r + 0.5) * cell),
          cell * 0.28,
          Paint()..color = AppColors.gold.withValues(alpha: 0.6),
        );
      }

      canvas.drawRect(_rect(r, c, cell), stroke);
    }
  }

  void _drawHomeColumns(Canvas canvas, double cell) {
    void drawCells(List<List<int>> cells, String colorName) {
      for (final rc in cells) {
        canvas.drawRect(_rect(rc[0], rc[1], cell),
            Paint()..color = _color(colorName).withValues(alpha: 0.75));
        canvas.drawRect(
          _rect(rc[0], rc[1], cell),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.grey.shade400,
        );
      }
    }

    drawCells([
      [7, 1], [7, 2], [7, 3], [7, 4], [7, 5]
    ], 'red');
    drawCells([
      [1, 7], [2, 7], [3, 7], [4, 7], [5, 7]
    ], 'green');
    drawCells([
      [7, 13], [7, 12], [7, 11], [7, 10], [7, 9]
    ], 'yellow');
    drawCells([
      [13, 7], [12, 7], [11, 7], [10, 7], [9, 7]
    ], 'blue');
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
      canvas.drawPath(path, Paint()..color = _color(name));
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

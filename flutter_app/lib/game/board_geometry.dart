import 'dart:ui';

/// Shared geometry for the 15x15 Ludo board.
/// Ring index 0..51 matches the painted track order.
/// Relative token positions: -1 = base, 0..51 = ring, 52..56 = home lane, 57 = home.
class BoardGeometry {
  BoardGeometry._();

  static const int gridSize = 15;

  static const List<String> colors = ['red', 'green', 'yellow', 'blue'];

  static const Map<String, int> startOffsets = {
    'red': 0,
    'green': 13,
    'yellow': 26,
    'blue': 39,
  };

  static const Set<int> safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  /// Track cells as [row, col], index == absolute ring position.
  static const List<List<int>> ringCells = [
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

  /// Base quadrant origins in cells.
  static const Map<String, Offset> baseOrigins = {
    'red': Offset(0, 0),
    'green': Offset(9, 0),
    'yellow': Offset(9, 9),
    'blue': Offset(0, 9),
  };

  /// Home lane cells (relative positions 52..56) per color.
  static const Map<String, List<List<int>>> laneCells = {
    'red': [
      [7, 1], [7, 2], [7, 3], [7, 4], [7, 5]
    ],
    'green': [
      [1, 7], [2, 7], [3, 7], [4, 7], [5, 7]
    ],
    'yellow': [
      [7, 13], [7, 12], [7, 11], [7, 10], [7, 9]
    ],
    'blue': [
      [13, 7], [12, 7], [11, 7], [10, 7], [9, 7]
    ],
  };

  static const Map<String, Offset> _homeNudge = {
    'red': Offset(-0.62, 0),
    'green': Offset(0, -0.62),
    'yellow': Offset(0.62, 0),
    'blue': Offset(0, 0.62),
  };

  static const List<Offset> _baseSlotOffsets = [
    Offset(2, 2),
    Offset(2, 4),
    Offset(4, 2),
    Offset(4, 4),
  ];

  /// Center point (in pixels) of where a token should sit.
  static Offset tokenCenter({
    required String color,
    required int pos,
    required int tokenIndex,
    required double cell,
  }) {
    if (pos < 0) {
      final o = baseOrigins[color]!;
      final s = _baseSlotOffsets[tokenIndex.clamp(0, 3)];
      return Offset((o.dx + s.dx) * cell, (o.dy + s.dy) * cell);
    }
    if (pos >= 52 && pos < 57) {
      final rc = laneCells[color]![pos - 52];
      return Offset((rc[1] + 0.5) * cell, (rc[0] + 0.5) * cell);
    }
    if (pos >= 57) {
      final n = _homeNudge[color]!;
      return Offset(
        (7.5 + n.dx) * cell,
        (7.5 + n.dy) * cell,
      );
    }
    final abs = absoluteSquare(color, pos);
    final rc = ringCells[abs];
    return Offset((rc[1] + 0.5) * cell, (rc[0] + 0.5) * cell);
  }

  static int absoluteSquare(String color, int relPos) {
    return (startOffsets[color]! + relPos) % 52;
  }
}

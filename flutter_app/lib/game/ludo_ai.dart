import 'dart:math';

import 'board_geometry.dart';
import 'ludo_engine.dart';

/// Heuristic CPU opponent: captures > finishing > leaving base >
/// safe landings > advancing the leading token.
class LudoAi {
  LudoAi._();

  static int chooseMove(
    Map<String, List<int>> allTokens,
    String color,
    int dice,
    List<int?> legalTargets,
  ) {
    final tokens = allTokens[color]!;
    final candidates = <int>[];
    for (var i = 0; i < legalTargets.length; i++) {
      if (legalTargets[i] != null) candidates.add(i);
    }
    if (candidates.isEmpty) return -1;
    if (candidates.length == 1) return candidates.first;

    var bestToken = candidates.first;
    var bestScore = -1.0;

    for (final index in candidates) {
      final from = tokens[index];
      final to = legalTargets[index]!;
      var score = 0.0;

      if (to == LudoEngine.homeDone) {
        score += 1000;
      } else if (to >= LudoEngine.laneStart) {
        score += 220 + to * 2;
      }

      if (from == LudoEngine.basePos) {
        score += 260;
      }

      final abs = to <= LudoEngine.trackEnd
          ? BoardGeometry.absoluteSquare(color, to)
          : -1;
      if (abs >= 0) {
        for (final entry in allTokens.entries) {
          if (entry.key == color) continue;
          final offset = BoardGeometry.startOffsets[entry.key]!;
          for (final p in entry.value) {
            if (p < 0 || p > LudoEngine.trackEnd) continue;
            if ((offset + p) % 52 == abs) {
              score += 520 + p.toDouble();
            }
          }
        }
        if (BoardGeometry.safeSquares.contains(abs)) score += 130;
      }

      // Avoid landing right in front of an enemy token (within 6 behind).
      if (abs >= 0 && !BoardGeometry.safeSquares.contains(abs)) {
        for (final entry in allTokens.entries) {
          if (entry.key == color) continue;
          final offset = BoardGeometry.startOffsets[entry.key]!;
          for (final p in entry.value) {
            if (p < 0 || p > LudoEngine.trackEnd) continue;
            final enemyAbs = (offset + p) % 52;
            final gap = (abs - enemyAbs + 52) % 52;
            if (gap >= 1 && gap <= 6) score -= (7 - gap) * 12.0;
          }
        }
      }

      score += to == 0 ? 10 : from.toDouble() * 0.5;
      score += _random.nextDouble() * 8;

      if (score > bestScore) {
        bestScore = score;
        bestToken = index;
      }
    }

    return bestToken;
  }

  static final Random _random = Random();
}

import 'board_geometry.dart';

/// Pure Ludo rules engine shared by local play and online state rendering.
class LudoEngine {
  LudoEngine._();

  static const int basePos = -1;
  static const int trackEnd = 51;
  static const int laneStart = 52;
  static const int homeDone = 57;

  static List<int> initialTokens() => [basePos, basePos, basePos, basePos];

  /// Target position per token index; null where the token cannot move.
  static List<int?> legalTargets(List<int> tokens, int dice) {
    final targets = List<int?>.filled(tokens.length, null);
    for (var i = 0; i < tokens.length; i++) {
      final pos = tokens[i];
      if (pos == homeDone) continue;
      if (pos == basePos) {
        if (dice == 6) targets[i] = 0;
        continue;
      }
      final target = pos + dice;
      if (target <= homeDone) targets[i] = target;
    }
    return targets;
  }

  static bool hasAnyMove(List<int> tokens, int dice) =>
      legalTargets(tokens, dice).any((t) => t != null);

  static MoveResult applyMove(
    Map<String, List<int>> allTokens,
    String color,
    int tokenIndex,
    int dice,
  ) {
    final tokens = allTokens[color]!;
    final current = tokens[tokenIndex];

    final target = current == basePos ? 0 : current + dice;
    if (target > homeDone) throw StateError('Move overshoots home');
    tokens[tokenIndex] = target;

    final capturedColors = <String>[];
    final victims = <CapturedToken>[];
    var captured = false;

    final abs = target <= trackEnd ? BoardGeometry.absoluteSquare(color, target) : -1;
    if (abs >= 0 && !BoardGeometry.safeSquares.contains(abs)) {
      for (final other in BoardGeometry.colors) {
        if (other == color || !allTokens.containsKey(other)) continue;
        final offset = BoardGeometry.startOffsets[other]!;
        final oppTokens = allTokens[other]!;
        for (var i = 0; i < oppTokens.length; i++) {
          final p = oppTokens[i];
          if (p < 0 || p > trackEnd) continue;
          if ((offset + p) % 52 == abs) {
            oppTokens[i] = basePos;
            captured = true;
            victims.add(CapturedToken(color: other, tokenIndex: i, fromPos: p));
            if (!capturedColors.contains(other)) capturedColors.add(other);
          }
        }
      }
    }

    return MoveResult(
      from: current,
      to: target,
      captured: captured,
      capturedColors: capturedColors,
      victims: victims,
      reachedHome: target == homeDone,
      finished: tokens.every((p) => p == homeDone),
    );
  }

  static bool isFinished(List<int> tokens) => tokens.every((p) => p == homeDone);

  /// Capture/finish resolution for a token that has ALREADY been moved
  /// (animated step by step) to [finalPos].
  static MoveResult resolveAfterMove(
    Map<String, List<int>> allTokens,
    String color,
    int finalPos,
  ) {
    final capturedColors = <String>[];
    final victims = <CapturedToken>[];
    var captured = false;

    final abs =
        finalPos <= trackEnd ? BoardGeometry.absoluteSquare(color, finalPos) : -1;
    if (abs >= 0 && !BoardGeometry.safeSquares.contains(abs)) {
      for (final other in BoardGeometry.colors) {
        if (other == color || !allTokens.containsKey(other)) continue;
        final offset = BoardGeometry.startOffsets[other]!;
        final oppTokens = allTokens[other]!;
        for (var i = 0; i < oppTokens.length; i++) {
          final p = oppTokens[i];
          if (p < 0 || p > trackEnd) continue;
          if ((offset + p) % 52 == abs) {
            oppTokens[i] = basePos;
            captured = true;
            victims.add(CapturedToken(color: other, tokenIndex: i, fromPos: p));
            if (!capturedColors.contains(other)) capturedColors.add(other);
          }
        }
      }
    }

    return MoveResult(
      from: -2,
      to: finalPos,
      captured: captured,
      capturedColors: capturedColors,
      victims: victims,
      reachedHome: finalPos == homeDone,
      finished: allTokens[color]!.every((p) => p == homeDone),
    );
  }

  static int tokensHome(List<int> tokens) =>
      tokens.where((p) => p == homeDone).length;

  static int progressOf(List<int> tokens) => tokens
      .where((p) => p != basePos)
      .fold(0, (sum, p) => sum + (p == homeDone ? trackEnd + 6 : p));

  static String nextColor(
    List<String> order,
    String current,
    Map<String, List<int>> tokens,
  ) {
    final index = order.indexOf(current);
    for (var step = 1; step <= order.length; step++) {
      final candidate = order[(index + step) % order.length];
      if (!isFinished(tokens[candidate]!)) return candidate;
    }
    return current;
  }
}

class CapturedToken {
  const CapturedToken({
    required this.color,
    required this.tokenIndex,
    required this.fromPos,
  });

  final String color;
  final int tokenIndex;

  /// Ring position the victim occupied when it was cut.
  final int fromPos;
}

/// Visual effect kinds for the presentation layer.
enum FxKind { flame, sparkle }

/// One board square where an effect should play.
class FxSpot {
  const FxSpot({
    required this.color,
    required this.tokenIndex,
    required this.pos,
  });

  final String color;
  final int tokenIndex;
  final int pos;
}

/// A numbered visual event (kill flames / home sparkles) for the UI.
class BoardFx {
  const BoardFx({required this.id, required this.kind, required this.spots});

  final int id;
  final FxKind kind;
  final List<FxSpot> spots;
}

class MoveResult {
  MoveResult({
    required this.from,
    required this.to,
    required this.captured,
    required this.capturedColors,
    this.victims = const [],
    required this.reachedHome,
    required this.finished,
  });

  final int from;
  final int to;
  final bool captured;
  final List<String> capturedColors;
  final List<CapturedToken> victims;
  final bool reachedHome;
  final bool finished;
}

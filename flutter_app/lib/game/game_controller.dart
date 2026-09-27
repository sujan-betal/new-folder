import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/sound/haptics.dart';
import '../core/sound/sound_manager.dart';
import 'board_geometry.dart';
import 'ludo_ai.dart';
import 'ludo_engine.dart';

enum GamePhase { awaitingRoll, rolling, choosingMove, moving, finished }

class Participant {
  Participant({
    required this.color,
    required this.name,
    required this.isCpu,
    this.avatar = '\u{1F3B2}',
  });

  final String color;
  final String name;
  final bool isCpu;
  final String avatar;
}

class GameController extends ChangeNotifier {
  GameController({required this.participants, this.onEvent})
      : _order = participants.map((p) => p.color).toList();

  final List<Participant> participants;
  final void Function(String message)? onEvent;
  final List<String> _order;

  final Random _random = Random();

  late Map<String, List<int>> tokens =
      {for (final p in participants) p.color: LudoEngine.initialTokens()};
  String _current = BoardGeometry.colors.first;
  int _currentIndex = 0;

  GamePhase phase = GamePhase.awaitingRoll;
  int? diceValue;
  Set<int> movable = {};
  String? winnerColor;
  BoardFx? boardFx;
  int _sixStreak = 0;
  int _generation = 0;
  int _fxSeq = 0;
  bool disposed = false;

  String get currentColor => _current;
  Participant get currentParticipant => participants[_currentIndex];
  bool get isHumanTurn =>
      phase != GamePhase.finished && !currentParticipant.isCpu;
  bool get canRoll => isHumanTurn && phase == GamePhase.awaitingRoll;

  Participant participantOf(String color) =>
      participants.firstWhere((p) => p.color == color);

  Future<void> start() async {
    _current = _order.first;
    _currentIndex = 0;
    await _maybeCpuTurn();
  }

  /// Tapping the dice always answers: if the roll is not allowed yet the
  /// player gets the "not yet" cue instead of silence.
  Future<void> roll() async {
    if (phase != GamePhase.awaitingRoll) {
      SoundManager.instance.invalid();
      Haptics.instance.error();
      return;
    }
    await _doRoll();
  }

  Future<void> _doRoll() async {
    final gen = ++_generation;
    phase = GamePhase.rolling;

    // Shake, then throw - the rattle lands right as the dice start tumbling.
    SoundManager.instance.diceThrow();
    Haptics.instance.medium();
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!_alive(gen)) return;
    SoundManager.instance.diceRoll();

    // Wait for the dice animation to settle (~1000ms total animation)
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!_alive(gen)) return;

    final value = _random.nextInt(6) + 1;
    diceValue = value;
    movable = {};

    final color = _current;
    final targets = LudoEngine.legalTargets(tokens[color]!, value);

    if (value == 6) {
      _sixStreak += 1;
      SoundManager.instance.six();
      Haptics.instance.success();
    } else {
      _sixStreak = 0;
    }

    if (_sixStreak >= 3) {
      _sixStreak = 0;
      SoundManager.instance.invalid();
      Haptics.instance.error();
      onEvent?.call('Three sixes in a row - turn skipped!');
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!_alive(gen)) return;
      await _passTurn(gen);
      return;
    }

    if (targets.every((t) => t == null)) {
      SoundManager.instance.invalid();
      Haptics.instance.error();
      onEvent?.call(
          '${_label(color)} rolled $value - no move available');
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!_alive(gen)) return;
      await _passTurn(gen);
      return;
    }

    movable = {
      for (var i = 0; i < targets.length; i++)
        if (targets[i] != null) i,
    };
    phase = GamePhase.choosingMove;
    notifyListeners();

    if (targets.where((t) => t != null).length == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (!_alive(gen)) return;
      await moveToken(movable.first);
      return;
    }

    if (currentParticipant.isCpu) {
      await Future<void>.delayed(const Duration(milliseconds: 620));
      if (!_alive(gen)) return;
      final choice = LudoAi.chooseMove(tokens, color, value, targets);
      if (choice >= 0) await moveToken(choice);
    }
  }

  Future<void> moveToken(int tokenIndex) async {
    if (phase != GamePhase.choosingMove || !movable.contains(tokenIndex)) {
      SoundManager.instance.invalid();
      Haptics.instance.error();
      return;
    }
    final gen = _generation;
    final color = _current;
    final value = diceValue!;

    phase = GamePhase.moving;
    movable = {};

    // ---- Ludo King style: hop cell by cell with a click each step. ----
    final start = tokens[color]![tokenIndex];
    final fromBase = start == LudoEngine.basePos;
    if (fromBase) {
      // Leaving the yard gets its own scoop-and-clack rather than a tock.
      SoundManager.instance.release();
      Haptics.instance.heavy();
    }
    var target = fromBase ? 0 : start + value;
    if (target > LudoEngine.homeDone) target = LudoEngine.homeDone;
    for (var pos = (fromBase ? -1 : start) + 1;
        pos <= target;
        pos++) {
      tokens[color]![tokenIndex] = pos;
      if (!fromBase || pos > 0) {
        SoundManager.instance.move();
        // Buzz once per move, not once per cell - a tick on every step would
        // turn a long roll into a buzzsaw.
        if (pos == (fromBase ? 1 : start + 1)) Haptics.instance.light();
      }
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 105));
      if (!_alive(gen)) return;
    }

    // Position already at target; apply captures / flags via the engine.
    final result = LudoEngine.resolveAfterMove(tokens, color, target);

    if (result.captured) {
      boardFx = BoardFx(
        id: ++_fxSeq,
        kind: FxKind.flame,
        spots: [
          for (final v in result.victims)
            FxSpot(color: v.color, tokenIndex: v.tokenIndex, pos: v.fromPos),
        ],
      );
    } else if (result.reachedHome) {
      boardFx = BoardFx(
        id: ++_fxSeq,
        kind: FxKind.sparkle,
        spots: [
          FxSpot(
              color: color, tokenIndex: tokenIndex, pos: LudoEngine.homeDone),
        ],
      );
    }
    notifyListeners();

    if (result.captured) {
      SoundManager.instance.capture();
      Haptics.instance.heavy();
      for (final victim in result.capturedColors) {
        onEvent?.call(
            '${_label(color)} captured ${_label(victim)}! Extra turn');
      }
    }
    if (result.reachedHome) {
      SoundManager.instance.home();
      Haptics.instance.success();
      onEvent?.call('${_label(color)} sent a token home! Extra turn');
    } else {
      final landedAbs =
          target <= LudoEngine.trackEnd
              ? BoardGeometry.absoluteSquare(color, target)
              : -1;
      if (landedAbs >= 0 && BoardGeometry.safeSquares.contains(landedAbs)) {
        SoundManager.instance.safe();
      }
    }

    if (!_alive(gen)) return;

    if (result.finished) {
      winnerColor ??= color;
      phase = GamePhase.finished;
      SoundManager.instance.win();
      Haptics.instance.success();
      notifyListeners();
      return;
    }

    final extra = value == 6 || result.captured || result.reachedHome;
    if (extra) {
      phase = GamePhase.awaitingRoll;
      diceValue = null;
      notifyListeners();
      await _maybeCpuTurn();
      return;
    }

    await _passTurn(gen);
  }

  Future<void> _passTurn(int gen) async {
    _sixStreak = 0;
    diceValue = null;
    _advanceToNextActive();
    phase = GamePhase.awaitingRoll;
    SoundManager.instance.turn();
    Haptics.instance.light();
    notifyListeners();
    await _maybeCpuTurn();
  }

  void _advanceToNextActive() {
    for (var step = 1; step <= participants.length; step++) {
      final nextIndex = (_currentIndex + step) % participants.length;
      final candidateColor = participants[nextIndex].color;
      if (!LudoEngine.isFinished(tokens[candidateColor]!)) {
        _currentIndex = nextIndex;
        _current = candidateColor;
        return;
      }
    }
  }

  Future<void> _maybeCpuTurn() async {
    if (phase != GamePhase.awaitingRoll || !currentParticipant.isCpu) return;
    final gen = _generation;
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!_alive(gen) || phase != GamePhase.awaitingRoll) return;
    await _doRoll();
  }

  bool _alive(int gen) => !disposed && gen == _generation;

  String _label(String color) =>
      color.isEmpty ? '?' : color[0].toUpperCase() + color.substring(1);

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

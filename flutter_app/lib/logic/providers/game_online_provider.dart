import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/realtime_client.dart';
import '../../core/sound/haptics.dart';
import '../../core/sound/sound_manager.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../game/ludo_engine.dart';
import 'auth_provider.dart';

class GameOnlineProvider extends ChangeNotifier {
  GameOnlineProvider(this._repository, this._auth, this._realtime);

  final GameRepository _repository;
  final AuthProvider _auth;
  final RealtimeClient _realtime;

  OnlineGameModel? game;
  bool busy = false;
  String? error;
  Set<int> movable = {};
  String? lastRollLabel;

  /// Board tokens. While a hop animation is in flight this holds the
  /// cell-by-cell intermediate position of the moving token(s); otherwise it
  /// mirrors `game.tokens`.
  Map<String, List<int>> displayTokens = {};

  BoardFx? boardFx;
  int _fxSeq = 0;
  Map<String, List<int>>? _prevTokens;

  Timer? _hopTimer;
  Timer? _fallsBackPoll;
  Timer? _rollClearTimer;
  final Set<String> _rollingColors = {};
  List<_Hop> _hops = [];

  static const List<String> colorOrder = ['red', 'green', 'yellow', 'blue'];

  static const int _hopIntervalMs = 125;

  int get myUserId => _auth.user?.id ?? -1;

  Map<String, dynamic>? get myParticipant {
    for (final p in game?.participants ?? const []) {
      if ((p['user_id'] as num?)?.toInt() == myUserId && p['is_bot'] != true) {
        return p;
      }
    }
    return null;
  }

  String? get myColor => myParticipant?['color'] as String?;

  bool get isMyTurn =>
      game != null && game!.isActive && game!.currentTurn == myColor;

  bool get canRoll =>
      isMyTurn && !busy && game?.diceValue == null && movable.isEmpty;

  /// Dice panel flag: while the die is still tumbling (recent roll).
  bool isRolling(String color) => _rollingColors.contains(color);

  Future<void> load(int gameId) async {
    error = null;
    _realtime.onData = _handleFrame;
    _realtime.connect('/api/v1/ws/game/$gameId');
    try {
      game = await _repository.get(gameId);
      displayTokens = _deepCopy(game!.tokens);
      _startFallbackPolling(gameId);
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  /// Safety net: if the socket silently fails, a slow poll keeps the game
  /// state converging so nobody gets stuck.
  void _startFallbackPolling(int gameId) {
    _fallsBackPoll?.cancel();
    _fallsBackPoll = Timer.periodic(const Duration(seconds: 6), (_) async {
      try {
        final fresh = await _repository.get(gameId);
        _applyServerState(fresh);
      } catch (_) {}
    });
  }

  Future<void> _handleFrame(String raw) async {
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      if (msg['kind'] != 'game' || msg['game'] == null) return;
      final fresh = OnlineGameModel.fromJson(
          Map<String, dynamic>.from(msg['game'] as Map));
      _applyServerState(fresh);
    } catch (_) {}
  }

  void _applyServerState(OnlineGameModel fresh) {
    final old = game;
    final hadPrevious = old != null;

    if (fresh.status == 'active') {
      final changed = fresh.currentTurn != old?.currentTurn ||
          fresh.diceValue != old?.diceValue ||
          fresh.tokens.toString() != old?.tokens.toString();
      if (!changed && !_hops.isNotEmpty) return;

      if (hadPrevious) {
        _animateMoves(displayTokens, fresh.tokens);
      } else {
        displayTokens = _deepCopy(fresh.tokens);
      }
      game = fresh;
      movable = {};
      _detectFx();

      // Remote roll: make the die visibly tumble for its owner.
      if (fresh.diceValue != null && (old?.diceValue == null || old == null)) {
        _markRolling(fresh.currentTurn);
      } else if (fresh.diceValue == null) {
        _rollingColors.clear();
      }

      if (fresh.currentTurn.toString().isNotEmpty &&
          fresh.diceValue == null &&
          fresh.currentTurn == myColor &&
          old?.currentTurn != myColor) {
        SoundManager.instance.turn();
      }
      notifyListeners();
    } else {
      game = fresh;
      displayTokens = _deepCopy(fresh.tokens);
      _detectFx();
      movable = {};
      _rollingColors.clear();
      notifyListeners();
      _notifyFinishedOnce();
    }
  }

  void _markRolling(String color) {
    _rollingColors
      ..clear()
      ..add(color);
    _rollClearTimer?.cancel();
    _rollClearTimer = Timer(const Duration(milliseconds: 950), () {
      _rollingColors.clear();
      notifyListeners();
    });
  }

  // --------------------------------------------------------------------
  // Hop animation: a moved token glides over the intermediate cells, the
  // Ludo King signature motion, for BOTH local and remote players.
  // --------------------------------------------------------------------
  void _animateMoves(
      Map<String, List<int>> current, Map<String, List<int>> target) {
    _hopTimer?.cancel();
    _hops = [];

    final hops = <_Hop>[];
    for (final color in target.keys) {
      final before = current[color] ?? LudoEngine.initialTokens();
      final after = target[color]!;
      for (var i = 0; i < after.length && i < before.length; i++) {
        final b = before[i];
        final a = after[i];
        if (b == a) continue;
        if (b == LudoEngine.basePos) {
          // Popping out of base onto the start square.
          hops.add(_Hop(color, i, [0], fromBase: true));
        } else if (a > b && a - b <= 6) {
          hops.add(_Hop(color, i, List<int>.generate(a - b, (k) => b + 1 + k)));
        }
        // else: capture/return-to-base is not hop-animated; the flame fx at
        // the victim square sells the jump instantly (like Ludo King).
      }
    }

    if (hops.isEmpty) {
      displayTokens = _deepCopy(target);
      return;
    }

    // Audible hop click for *other* people's moves (own moves sound via
    // moveToken); this is the Ludo King cell-by-cell tick.
    if (hops.any((h) => h.color != myColor)) {
      SoundManager.instance.move();
    }

    // Start from wherever the board is right now.
    displayTokens = _deepCopy(current);
    _hops = hops;

    // Gentle tick - each hop advances one cell per tick.
    _hopTimer = Timer.periodic(
        Duration(milliseconds: _hopIntervalMs), (_) => _tickHops(hops));
    notifyListeners();
  }

  void _tickHops(List<_Hop> hops) {
    if (game == null) {
      _hopTimer?.cancel();
      return;
    }
    final display = _deepCopy(game!.tokens);
    var anyActive = false;
    for (final h in hops) {
      if (h.done) continue;
      h.step += 1;
      final cell = h.path[h.step.clamp(0, h.path.length - 1)];
      display[h.color]![h.tokenIndex] = cell;
      h.done = h.step >= h.path.length;
      anyActive = true;
    }
    displayTokens = display;
    if (!anyActive) {
      _hopTimer?.cancel();
      displayTokens = _deepCopy(game!.tokens);
      _rollingColors.clear();
    }
    notifyListeners();
  }

  /// Detects kills / home entries by diffing the previous token snapshot.
  void _detectFx() {
    final g = game;
    if (g == null) return;
    final prev = _prevTokens;
    _prevTokens = {
      for (final e in g.tokens.entries) e.key: List<int>.of(e.value),
    };
    if (prev == null) return;

    final fire = <FxSpot>[];
    final sparkle = <FxSpot>[];
    var released = false;
    var reachedHome = false;
    prev.forEach((color, before) {
      final after = g.tokens[color];
      if (after == null) return;
      for (var i = 0; i < before.length && i < after.length; i++) {
        final was = before[i];
        final now = after[i];
        if (was >= 0 &&
            was <= LudoEngine.trackEnd &&
            now == LudoEngine.basePos) {
          fire.add(FxSpot(color: color, tokenIndex: i, pos: was));
        } else if (was == LudoEngine.basePos && now >= 0) {
          released = true;
        } else if (was != LudoEngine.homeDone && now == LudoEngine.homeDone) {
          sparkle.add(
              FxSpot(color: color, tokenIndex: i, pos: LudoEngine.homeDone));
          reachedHome = true;
        }
      }
    });

    if (fire.isNotEmpty) {
      boardFx = BoardFx(id: ++_fxSeq, kind: FxKind.flame, spots: fire);
      if ((fire.first.color) != myColor) SoundManager.instance.capture();
      Haptics.instance.heavy();
    } else if (sparkle.isNotEmpty) {
      boardFx = BoardFx(id: ++_fxSeq, kind: FxKind.sparkle, spots: sparkle);
      if ((sparkle.first.color) != myColor) SoundManager.instance.home();
    }
    if (released) SoundManager.instance.release();
    if (reachedHome) {
      SoundManager.instance.home();
      Haptics.instance.success();
    }
  }

  bool _finishedNotified = false;
  VoidCallback? onFinished;

  void _notifyFinishedOnce() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    _fallsBackPoll?.cancel();
    _realtime.disconnect();
    if (game?.winnerId != null && game!.winnerId == myUserId) {
      SoundManager.instance.win();
    } else {
      SoundManager.instance.lose();
    }
    onFinished?.call();
  }

  Future<void> rollDice() async {
    if (!canRoll || game == null) {
      SoundManager.instance.invalid();
      Haptics.instance.error();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      SoundManager.instance.diceThrow();
      await Future<void>.delayed(const Duration(milliseconds: 130));
      await _repository.roll(game!.id);
      game = await _repository.get(game!.id);
      displayTokens = _deepCopy(game!.tokens);
      _detectFx();
      _markRolling(myColor ?? '');
      SoundManager.instance.diceRoll();
      Haptics.instance.medium();
      final color = myColor;
      lastRollLabel =
          '${_capitalize(color ?? '')} rolled ${game!.diceValue ?? '?'}';
      if (game!.diceValue == 6) {
        SoundManager.instance.six();
        Haptics.instance.success();
      }
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> moveToken(int tokenIndex) async {
    final allowed = computeMovableForMe();
    if (game == null || busy || !allowed.contains(tokenIndex)) {
      SoundManager.instance.invalid();
      Haptics.instance.error();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _repository.move(game!.id, tokenIndex);
      game = await _repository.get(game!.id);
      _detectFx();
      SoundManager.instance.move();
      Haptics.instance.light();
      movable = {};
      displayTokens = _deepCopy(game!.tokens);
      if (!game!.isActive) _notifyFinishedOnce();
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Legal target indices for my color given the current server dice.
  Set<int> computeMovableForMe() {
    final g = game;
    final color = myColor;
    if (g == null || color == null || !isMyTurn || g.diceValue == null) {
      return {};
    }
    final tokens = g.tokens[color] ?? LudoEngine.initialTokens();
    final targets = LudoEngine.legalTargets(tokens, g.diceValue!);
    return {
      for (var i = 0; i < targets.length; i++)
        if (targets[i] != null) i,
    };
  }

  /// Convenience for UI: current movable set (recomputed from server state).
  Set<int> get movableForMe => computeMovableForMe();

  Map<String, dynamic>? participantOf(String color) {
    for (final p in game?.participants ?? const []) {
      if ((p['color'] ?? '') == color) return p;
    }
    return null;
  }

  String nameOf(String color) {
    final p = participantOf(color);
    if (p == null) return _capitalize(color);
    if (p['is_bot'] == true) return 'CPU';
    final username = (p['username'] ?? '').toString();
    if (username.isEmpty) return _capitalize(color);
    final id = (p['user_id'] as num?)?.toInt();
    return id == myUserId ? '$username (You)' : username;
  }

  String avatarOf(String color) {
    final p = participantOf(color);
    final avatar = p == null ? '' : (p['avatar'] ?? '').toString();
    return avatar.isEmpty ? '\u{1F3B2}' : avatar;
  }

  List<String> get activeColors {
    final colors = game?.tokens.keys.toList() ?? [];
    colors
        .sort((a, b) => colorOrder.indexOf(a).compareTo(colorOrder.indexOf(b)));
    return colors;
  }

  int tokensHomeOf(String color) =>
      LudoEngine.tokensHome(game?.tokens[color] ?? const []);

  Map<String, List<int>> _deepCopy(Map<String, List<int>> src) => {
        for (final e in src.entries) e.key: List<int>.of(e.value),
      };

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  void dispose() {
    _hopTimer?.cancel();
    _fallsBackPoll?.cancel();
    _rollClearTimer?.cancel();
    _realtime.disconnect();
    super.dispose();
  }
}

class _Hop {
  _Hop(this.color, this.tokenIndex, this.path, {this.fromBase = false});

  final String color;
  final int tokenIndex;
  final List<int> path;
  final bool fromBase;
  int step = -1;
  bool done = false;
}

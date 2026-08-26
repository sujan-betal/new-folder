import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/sound/sound_manager.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../game/ludo_engine.dart';
import 'auth_provider.dart';

class GameOnlineProvider extends ChangeNotifier {
  GameOnlineProvider(this._repository, this._auth);

  final GameRepository _repository;
  final AuthProvider _auth;

  OnlineGameModel? game;
  bool busy = false;
  String? error;
  Set<int> movable = {};
  String? lastRollLabel;

  Timer? _pollTimer;
  bool _polling = false;
  bool _finishedNotified = false;
  VoidCallback? onFinished;

  BoardFx? boardFx;
  int _fxSeq = 0;
  Map<String, List<int>>? _prevTokens;

  static const List<String> colorOrder = ['red', 'green', 'yellow', 'blue'];

  int get myUserId => _auth.user?.id ?? -1;

  Map<String, dynamic>? get myParticipant {
    for (final p in game?.participants ?? const []) {
      if ((p['user_id'] as num?)?.toInt() == myUserId &&
          p['is_bot'] != true) {
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

  Future<void> load(int gameId) async {
    error = null;
    try {
      game = await _repository.get(gameId);
      movable = {};
      _startPolling();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) async {
      if (_polling || busy || game == null || !game!.isActive) return;
      _polling = true;
      try {
        final fresh = await _repository.get(game!.id);
        if (fresh.status == 'active') {
          final changed = fresh.currentTurn != game!.currentTurn ||
              fresh.diceValue != game!.diceValue ||
              fresh.tokens.toString() != game!.tokens.toString();
          if (changed) {
            // Your-turn ding like Ludo King.
            if (fresh.currentTurn == myColor && fresh.diceValue == null) {
              SoundManager.instance.turn();
            }
            game = fresh;
            _detectFx();
            movable = {};
            notifyListeners();
          }
        } else {
          game = fresh;
          _detectFx();
          movable = {};
          notifyListeners();
          _notifyFinishedOnce();
        }
      } catch (_) {
        // Transient network errors are ignored while polling.
      } finally {
        _polling = false;
      }
    });
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
        } else if (was != LudoEngine.homeDone &&
            now == LudoEngine.homeDone) {
          sparkle.add(
              FxSpot(color: color, tokenIndex: i, pos: LudoEngine.homeDone));
        }
      }
    });

    if (fire.isNotEmpty) {
      boardFx = BoardFx(id: ++_fxSeq, kind: FxKind.flame, spots: fire);
    } else if (sparkle.isNotEmpty) {
      boardFx = BoardFx(id: ++_fxSeq, kind: FxKind.sparkle, spots: sparkle);
    }
  }

  void _notifyFinishedOnce() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    _pollTimer?.cancel();
    if (game?.winnerId != null && game!.winnerId == myUserId) {
      SoundManager.instance.win();
    }
    onFinished?.call();
  }

  Future<void> rollDice() async {
    if (!canRoll || game == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _repository.roll(game!.id);
      game = await _repository.get(game!.id);
      _detectFx();
      SoundManager.instance.diceRoll();
      final color = myColor;
      lastRollLabel =
          '${_capitalize(color ?? '')} rolled ${game!.diceValue ?? '?'}';
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> moveToken(int tokenIndex) async {
    final allowed = computeMovableForMe();
    if (game == null || busy || !allowed.contains(tokenIndex)) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _repository.move(game!.id, tokenIndex);
      game = await _repository.get(game!.id);
      _detectFx();
      SoundManager.instance.move();
      movable = {};
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
    colors.sort(
        (a, b) => colorOrder.indexOf(a).compareTo(colorOrder.indexOf(b)));
    return colors;
  }

  int tokensHomeOf(String color) =>
      LudoEngine.tokensHome(game?.tokens[color] ?? const []);

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

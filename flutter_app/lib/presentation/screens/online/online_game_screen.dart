import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../../../injection_container.dart' as di;
import '../../../logic/providers/auth_provider.dart';
import '../../../logic/providers/game_online_provider.dart';
import '../../widgets/board_painter.dart';
import '../../widgets/board_view.dart';
import '../../widgets/player_dice_panel.dart';
import '../../widgets/sound_toggle.dart';
import '../game/local_game_screen.dart' show PrimaryGameButton;

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key, required this.gameId});

  final int gameId;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late final GameOnlineProvider _provider;
  bool _showingResult = false;

  // Ludo King style turn countdown: resets on every state change.
  static const int _turnSeconds = 15;
  int _secondsLeft = _turnSeconds;
  Timer? _tickTimer;
  String? _timerKey;

  @override
  void initState() {
    super.initState();
    _provider = di.sl<GameOnlineProvider>();
    _provider.onFinished = _presentResult;
    _provider.addListener(_onGameChanged);
    _provider.load(widget.gameId);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _provider
      ..removeListener(_onGameChanged)
      ..dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (!mounted) return;
    final game = _provider.game;
    if (game == null) return;

    final key =
        '${game.id}|${game.currentTurn}|${game.diceValue ?? '-'}|${game.status}';
    if (key == _timerKey) return;
    _timerKey = key;

    if (game.isActive && game.diceValue == null) {
      setState(() => _secondsLeft = _turnSeconds);
      _tickTimer?.cancel();
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        if (_secondsLeft <= 1) {
          _tickTimer?.cancel();
          // Timeout: auto-roll for the player, exactly like Ludo King.
          if (_provider.canRoll) await _provider.rollDice();
          return;
        }
        setState(() => _secondsLeft -= 1);
      });
    } else {
      _tickTimer?.cancel();
    }
  }

  Future<void> _presentResult() async {
    if (!mounted || _showingResult) return;
    _showingResult = true;
    final game = _provider.game;
    if (game == null) return;

    final iWon = game.winnerId != null && game.winnerId == _provider.myUserId;

    // Refresh profile so coins/XP reflect the finished match.
    try {
      await context.read<AuthProvider>().bootstrap();
    } catch (_) {}

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.navyLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(iWon ? '\u{1F3C6}' : '\u{1F91A}',
                  style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 10),
              Text(
                iWon ? 'Victory!' : 'Game over',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: iWon ? AppColors.gold : Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Winner: ${_provider.nameOf(_colorOfWinner(game))}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 20),
              PrimaryGameButton(
                label: 'Back to menu',
                onTap: () {
                  Navigator.of(context)
                    ..pop()
                    ..pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _colorOfWinner(OnlineGameModel game) {
    for (final p in game.participants) {
      if ((p['user_id'] as num?)?.toInt() == game.winnerId) {
        return (p['color'] ?? 'red').toString();
      }
    }
    return 'red';
  }

  /// One board-edge slot; renders that colour's own dice panel if seated.
  Widget _cornerSlot(GameOnlineProvider provider, String color,
      {required bool alignRight}) {
    final game = provider.game;
    if (game == null || !provider.activeColors.contains(color)) {
      return const SizedBox.expand();
    }
    final active = game.currentTurn == color;
    final waiting = game.diceValue == null;
    return Align(
      alignment:
          alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: PlayerDicePanel(
        colorName: color,
        name: provider.nameOf(color),
        avatar: provider.avatarOf(color),
        tokensHome: provider.tokensHomeOf(color),
        active: active,
        glowing: active && waiting && !provider.busy,
        diceValue: game.diceValue ?? 1,
        rolling: active && waiting && provider.busy,
        canRoll: provider.canRoll && color == provider.myColor,
        onRollTap: provider.rollDice,
      ),
    );
  }

  Widget _cornerRow(GameOnlineProvider provider,
      {required String left, required String right}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: SizedBox(
        height: 78,
        child: Row(
          children: [
            Expanded(child: _cornerSlot(provider, left, alignRight: false)),
            Expanded(child: _cornerSlot(provider, right, alignRight: true)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<GameOnlineProvider>(
        builder: (context, provider, _) {
          final game = provider.game;

          return Scaffold(
            body: Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.backgroundGradient),
              child: SafeArea(
                child: game == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: AppColors.gold),
                            const SizedBox(height: 12),
                            Text(provider.error ?? 'Loading game...',
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back_ios_new,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Room ${game.id} - ${game.status}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (game.isActive && game.diceValue == null)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _secondsLeft <= 5
                                          ? Colors.red.withValues(alpha: 0.25)
                                          : Colors.black26,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _secondsLeft <= 5
                                            ? Colors.redAccent
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Text(
                                      '\u23F1 ${_secondsLeft}s',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _secondsLeft <= 5
                                            ? Colors.redAccent
                                            : Colors.white70,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                const SoundToggle(),
                                Text(
                                  'You: ${provider.myColor ?? '-'}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: provider.myColor == null
                                          ? Colors.white54
                                          : BoardPainter.colorOf(
                                              provider.myColor!)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                // Ludo King layout: each player's own dice
                                // beside their base corner of the board.
                                _cornerRow(provider,
                                    left: 'red', right: 'green'),
                                Expanded(
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: BoardView(
                                          tokens: game.tokens,
                                          currentColor: game.currentTurn,
                                          movable: provider.movableForMe,
                                          boardFx: provider.boardFx,
                                          onTokenTap: (_, index) =>
                                              provider.moveToken(index),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _cornerRow(provider,
                                    left: 'blue', right: 'yellow'),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

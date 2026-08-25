import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../../../injection_container.dart' as di;
import '../../../logic/providers/auth_provider.dart';
import '../../../logic/providers/game_online_provider.dart';
import '../../widgets/board_painter.dart';
import '../../widgets/board_view.dart';
import '../../widgets/dice_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _provider = di.sl<GameOnlineProvider>();
    _provider.onFinished = _presentResult;
    _provider.load(widget.gameId);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
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

  Widget _participantStrip(GameOnlineProvider provider) {
    final colors = provider.activeColors;
    if (colors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Row(
        children: [
          for (var i = 0; i < colors.length; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding:
                    const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
                decoration: BoxDecoration(
                  color: provider.game?.currentTurn == colors[i]
                      ? BoardPainter.colorOf(colors[i]).withValues(alpha: 0.35)
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: provider.game?.currentTurn == colors[i]
                        ? AppColors.gold
                        : Colors.white24,
                    width: provider.game?.currentTurn == colors[i] ? 1.8 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: BoardPainter.colorOf(colors[i]),
                      child: Text(provider.avatarOf(colors[i]),
                          style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.nameOf(colors[i]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '\u{1F3E0} ${provider.tokensHomeOf(colors[i])}/4',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
          final turnColor = game == null
              ? Colors.white
              : BoardPainter.colorOf(game.currentTurn);

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
                            flex: 6,
                            child: Column(
                              children: [
                                _participantStrip(provider),
                                Expanded(
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: BoardView(
                                          tokens: game.tokens,
                                          currentColor: game.currentTurn,
                                          movable: provider.movableForMe,
                                          onTokenTap: (_, index) =>
                                              provider.moveToken(index),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(18, 6, 18, 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DiceWidget(
                                  value: game.diceValue ?? 1,
                                  rolling: false,
                                  color: turnColor,
                                  size: 68,
                                  enabled: provider.canRoll,
                                  onTap: provider.rollDice,
                                ),
                                const SizedBox(width: 18),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      provider.busy
                                          ? 'Syncing...'
                                          : provider.isMyTurn
                                              ? (game.diceValue == null
                                                  ? 'Your turn - roll!'
                                                  : 'Pick a token to move')
                                              : '${provider.nameOf(game.currentTurn)}\'s turn',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 6),
                                    PrimaryGameButton(
                                      label: provider.canRoll
                                          ? 'ROLL'
                                          : 'WAIT',
                                      width: 120,
                                      enabled: provider.canRoll,
                                      onTap: provider.rollDice,
                                    ),
                                  ],
                                ),
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

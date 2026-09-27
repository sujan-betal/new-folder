import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/sound/haptics.dart';
import '../../../core/sound/sound_manager.dart';
import '../../../data/models/room_model.dart';
import '../../../game/ludo_engine.dart';
import '../../../injection_container.dart' as di;
import '../../../logic/providers/auth_provider.dart';
import '../../../logic/providers/game_online_provider.dart';
import '../../widgets/board_painter.dart';
import '../../widgets/board_view.dart';
import '../../widgets/dice_dock.dart';
import '../../widgets/game_background.dart';
import '../../widgets/game_banner.dart';
import '../../widgets/player_strip.dart';
import '../../widgets/sound_toggle.dart';
import '../../widgets/victory_overlay.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key, required this.gameId});

  final int gameId;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final GlobalKey<BannerHostState> _banners = GlobalKey<BannerHostState>();

  late final GameOnlineProvider _provider;
  bool _showingResult = false;
  bool _iWon = false;
  Color _winnerColor = Colors.white;
  String _winnerName = '';
  List<(String, Color)> _standings = const [];

  // Turn countdown: resets on every state change.
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
          // Timeout: auto-roll for the player.
          if (_provider.canRoll) await _provider.rollDice();
          return;
        }
        setState(() => _secondsLeft -= 1);
        // Urgency ticks over the last three seconds.
        if (_secondsLeft <= 3) {
          SoundManager.instance.countdown();
          Haptics.instance.light();
        }
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

    final standings = <(String, Color)>[];
    for (final p in game.participants) {
      standings.add((
        _provider.nameOf(p['color']?.toString() ?? 'red'),
        BoardPainter.colorOf(p['color']?.toString() ?? 'red'),
      ));
    }

    Haptics.instance.success();
    setState(() {
      _standings = standings;
      _iWon = iWon;
      _winnerColor = BoardPainter.colorOf(_colorOfWinner(game));
      _winnerName = _provider.nameOf(_colorOfWinner(game));
    });
  }

  String _colorOfWinner(OnlineGameModel game) {
    for (final p in game.participants) {
      if ((p['user_id'] as num?)?.toInt() == game.winnerId) {
        return (p['color'] ?? 'red').toString();
      }
    }
    return 'red';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<GameOnlineProvider>(
        builder: (context, provider, _) {
          final game = provider.game;

          return BannerHost(
            key: _banners,
            child: Stack(
              children: [
                Scaffold(
                  body: GameBackground(
                    glow: BoardPainter.colorOf(game?.currentTurn ?? 'red'),
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
                          : _board(provider, game),
                    ),
                  ),
                ),
                if (_showingResult)
                  Positioned.fill(
                    child: VictoryOverlay(
                      winnerName: _winnerName,
                      winnerColor: _winnerColor,
                      standings: _standings,
                      iWon: _iWon,
                      rewardLabel: _iWon ? '+50 coins' : '+10 coins',
                      onHome: () {
                        SoundManager.instance.tap();
                        Navigator.of(context)
                          ..pop()
                          ..pop();
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _board(GameOnlineProvider provider, OnlineGameModel game) {
    final current = game.currentTurn;
    final isMe = current == provider.myColor;
    final waiting = game.diceValue == null;

    final prompt = !isMe
        ? DicePrompt.waiting
        : (waiting ? DicePrompt.roll : DicePrompt.pickToken);

    final movable = provider.movableForMe;
    final landings = isMe && !waiting && game.diceValue != null
        ? LudoEngine.landingPositions(game.tokens[current]!, game.diceValue!)
        : const <int>{};

    return Column(
      children: [
        _header(game),
        PlayerStrip(
          children: [
            for (final color in provider.activeColors)
              PlayerChip(
                colorName: color,
                name: provider.nameOf(color),
                avatar: provider.avatarOf(color),
                tokensHome: provider.tokensHomeOf(color),
                active: current == color,
                isMe: color == provider.myColor,
              ),
          ],
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AspectRatio(
                aspectRatio: 1,
                child: BoardView(
                  tokens: game.tokens,
                  currentColor: current,
                  movable: movable,
                  landings: landings,
                  boardFx: provider.boardFx,
                  onTokenTap: (_, index) => provider.moveToken(index),
                ),
              ),
            ),
          ),
        ),
        DiceDock(
          colorName: current,
          name: provider.nameOf(current),
          avatar: provider.avatarOf(current),
          prompt: prompt,
          diceValue: game.diceValue ?? 1,
          rolling: isMe && waiting && provider.busy,
          onRollTap: provider.rollDice,
          trailing: game.isActive && waiting ? _timerChip() : null,
        ),
      ],
    );
  }

  Widget _header(OnlineGameModel game) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
          ),
          Expanded(
            child: Text(
              'Room ${game.id}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
          const SoundToggle(),
        ],
      ),
    );
  }

  Widget _timerChip() {
    final urgent = _secondsLeft <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: urgent
            ? AppColors.red.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: urgent ? Colors.redAccent : Colors.white24, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
              size: 14, color: urgent ? Colors.redAccent : Colors.white70),
          const SizedBox(width: 4),
          Text(
            '$_secondsLeft',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: urgent ? Colors.redAccent : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

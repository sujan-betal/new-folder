import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/sound/haptics.dart';
import '../../../core/sound/sound_manager.dart';
import '../../../game/game_controller.dart';
import '../../../game/board_geometry.dart';
import '../../../game/ludo_engine.dart';
import '../../widgets/board_painter.dart';
import '../../widgets/board_view.dart';
import '../../widgets/player_dock.dart';
import '../../widgets/game_background.dart';
import '../../widgets/game_banner.dart';
import '../../widgets/sound_toggle.dart';
import '../../widgets/victory_overlay.dart';

class LocalGameScreen extends StatefulWidget {
  const LocalGameScreen({super.key, required this.participants});

  final List<Participant> participants;

  @override
  State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<BannerHostState> _banners = GlobalKey<BannerHostState>();

  late final GameController _controller;
  bool _showingWinner = false;
  int? _lastFxId;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      participants: widget.participants,
      onEvent: _onEvent,
    )..addListener(_onChanged);
    _controller.start();
  }

  @override
  void dispose() {
    _shake.dispose();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Participant? _participantOf(String color) {
    for (final p in _controller.participants) {
      if (p.color == color) return p;
    }
    return null;
  }

  /// Controller events become loud, colourful banners instead of a grey
  /// snackbar - this is the difference between "something happened" and
  /// "you just cut Red".
  void _onEvent(String message) {
    if (!mounted) return;
    final lower = message.toLowerCase();
    if (lower.contains('captured')) {
      _banners.currentState?.show(
        'KILL!',
        subtitle: message,
        color: AppColors.red,
        icon: Icons.local_fire_department_rounded,
      );
    } else if (lower.contains('sent a token home')) {
      _banners.currentState?.show(
        'HOME!',
        subtitle: message,
        color: AppColors.gold,
        icon: Icons.emoji_events_rounded,
      );
    } else if (lower.contains('three sixes')) {
      _banners.currentState?.show(
        'NO TURNS!',
        subtitle: message,
        color: const Color(0xFF6D4C41),
        icon: Icons.block_rounded,
      );
    } else if (lower.contains('no move')) {
      _banners.currentState?.show(
        'NO MOVE',
        subtitle: message,
        color: const Color(0xFF546E7A),
        icon: Icons.do_not_disturb_on_rounded,
      );
    }
  }

  void _reactToFx() {
    final fx = _controller.boardFx;
    if (fx == null || fx.id == _lastFxId) return;
    _lastFxId = fx.id;
    if (fx.kind == FxKind.flame) {
      Haptics.instance.heavy();
      _shake.forward(from: 0);
    } else {
      Haptics.instance.light();
    }
  }

  void _onChanged() {
    if (_controller.phase == GamePhase.finished && !_showingWinner && mounted) {
      _showingWinner = true;
      Haptics.instance.success();
      setState(() {});
    }
  }

  /// Final standings like Ludo King: rank everyone by track progress.
  List<(String, Color)> _standings() {
    final ranked = _controller.participants
        .map((p) =>
            MapEntry(p, LudoEngine.progressOf(_controller.tokens[p.color]!)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in ranked) (e.key.name, BoardPainter.colorOf(e.key.color)),
    ];
  }

  void _restart() {
    setState(() => _showingWinner = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LocalGameScreen(participants: widget.participants),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BannerHost(
      key: _banners,
      child: Stack(
        children: [
          Scaffold(
            body: GameBackground(
              glow: BoardPainter.colorOf(_controller.currentColor),
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _body(),
                ),
              ),
            ),
          ),
          if (_showingWinner) _victory(),
        ],
      ),
    );
  }

  Widget _body() {
    final controller = _controller;
    _reactToFx();

    final dice = controller.diceValue;
    final landings = controller.phase == GamePhase.choosingMove && dice != null
        ? LudoEngine.landingPositions(
            controller.tokens[controller.currentColor]!, dice)
        : const <int>{};

    final labels = {
      for (final p in controller.participants) p.color: p.name,
    };

    // Every seat keeps its own die, parked in the corner of its own base.
    // Top-row players dock above the board, bottom-row players below it.
    Widget dockFor(String color) {
      final p = _participantOf(color);
      if (p == null) return const SizedBox.shrink();
      final prompt = controller.currentColor != color
          ? DicePrompt.waiting
          : switch (controller.phase) {
              GamePhase.choosingMove ||
              GamePhase.moving =>
                DicePrompt.pickToken,
              _ => DicePrompt.roll,
            };
      return PlayerDock(
        colorName: p.color,
        name: p.name,
        avatar: p.avatar,
        tokensHome: LudoEngine.tokensHome(controller.tokens[p.color]!),
        diceValue: controller.diceValue ?? 1,
        rolling: controller.currentColor == p.color &&
            controller.phase == GamePhase.rolling,
        prompt: prompt,
        onRollTap: controller.roll,
        // Right-hand bases read pin-then-die, left-hand bases die-then-pin.
        pinFirst: BoardGeometry.baseOrigins[p.color]!.dx >= 4,
      );
    }

    Widget dockRow({required String left, required String right}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft, child: dockFor(left))),
            Expanded(
                child: Align(
                    alignment: Alignment.centerRight, child: dockFor(right))),
          ],
        ),
      );
    }

    return Column(
      children: [
        _header(),
        dockRow(left: 'red', right: 'green'),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    final t = _shake.value;
                    final dx = math.sin(t * math.pi * 6) * 7 * (1 - t);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: BoardView(
                    tokens: controller.tokens,
                    currentColor: controller.currentColor,
                    movable: controller.movable,
                    landings: landings,
                    labels: labels,
                    boardFx: controller.boardFx,
                    onTokenTap: (color, index) => controller.moveToken(index),
                  ),
                ),
              ),
            ),
          ),
        ),
        dockRow(left: 'blue', right: 'yellow'),
      ],
    );
  }

  Widget _victory() {
    final winnerColor = _controller.winnerColor!;
    final winner = _controller.participantOf(winnerColor);
    final iWon = !winner.isCpu;
    return Positioned.fill(
      child: VictoryOverlay(
        winnerName: winner.name,
        winnerColor: BoardPainter.colorOf(winnerColor),
        standings: _standings(),
        iWon: iWon,
        rewardLabel: iWon ? '+50 coins' : '+10 coins',
        onPlayAgain: () {
          SoundManager.instance.tap();
          _restart();
        },
        onHome: () {
          SoundManager.instance.tap();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _header() {
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
              widget.participants.any((p) => p.isCpu)
                  ? 'You vs Computer'
                  : 'Pass & Play',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
          const SoundToggle(),
          IconButton(
            tooltip: 'Restart',
            onPressed: _confirmRestart,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.gold, size: 21),
          ),
        ],
      ),
    );
  }

  void _confirmRestart() {
    SoundManager.instance.tap();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.navyLight,
        title: const Text('Restart game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restart();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}

class PrimaryGameButton extends StatelessWidget {
  const PrimaryGameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.width,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled
            ? () {
                SoundManager.instance.tap();
                Haptics.instance.medium();
                onTap?.call();
              }
            : null,
        child: Container(
          width: width,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: AppColors.goldDark.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFF4A2C00),
            ),
          ),
        ),
      ),
    );
  }
}

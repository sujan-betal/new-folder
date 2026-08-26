import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../game/game_controller.dart';
import '../../../game/ludo_engine.dart';
import '../../widgets/board_view.dart';
import '../../widgets/board_painter.dart';
import '../../widgets/player_dice_panel.dart';
import '../../widgets/sound_toggle.dart';

class LocalGameScreen extends StatefulWidget {
  const LocalGameScreen({super.key, required this.participants});

  final List<Participant> participants;

  @override
  State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen>
    with SingleTickerProviderStateMixin {
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
      onEvent: _showToast,
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

  void _reactToFx() {
    final fx = _controller.boardFx;
    if (fx == null || fx.id == _lastFxId) return;
    _lastFxId = fx.id;
    if (fx.kind == FxKind.flame) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _onChanged() {
    if (_controller.phase == GamePhase.finished &&
        !_showingWinner &&
        mounted) {
      _showingWinner = true;
      HapticFeedback.mediumImpact();
      _showWinnerDialog();
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          content: Text(message),
        ),
      );
  }

  Future<void> _showWinnerDialog() async {
    final winner = _controller.participantOf(_controller.winnerColor!);

    // Final standings like Ludo King: rank everyone by track progress.
    final standings = _controller.participants
        .map((p) => MapEntry(p, LudoEngine.progressOf(_controller.tokens[p.color]!)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const medals = ['\u{1F947}', '\u{1F948}', '\u{1F949}', '4\uFE0F\u20E3'];

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
              const Text('\u{1F3C6}', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 10),
              Text(
                '${winner.name} wins!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < standings.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(medals[i], style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              BoardPainter.colorOf(standings[i].key.color),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          standings[i].key.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              PrimaryGameButton(
                label: 'Play Again',
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _showingWinner = false);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          LocalGameScreen(participants: widget.participants),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                    ..pop()
                    ..pop();
                },
                child: const Text(
                  'Back to menu',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final controller = _controller;
              _reactToFx();
              return Column(
                children: [
                  _header(context),
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        // Ludo King layout: every player's own dice sits
                        // beside their base corner of the board.
                        _cornerRow(left: 'red', right: 'green'),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: AnimatedBuilder(
                                  animation: _shake,
                                  builder: (context, child) {
                                    final t = _shake.value;
                                    final dx =
                                        math.sin(t * math.pi * 6) * 7 * (1 - t);
                                    return Transform.translate(
                                      offset: Offset(dx, 0),
                                      child: child,
                                    );
                                  },
                                  child: BoardView(
                                    tokens: controller.tokens,
                                    currentColor: controller.currentColor,
                                    movable: controller.movable,
                                    boardFx: controller.boardFx,
                                    onTokenTap: (color, index) =>
                                        controller.moveToken(index),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _cornerRow(left: 'blue', right: 'yellow'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.participants.any((p) => p.isCpu)
                  ? 'You vs Computer'
                  : 'Pass & Play',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          const SoundToggle(),
          TextButton.icon(
            onPressed: () {
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
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                LocalGameScreen(participants: widget.participants),
                          ),
                        );
                      },
                      child: const Text('Restart'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.refresh, color: AppColors.gold),
            label: const Text('Restart',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Participant? _participantOf(String color) {
    for (final p in _controller.participants) {
      if (p.color == color) return p;
    }
    return null;
  }

  /// One board-edge slot; renders that colour's own dice panel if seated.
  Widget _cornerSlot(String color, {required bool alignRight}) {
    final controller = _controller;
    final p = _participantOf(color);
    if (p == null) return const SizedBox.expand();
    return Align(
      alignment:
          alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: PlayerDicePanel(
        colorName: p.color,
        name: p.name,
        avatar: p.avatar,
        tokensHome: LudoEngine.tokensHome(controller.tokens[p.color]!),
        active: controller.currentColor == p.color,
        glowing: controller.currentColor == p.color &&
            controller.phase == GamePhase.awaitingRoll,
        diceValue: controller.diceValue ?? 1,
        rolling: controller.currentColor == p.color &&
            controller.phase == GamePhase.rolling,
        canRoll: controller.canRoll,
        onRollTap: controller.roll,
      ),
    );
  }

  Widget _cornerRow({required String left, required String right}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: SizedBox(
        height: 78,
        child: Row(
          children: [
            Expanded(child: _cornerSlot(left, alignRight: false)),
            Expanded(child: _cornerSlot(right, alignRight: true)),
          ],
        ),
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
        onTap: enabled ? onTap : null,
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

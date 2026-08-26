import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../game/game_controller.dart';
import '../../../game/ludo_engine.dart';
import '../../widgets/board_view.dart';
import '../../widgets/board_painter.dart';
import '../../widgets/dice_glow.dart';
import '../../widgets/dice_widget.dart';
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
                  Expanded(child: _playerStrip()),
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
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
                  _diceBar(),
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

  Widget _playerStrip() {
    final controller = _controller;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (var i = 0; i < controller.participants.length; i++)
            Expanded(
              child: _PlayerCard(
                participant: controller.participants[i],
                active: controller.currentColor ==
                    controller.participants[i].color,
                tokensHome:
                    LudoEngine.tokensHome(controller.tokens[controller.participants[i].color]!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _diceBar() {
    final controller = _controller;
    final rolling = controller.phase == GamePhase.rolling;
    final color = BoardPainter.colorOf(controller.currentColor);
    final waiting = controller.phase == GamePhase.awaitingRoll;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ludo King style: no turn text, no button - just tap the
          // glowing tray dice on your turn.
          DiceGlow(
            active: waiting,
            color: color,
            child: DiceWidget(
              value: controller.diceValue ?? 1,
              rolling: rolling,
              color: color,
              size: 72,
              enabled: controller.canRoll,
              onTap: controller.roll,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.participant,
    required this.active,
    required this.tokensHome,
  });

  final Participant participant;
  final bool active;
  final int tokensHome;

  @override
  Widget build(BuildContext context) {
    final color = BoardPainter.colorOf(participant.color);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: active ? 0.85 : 0.45),
            Color.lerp(color, Colors.black, 0.35)!
                .withValues(alpha: active ? 0.9 : 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active ? AppColors.gold : Colors.white24,
          width: active ? 2.2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.55),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: color,
              child: Text(participant.avatar,
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            participant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(blurRadius: 3, color: Colors.black54)]),
          ),
          const SizedBox(height: 3),
          // Ludo King style: 4 little house pips fill as tokens finish.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final done = i < tokensHome;
              return Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? Colors.white : Colors.white24,
                  border: Border.all(color: Colors.white70, width: 0.8),
                ),
              );
            }),
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

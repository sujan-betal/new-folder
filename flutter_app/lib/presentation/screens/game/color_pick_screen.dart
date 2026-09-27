import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/sound/haptics.dart';
import '../../../core/sound/sound_manager.dart';
import '../../../game/board_geometry.dart';
import '../../widgets/pawn_token.dart';

/// Pick your colour before a match, the way Ludo King asks before dropping you
/// into a board. The chosen colour becomes the human's token colour and the
/// CPU/bots take the rest.
class ColorPickScreen extends StatefulWidget {
  const ColorPickScreen({
    super.key,
    required this.playerCount,
    required this.vsCpu,
  });

  /// 2, 3 or 4 seats.
  final int playerCount;

  /// True when the other seats are computer players.
  final bool vsCpu;

  @override
  State<ColorPickScreen> createState() => _ColorPickScreenState();
}

class _ColorPickScreenState extends State<ColorPickScreen> {
  late String _picked = BoardGeometry.colors.first;

  /// Colours still open: the picked one plus one per empty seat.
  List<String> get _available {
    // Two players sit diagonally, matching how Ludo King pairs a 2-player game.
    final base = widget.playerCount == 2
        ? ['red', 'yellow']
        : BoardGeometry.colors.take(widget.playerCount).toList();
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        const Text(
                          'Choose your colour',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.vsCpu
                              ? 'You go first, the computer takes the rest'
                              : 'Tap a colour to claim it',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.15,
                          children: [
                            for (final c in _available)
                              _ColorCard(
                                colorName: c,
                                selected: c == _picked,
                                onTap: () {
                                  SoundManager.instance.tap();
                                  Haptics.instance.medium();
                                  setState(() => _picked = c);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
          ),
          Expanded(
            child: Text(
              '${widget.playerCount} players',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: GestureDetector(
        onTap: () {
          SoundManager.instance.tap();
          Haptics.instance.medium();
          Navigator.of(context).pop(_picked);
        },
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: AppColors.goldDark.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Text(
            'PLAY',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Color(0xFF4A2C00),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorCard extends StatelessWidget {
  const _ColorCard({
    required this.colorName,
    required this.selected,
    required this.onTap,
  });

  final String colorName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(colorName);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.white : Colors.black26,
            width: selected ? 4 : 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.75),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A pair of the player's own tokens, so the choice is obvious.
            SizedBox(
              height: 74,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final dx in const [-20.0, 20.0])
                    Positioned(
                      left: 44 + dx,
                      child: PawnToken(size: 58, color: Colors.white),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              colorName.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              child: selected
                  ? const Icon(Icons.check_circle,
                      color: Colors.white, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorOf(String name) {
    switch (name) {
      case 'red':
        return AppColors.red;
      case 'green':
        return AppColors.green;
      case 'yellow':
        return AppColors.yellow;
      default:
        return AppColors.blue;
    }
  }
}

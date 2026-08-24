import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/board_painter.dart';

class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({super.key, required this.mode});

  final String mode;

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _turnColors = ['red', 'green', 'yellow', 'blue'];
  static const List<String> _diceFaces = [
    '\u2680',
    '\u2681',
    '\u2682',
    '\u2683',
    '\u2684',
    '\u2685',
  ];

  final Random _random = Random();
  late final AnimationController _shake;
  int _diceValue = 6;
  bool _rolling = false;
  int _turnIndex = 0;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Color get _currentColor {
    switch (_turnColors[_turnIndex]) {
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

  Future<void> _roll() async {
    if (_rolling) return;
    setState(() => _rolling = true);
    _shake.forward(from: 0);

    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 70));
      if (!mounted) return;
      setState(() => _diceValue = _random.nextInt(6) + 1);
    }

    setState(() {
      _rolling = false;
      _turnIndex = (_turnIndex + 1) % _turnColors.length;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text(
          widget.mode == 'computer'
              ? 'Demo board - online moves come from the FastAPI game engine'
              : 'Pass the device to next player!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon:
                          const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.mode == 'computer'
                          ? 'You vs Computer'
                          : 'Local Multiplayer',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: CustomPaint(painter: const BoardPainter()),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration:
                          BoxDecoration(color: _currentColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: Text(
                        '${_turnColors[_turnIndex].toUpperCase()} turn',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: _roll,
                      child: RotationTransition(
                        turns: Tween<double>(begin: 0, end: 0.12)
                            .animate(_shake),
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _diceFaces[_diceValue - 1],
                            style: const TextStyle(fontSize: 46),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: _rolling ? null : _roll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'ROLL',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF4A2C00),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

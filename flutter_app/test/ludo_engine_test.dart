import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/game/board_geometry.dart';
import 'package:flutter_app/game/ludo_ai.dart';
import 'package:flutter_app/game/ludo_engine.dart';

void main() {
  group('LudoEngine', () {
    test('initial tokens are all in base', () {
      expect(LudoEngine.initialTokens(), [-1, -1, -1, -1]);
    });

    test('token leaves base only with a six', () {
      expect(LudoEngine.legalTargets(LudoEngine.initialTokens(), 3),
          [null, null, null, null]);
      // With a six every base token may enter the board.
      expect(LudoEngine.legalTargets(LudoEngine.initialTokens(), 6),
          [0, 0, 0, 0]);
    });

    test('exact roll required to finish at 57', () {
      final tokens = [51, -1, -1, -1];
      // Token 0 reaches home exactly; the rest may also exit with the six.
      expect(LudoEngine.legalTargets(tokens, 6), [57, 0, 0, 0]);

      // Overshoot beyond home is illegal.
      final nearHome = [53, -1, -1, -1];
      expect(
        LudoEngine.legalTargets(nearHome, 5),
        [null, null, null, null],
      );
      expect(
        LudoEngine.legalTargets(nearHome, 4),
        [57, null, null, null],
      );
    });

    test('landing on an enemy token captures it', () {
      final state = {
        'red': LudoEngine.initialTokens(),
        'blue': LudoEngine.initialTokens(),
      };
      state['red']![0] = 20;
      // Blue sits on absolute square 23 => relative (23-39) mod 52 = 36.
      state['blue']![0] = 36;

      final result = LudoEngine.applyMove(state, 'red', 0, 3);
      expect(result.captured, isTrue);
      expect(result.capturedColors, ['blue']);
      expect(state['blue']![0], LudoEngine.basePos);
      expect(state['red']![0], 23);
    });

    test('no capture on safe squares', () {
      final state = {
        'red': LudoEngine.initialTokens(),
        'green': LudoEngine.initialTokens(),
      };
      // Green start square is absolute 13 (safe).
      state['green']![0] = 0;
      state['red']![0] = 10;

      final result = LudoEngine.applyMove(state, 'red', 0, 3);
      expect(result.captured, isFalse);
      expect(state['green']![0], 0);
    });

    test('tokens in their home lane cannot be captured', () {
      final state = {
        'red': LudoEngine.initialTokens(),
        'green': LudoEngine.initialTokens(),
      };
      state['green']![0] = 52;
      state['red']![0] = 8;

      final result = LudoEngine.applyMove(state, 'red', 0, 5);
      expect(result.captured, isFalse);
      expect(state['green']![0], 52);
    });

    test('finished only when all four tokens reach home', () {
      expect(LudoEngine.isFinished([57, 57, 57, 57]), isTrue);
      expect(LudoEngine.isFinished([56, 57, 57, 57]), isFalse);
    });

    test('nextColor skips finished players', () {
      final tokens = {
        'red': [57, 57, 57, 57],
        'green': LudoEngine.initialTokens(),
      };
      expect(LudoEngine.nextColor(['red', 'green'], 'red', tokens), 'green');
    });

    test('absolute squares use start offsets and wrap around', () {
      expect(BoardGeometry.absoluteSquare('red', 0), 0);
      expect(BoardGeometry.absoluteSquare('green', 0), 13);
      expect(BoardGeometry.absoluteSquare('yellow', 0), 26);
      expect(BoardGeometry.absoluteSquare('blue', 0), 39);
      expect(BoardGeometry.absoluteSquare('blue', 14), 1);
      expect(BoardGeometry.ringCells.length, 52);
    });

    test('home lane cells exist for every color', () {
      for (final color in BoardGeometry.colors) {
        expect(BoardGeometry.laneCells[color]!.length, 5);
      }
    });
  });

  group('LudoAi', () {
    test('prefers the finishing move', () {
      final state = {
        'red': [55, 10, -1, -1],
      };
      final choice = LudoAi.chooseMove(
          state, 'red', 2, LudoEngine.legalTargets(state['red']!, 2));
      expect(choice, 0);
    });

    test('prefers a capturing move over a plain advance', () {
      final state = {
        'red': [10, 30, -1, -1],
        'blue': [((15 - 39) % 52 + 52) % 52, -1, -1, -1],
      };
      // dice 5 -> token0 lands on abs 15 where blue sits (not safe),
      // token1 advances to abs 35 with nothing there.
      final choice =
          LudoAi.chooseMove(state, 'red', 5, LudoEngine.legalTargets(state['red']!, 5));
      expect(choice, 0);
    });
  });
}

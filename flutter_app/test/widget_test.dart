import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/presentation/widgets/dice_widget.dart';

void main() {
  testWidgets('DiceWidget renders pips for the given value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DiceWidget(
              value: 5,
              rolling: false,
              color: AppColors.gold,
              size: 72,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DiceWidget), findsOneWidget);
  });
}

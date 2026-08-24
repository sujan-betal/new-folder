import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/injection_container.dart' as di;
import 'package:flutter_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app builds and reaches landing screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await di.init();
    await tester.pumpWidget(const LudoApp());
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('MASTER'), findsOneWidget);
  });
}

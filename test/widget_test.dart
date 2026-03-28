import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ppqa_snag_logger/main.dart';
import 'package:ppqa_snag_logger/state/app_state.dart';

void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const PPQAApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Login screen should show username and password fields
    expect(find.text('PPQA Snag Logger'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}

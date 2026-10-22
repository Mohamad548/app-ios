import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim800_controller/l10n.dart';
import 'package:sim800_controller/screens/splash_screen.dart';
import 'package:sim800_controller/theme.dart';

void main() {
  testWidgets('splash shows the Sorani welcome text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const SplashScreen(),
      ),
    );

    expect(find.text(L10n.welcome), findsOneWidget);
  });
}

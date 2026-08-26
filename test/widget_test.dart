// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:yanaworldwide_store/main.dart';
import 'package:yanaworldwide_store/screens/splash_screen.dart';
import 'package:yanaworldwide_store/theme/app_theme.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider<AppThemeController>(
        create: (_) => AppThemeController(),
        child: const MyApp(firebaseReady: false),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);

    // Dispose the splash and let its short sound guard timer complete.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}


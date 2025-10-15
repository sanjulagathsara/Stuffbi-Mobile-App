import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Use your real App so routing/theme match production.
import 'package:stuffbi/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stuffbi app flow', () {
    testWidgets('Splash shows and navigates to Login on Start', (
      WidgetTester tester,
    ) async {
      // Pump the whole app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Splash content
      expect(find.text('Stuffbi'), findsOneWidget);
      expect(find.text('Personal Inventory Management System'), findsOneWidget);

      // Tap Start
      final startBtn = find.widgetWithText(FilledButton, 'Start');
      expect(startBtn, findsOneWidget);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // We should be on Login
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
    });

    testWidgets('Login → Bundles via Continue as Guest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // From Splash → Login
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();

      // Tap Continue as Guest
      final guestBtn = find.widgetWithText(OutlinedButton, 'Continue as Guest');
      expect(guestBtn, findsOneWidget);
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();

      // On Bundles screen placeholder
      expect(find.text('Bundles'), findsOneWidget);
      expect(find.text('Bundles screen placeholder'), findsOneWidget);
    });

    testWidgets('Bundles → Dev (Under Development) via AppBar action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Splash → Login
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();

      // Login → Bundles (guest)
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Continue as Guest'),
      );
      await tester.pumpAndSettle();

      // Tap the Dev action (🛠️) in AppBar
      // We added tooltip: 'Dev' on the IconButton in BundlesScreen
      final devAction = find.byTooltip('Dev');
      expect(devAction, findsOneWidget);
      await tester.tap(devAction);
      await tester.pumpAndSettle();

      // Under Development screen content
      expect(find.text('Dev'), findsOneWidget); // AppBar title
      expect(find.text('Under Development'), findsOneWidget);
      expect(
        find.text('We’re crafting this feature for the next release.'),
        findsOneWidget,
      );

      // Back button (custom primary button)
      final backBtn = find.widgetWithText(FilledButton, 'Back');
      expect(backBtn, findsOneWidget);
    });
  });
}

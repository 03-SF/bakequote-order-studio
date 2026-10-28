import 'package:bakequote_mobile/core/config/backend_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakequote_mobile/app/app.dart';
import 'package:bakequote_mobile/features/auth/application/auth_controller.dart';
import 'support/fake_auth_repository.dart';

void main() {
  testWidgets(
    'Missing live configuration becomes an error rather than endless loading',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          backendConfigProvider.overrideWithValue(
            const BackendConfig(mode: 'live'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BakeQuoteApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Account unavailable'), findsOneWidget);
      expect(
        find.textContaining('Live backend setup is missing.'),
        findsOneWidget,
      );
      expect(find.textContaining('--dart-define-from-file='), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
  testWidgets(
    'Live login validates, loads real identity and protects role routes',
    (tester) async {
      final repo = FakeAuthRepository();
      final c = authContainer(repo);
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const BakeQuoteApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
      c.read(routerProvider).go('/bakery/ABCDEF0123456789ABCDEF0123456789');
      await tester.pumpAndSettle();
      expect(find.text('Explore customer preview'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(repo.logins, 0);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'alice@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Find a bakery'), findsOneWidget);
      expect(
        c
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['bakery'],
        'ABCDEF0123456789ABCDEF0123456789',
      );
      expect(
        c.read(authControllerProvider).identity?.email,
        'alice@example.test',
      );
      expect(find.text('Sara Ahmed'), findsNothing);
      c.read(routerProvider).go('/live/baker/today');
      await tester.pumpAndSettle();
      expect(
        c.read(routerProvider).routeInformationProvider.value.uri.path,
        '/live/customer/home',
      );
      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('alice@example.test'), findsNothing);
      expect(c.read(authControllerProvider).profile, isNull);
    },
  );
  testWidgets(
    'Live English registration validates at narrow width and 160% scale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeAuthRepository();
      final container = authContainer(repo);
      addTearDown(container.dispose);
      addTearDown(repo.events.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BakeQuoteApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/auth/register');
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(Form))),
        TextDirection.ltr,
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Ayesha');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'new@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'password');
      await tester.enterText(find.byType(TextFormField).at(3), 'different');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(repo.registrations, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

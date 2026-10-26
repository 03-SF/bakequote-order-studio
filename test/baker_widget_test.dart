import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bakequote_mobile/app/app.dart';
import 'package:bakequote_mobile/features/baker/presentation/baker_pages.dart';
import 'package:bakequote_mobile/features/baker/data/baker_repository.dart';
import 'support/baker_fixture.dart';

void main() {
  testWidgets(
    'Pricing controls reproduce PKR 4100 with selected extras and delivery',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PricingPanel(workspace: fixture(), dirty: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chocolate cake').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('2 lb').last);
      await tester.pumpAndSettle();
      for (final label in ['Buttercream', 'Topper']) {
        await tester.ensureVisible(find.textContaining(label));
        await tester.tap(find.textContaining(label));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).at(2),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Local delivery').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Estimated total: PKR 4100.00'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Baker workspace persists edits, activation, catalog and pricing preview',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PreviewBakerRepository.key: jsonEncode(fixture().toJson()),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BakeQuoteApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/baker/setup');
      await tester.pumpAndSettle();
      expect(find.text('Business draft'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name'),
        'Edited bakery',
      );
      await tester.scrollUntilVisible(
        find.text('Save draft changes'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Save draft changes'));
      await tester.pumpAndSettle();
      expect(find.text('Draft saved'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Review'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Review and activate'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Review and activate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Active business'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Active business'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Catalog'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(find.text('Chocolate cake'), findsOneWidget);
      await tester.tap(find.text('Edit product'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Product name'),
        'Edited cake',
      );
      await tester.scrollUntilVisible(
        find.text('Use product changes'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Use product changes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save draft changes'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Save draft changes'));
      await tester.pumpAndSettle();
      final saved = await PreviewBakerRepository(
        await SharedPreferences.getInstance(),
      ).load();
      expect(saved.business['name'], 'Edited bakery');
      expect(saved.products.single['name'], 'Edited cake');
      expect(saved.active, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Workspace handles invalid draft fields and unsaved exit at large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({
        PreviewBakerRepository.key: jsonEncode(fixture().toJson()),
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const BakeQuoteApp()),
      );
      await tester.pumpAndSettle();
      c.read(routerProvider).go('/baker/setup');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name'),
        '',
      );
      await tester.scrollUntilVisible(
        find.text('Save draft changes'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Save draft changes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Business name must'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Business name must'), findsOneWidget);
      c.read(routerProvider).go('/baker/today');
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        c.read(routerProvider).routeInformationProvider.value.uri.path,
        '/baker/setup',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

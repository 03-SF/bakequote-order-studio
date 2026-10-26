import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bakequote_mobile/app/app.dart';

void main() {
  testWidgets('Both role shells navigate and quotation opens', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BakeQuoteApp()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore customer preview'));
    await tester.tap(find.text('Explore customer preview'));
    await tester.pumpAndSettle();
    expect(find.text('Sweet Crumb by Ayesha'), findsOneWidget);
    await tester.tap(find.text('Orders').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View quotation'));
    await tester.pumpAndSettle();
    expect(find.text('PKR 4500'), findsWidgets);
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch preview role'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore baker preview'));
    await tester.tap(find.text('Explore baker preview'));
    await tester.pumpAndSettle();
    for (final title in [
      'Calendar',
      'Orders',
      'Messages',
      'Account',
      'Today',
    ]) {
      await tester.tap(find.text(title).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('English startup and large text work at narrow mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BakeQuoteApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.text('Explore customer preview'))),
      TextDirection.ltr,
    );
    await tester.ensureVisible(find.text('Explore customer preview'));
    await tester.tap(find.text('Explore customer preview'));
    await tester.pumpAndSettle();
    for (final title in ['Orders', 'Messages', 'Account', 'Home']) {
      await tester.tap(find.text(title).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

import 'package:bakequote_mobile/features/discovery/domain/discovery.dart';
import 'package:bakequote_mobile/features/discovery/application/discovery_controller.dart';
import 'package:bakequote_mobile/features/auth/application/auth_controller.dart';
import 'package:bakequote_mobile/features/auth/domain/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bakequote_mobile/features/discovery/presentation/discovery_page.dart';

const code = 'ABCDEF0123456789ABCDEF0123456789';
const bakery = Bakery(
  id: 'a',
  code: code,
  name: 'Test bakery',
  description: 'Public',
  location: 'Area',
  minimum: 10001,
  pickup: true,
  delivery: false,
);

class SessionStub extends AuthController {
  void switchAccount() {
    state = const AuthViewState(
      phase: AuthPhase.signedIn,
      identity: Identity('other', 'other@example.test', verified: true),
    );
  }

  @override
  AuthViewState build() => const AuthViewState(phase: AuthPhase.signedIn);
}

class FakeDiscovery implements DiscoveryRepository {
  @override
  Future<List<SavedBakery>> recent() async => [];
  @override
  Future<void> recordOpen(String id) async {}
  bool fail = false, unavailable = false, savedState = false;
  int saves = 0;
  @override
  Future<Bakery?> find(String code) async {
    if (fail) throw Exception();
    return unavailable ? null : bakery;
  }

  @override
  Future<List<MenuProduct>> menu(String code, {String? after}) async => [];
  @override
  Future<List<SavedBakery>> saved({String? after}) async =>
      savedState ? [const SavedBakery('a', bakery)] : [];
  @override
  Future<bool> isSaved(String id) async => savedState;
  @override
  Future<void> save(String id, bool saved) async {
    saves++;
    if (fail) throw Exception();
    savedState = saved;
  }
}

void main() {
  test('Discovery clears saved and recent state on account change', () async {
    final repo = FakeDiscovery()..savedState = true;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(SessionStub.new),
        discoveryRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.listen(discoveryControllerProvider, (_, _) {});
    await container.read(discoveryControllerProvider.notifier).loadSaved();
    expect(container.read(discoveryControllerProvider).saved, isNotEmpty);
    (container.read(authControllerProvider.notifier) as SessionStub)
        .switchAccount();
    expect(container.read(discoveryControllerProvider).saved, isEmpty);
    expect(container.read(discoveryControllerProvider).recent, isEmpty);
  });
  testWidgets(
    'Customer lookup keeps input on failure and works at narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeDiscovery()..fail = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(SessionStub.new),
            discoveryRepositoryProvider.overrideWithValue(repo),
            initialAuthLinkProvider.overrideWithValue(Future.value(null)),
          ],
          child: const MaterialApp(home: Scaffold(body: DiscoveryPage())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.widgetWithText(FilledButton, 'Find bakery'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load or save'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        code,
      );
      repo.fail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Find bakery'));
      await tester.pumpAndSettle();
      expect(find.text('Test bakery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Codes and supported links normalize without accepting arbitrary URLs',
    () {
      expect(bakeryCode(' ${code.toLowerCase()} '), code);
      expect(bakeryCode('dev.bakequote.mobile://bakery/$code'), code);
      expect(bakeryCode('https://untrusted.test/$code'), isNull);
      expect(
        bakeryCode('dev.bakequote.mobile://bakery/$code?token=private'),
        isNull,
      );
      expect(bakeryCode('bad'), isNull);
      expect(paisaText(410000), 'PKR 4100.00');
      expect(paisaText(10001), 'PKR 100.01');
    },
  );
  test(
    'Failed save does not report success or change saved state; retry persists',
    () async {
      final repo = FakeDiscovery();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(SessionStub.new),
          discoveryRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(discoveryControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final controller = container.read(discoveryControllerProvider.notifier);
      await controller.lookup(code);
      repo.fail = true;
      await controller.setSaved('a', true);
      expect(container.read(discoveryControllerProvider).isSaved, false);
      expect(
        container.read(discoveryControllerProvider).message,
        contains('Could not'),
      );
      repo.fail = false;
      await controller.setSaved('a', true);
      expect(container.read(discoveryControllerProvider).isSaved, true);
      await controller.loadSaved();
      expect(container.read(discoveryControllerProvider).saved.single.id, 'a');
    },
  );
  test('Unavailable or failed lookup clears previous public result', () async {
    final repo = FakeDiscovery();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(SessionStub.new),
        discoveryRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(discoveryControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(discoveryControllerProvider.notifier);
    await controller.lookup(code);
    expect(container.read(discoveryControllerProvider).bakery, isNotNull);
    repo.unavailable = true;
    await controller.lookup(code);
    expect(container.read(discoveryControllerProvider).bakery, isNull);
    expect(
      container.read(discoveryControllerProvider).message,
      contains('unavailable'),
    );
  });
}

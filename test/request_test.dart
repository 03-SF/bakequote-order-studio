import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bakequote_mobile/features/requests/data/request_repository.dart';
import 'package:bakequote_mobile/features/requests/domain/request.dart';
import 'package:bakequote_mobile/features/requests/application/request_controller.dart';
import 'package:bakequote_mobile/features/requests/presentation/request_pages.dart';
import 'package:bakequote_mobile/features/auth/application/auth_controller.dart';
import 'package:bakequote_mobile/features/auth/domain/auth_models.dart';
import 'package:bakequote_mobile/features/orders/data/order_repository.dart';

const input = RequestInput(
  productId: 'product',
  variantId: 'size',
  quantity: 1,
  date: '2027-01-01',
  name: 'Customer',
  phone: '03000000000',
);
const estimate = RequestEstimate(380000, 30000, 410000, [
  EstimateLine('Base', 300000),
  EstimateLine('Finish', 50000),
  EstimateLine('Topper', 30000),
]);
const catalogFixtureValue = RequestCatalog(
  'Cake',
  'cake',
  'ABCDEF0123456789ABCDEF0123456789',
  1,
  true,
  true,
  [RequestChoice('size', '1 kg', 'size', 300000)],
  [],
  [],
);

class RequestAuthStub extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(
    phase: AuthPhase.signedIn,
    identity: Identity('customer', 'c@example.test', verified: true),
  );
  void switchUser() {
    state = const AuthViewState(
      phase: AuthPhase.signedIn,
      identity: Identity('other', 'o@example.test', verified: true),
    );
  }
}

class BakerAuthStub extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(
    phase: AuthPhase.signedIn,
    identity: Identity('baker', 'baker@example.test', verified: true),
    profile: AccountProfile(
      id: 'baker',
      name: 'Baker',
      phone: '',
      experience: 'baker',
    ),
  );
}

class FakeRequests implements RequestRepository {
  RequestDraft remote = const RequestDraft('draft', 'bakery', 0, input);
  DraftCache? local;
  bool failSubmit = false,
      reject = false,
      unavailable = false,
      failUpload = false;
  int creates = 0, calls = 0;
  Completer<void>? submitGate, reviewGate;
  @override
  Future<RequestDraft> open(String business) async {
    if (remote.orderId != null) {
      remote = const RequestDraft('new-draft', 'bakery', 0, input);
    }
    return remote;
  }

  @override
  Future<RequestDraft> draft(String id) async => remote;
  @override
  Future<RequestCatalog?> catalog(String business, String product) async =>
      unavailable ? null : catalogFixture;
  RequestCatalog get catalogFixture => catalogFixtureValue;
  @override
  Future<RequestDraft> save(RequestDraft d) async {
    remote = RequestDraft(d.id, d.businessId, d.revision + 1, d.input);
    return remote;
  }

  @override
  Future<RequestDraft> review(RequestDraft d) async {
    if (reviewGate != null) await reviewGate!.future;
    remote = RequestDraft(
      d.id,
      d.businessId,
      d.revision,
      d.input,
      token: 'review',
      estimate: estimate,
    );
    return remote;
  }

  @override
  Future<String> submit(RequestDraft d) async {
    calls++;
    if (submitGate != null) await submitGate!.future;
    if (reject) {
      throw const RequestFailure(
        'Price changed. Review again.',
        definite: true,
      );
    }
    if (remote.orderId == null) {
      creates++;
      remote = RequestDraft(
        d.id,
        d.businessId,
        d.revision,
        d.input,
        token: d.token,
        estimate: d.estimate,
        orderId: 'order',
      );
    }
    if (failSubmit) throw Exception('Response lost');
    return 'order';
  }

  @override
  Future<DraftCache?> cached(String business) async => local;
  @override
  Future<void> cache(RequestDraft d, {bool uncertain = false}) async {
    local = DraftCache(d, uncertain);
  }

  @override
  Future<String> upload(String id, Uint8List bytes) async {
    if (failUpload) throw Exception('Network unavailable');
    return 'private/path';
  }

  @override
  Future<void> cleanup(RequestDraft d) async {}
  @override
  Future<void> removeUpload(String path) async {}
  @override
  Future<String> image(String path) async => 'https://example.invalid/image';
  @override
  Future<List<RequestRecord>> orders({String? after}) async => [];
  @override
  Future<RequestRecord> order(String id) => throw UnimplementedError();
  @override
  Future<List<String>> events(String id) async => [];
}

ProviderContainer harness(FakeRequests repo) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(RequestAuthStub.new),
    requestRepositoryProvider.overrideWith((ref) async => repo),
  ],
);
void main() {
  testWidgets(
    'Baker sees the saved bakery-local schedule and reschedule action',
    (tester) async {
      const record = RequestRecord(
        'order',
        'BQ-1',
        'confirmed',
        '2026-10-29',
        'Bakery',
        'Cake',
        input,
        '1 kg',
        [],
        estimate,
        'Asia/Karachi',
        '',
        '',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(BakerAuthStub.new),
            orderQuotesProvider.overrideWith((ref, id) async => []),
            orderScheduleProvider.overrideWith(
              (ref, id) async => {
                'date': '2027-01-01',
                'time': '15:30',
                'timezone': 'Asia/Karachi',
              },
            ),
            orderCancellationProvider.overrideWith((ref, id) async => null),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OrderActionPanel(orderId: 'order', record: record),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Saved schedule: 2027-01-01 15:30 (Asia/Karachi)'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Reschedule order'),
        findsOneWidget,
      );
    },
  );
  testWidgets('Baker can mark Baking and legacy Decorating orders Ready', (
    tester,
  ) async {
    for (final status in ['baking', 'decorating']) {
      final record = RequestRecord(
        'order',
        'BQ-1',
        status,
        '2026-10-29',
        'Bakery',
        'Cake',
        input,
        '1 kg',
        const [],
        estimate,
        'Asia/Karachi',
        '',
        '',
      );
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(status),
          overrides: [
            authControllerProvider.overrideWith(BakerAuthStub.new),
            orderQuotesProvider.overrideWith((ref, id) async => []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OrderActionPanel(orderId: 'order', record: record),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Mark ready'), findsOneWidget);
      expect(find.text('Start decorating'), findsNothing);
    }
  });
  testWidgets('Agreement remains disabled until the current quote is visible', (
    tester,
  ) async {
    final quoteResult = Completer<List<Map<String, dynamic>>>();
    const record = RequestRecord(
      'order',
      'BQ-1',
      'pending',
      '2026-10-29',
      'Bakery',
      'Cake',
      input,
      '1 kg',
      [],
      estimate,
      'Asia/Karachi',
      '',
      '',
      currentQuoteVersion: 2,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(RequestAuthStub.new),
          orderQuotesProvider.overrideWith((ref, id) => quoteResult.future),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderActionPanel(orderId: 'order', record: record),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final button = find.widgetWithText(FilledButton, 'Acknowledge exact quote');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    quoteResult.complete([
      {
        'version': 1,
        'estimate': {'total_paisa': 410000},
      },
      {
        'version': 2,
        'estimate': {'total_paisa': 580000},
        'reason': 'Updated design',
      },
    ]);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Quote v2: PKR 5800.00 (current)'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });
  testWidgets('Customer can withdraw a pending request after agreement', (
    tester,
  ) async {
    const record = RequestRecord(
      'order',
      'BQ-1',
      'pending',
      '2026-10-29',
      'Bakery',
      'Cake',
      input,
      '1 kg',
      [],
      estimate,
      'Asia/Karachi',
      '',
      '',
      currentQuoteVersion: 2,
      agreedQuoteVersion: 2,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(RequestAuthStub.new),
          orderQuotesProvider.overrideWith((ref, id) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OrderActionPanel(orderId: 'order', record: record),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(OutlinedButton, 'Withdraw request'),
      findsOneWidget,
    );
    expect(find.text('Acknowledge exact quote'), findsNothing);
  });
  test(
    'Failed upload preserves input and offers retry without a fake attachment',
    () async {
      final repo = FakeRequests()..failUpload = true;
      final c = harness(repo);
      addTearDown(c.dispose);
      c.listen(requestControllerProvider, (_, _) {});
      final ctrl = c.read(requestControllerProvider.notifier);
      await ctrl.open('bakery', 'product');
      await ctrl.upload(Uint8List.fromList([1]));
      expect(
        c.read(requestControllerProvider).draft!.input.attachments,
        isEmpty,
      );
      expect(c.read(requestControllerProvider).retryUpload, true);
      expect(c.read(requestControllerProvider).draft!.input.name, 'Customer');
      repo.failUpload = false;
      await ctrl.retryUpload();
      expect(c.read(requestControllerProvider).draft!.input.attachments, [
        'private/path',
      ]);
    },
  );
  test('Submitted draft can explicitly start a separate new request', () async {
    final repo = FakeRequests();
    final c = harness(repo);
    addTearDown(c.dispose);
    c.listen(requestControllerProvider, (_, _) {});
    final ctrl = c.read(requestControllerProvider.notifier);
    await ctrl.open('bakery', 'product');
    await ctrl.review();
    await ctrl.submit();
    await ctrl.newDraft('bakery', 'product');
    expect(c.read(requestControllerProvider).orderId, isNull);
    expect(c.read(requestControllerProvider).draft!.id, 'new-draft');
    expect(repo.creates, 1);
  });
  test(
    'Persistent drafts are isolated by authenticated account and project',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Future<SupabaseClient> session(String id) async {
        final client = SupabaseClient(
          'https://example.invalid',
          'test-client',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async {
            final payload = base64Url
                .encode(
                  utf8.encode(
                    jsonEncode({
                      'sub': id,
                      'exp':
                          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                    }),
                  ),
                )
                .replaceAll('=', '');
            return http.Response(
              jsonEncode({
                'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
                'refresh_token': 'test-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': id,
                  'aud': 'authenticated',
                  'email': 'test@example.test',
                  'created_at': '2026-10-29T00:00:00Z',
                  'app_metadata': {},
                  'user_metadata': {},
                },
              }),
              200,
            );
          }),
        );
        await client.auth.signInWithPassword(
          email: 'test@example.test',
          password: 'test-only',
        );
        addTearDown(client.dispose);
        return client;
      }

      final a = await session('customer-a'), b = await session('customer-b');
      final repoA = SupabaseRequestRepository(
        a,
        prefs,
        'customer-a',
        'project-a',
      );
      await repoA.cache(
        const RequestDraft('draft', 'bakery', 3, input),
        uncertain: true,
      );
      expect(
        (await SupabaseRequestRepository(
          a,
          prefs,
          'customer-a',
          'project-a',
        ).cached('bakery'))!.uncertain,
        true,
      );
      expect(
        await SupabaseRequestRepository(
          b,
          prefs,
          'customer-b',
          'project-a',
        ).cached('bakery'),
        isNull,
      );
      expect(
        await SupabaseRequestRepository(
          a,
          prefs,
          'customer-a',
          'project-b',
        ).cached('bakery'),
        isNull,
      );
      await a.auth.signOut(scope: SignOutScope.local);
      await expectLater(repoA.cached('bakery'), throwsA(isA<RequestFailure>()));
    },
  );
  test(
    'Builder validates impossible dates, required details and quantities',
    () {
      expect(input.copy(date: '2026-02-30').validate(1), isNotNull);
      expect(input.copy(fulfilment: 'delivery').validate(1), isNotNull);
      expect(input.copy(quantity: 0).validate(0), isNotNull);
      expect(input.copy(phone: '').validate(2), isNotNull);
      expect(input.validate(0), isNull);
    },
  );
  test('Backward navigation and restart retain unsent input', () async {
    final repo = FakeRequests();
    final first = harness(repo);
    final sub = first.listen(requestControllerProvider, (_, _) {});
    final ctrl = first.read(requestControllerProvider.notifier);
    await ctrl.open('bakery', 'product');
    await ctrl.edit(input.copy(instructions: 'Keep this design'));
    ctrl.step(1);
    ctrl.step(-1);
    expect(
      first.read(requestControllerProvider).draft!.input.instructions,
      'Keep this design',
    );
    sub.close();
    first.dispose();
    final next = harness(repo);
    addTearDown(next.dispose);
    next.listen(requestControllerProvider, (_, _) {});
    await next
        .read(requestControllerProvider.notifier)
        .open('bakery', 'product');
    expect(
      next.read(requestControllerProvider).draft!.input.instructions,
      'Keep this design',
    );
  });
  test(
    'Lost submission response keeps same key and recovers persisted order',
    () async {
      final repo = FakeRequests();
      final c = harness(repo);
      addTearDown(c.dispose);
      c.listen(requestControllerProvider, (_, _) {});
      final ctrl = c.read(requestControllerProvider.notifier);
      await ctrl.open('bakery', 'product');
      await ctrl.review();
      repo.failSubmit = true;
      await ctrl.submit();
      expect(c.read(requestControllerProvider).uncertain, true);
      expect(c.read(requestControllerProvider).orderId, isNull);
      await ctrl.edit(input.copy(name: 'Wrong mutation'));
      expect(c.read(requestControllerProvider).draft!.input.name, 'Customer');
      await ctrl.checkOutcome();
      expect(c.read(requestControllerProvider).orderId, 'order');
      expect(repo.creates, 1);
    },
  );
  test(
    'Duplicate taps are guarded; definite stale price needs another review',
    () async {
      final repo = FakeRequests();
      final c = harness(repo);
      addTearDown(c.dispose);
      c.listen(requestControllerProvider, (_, _) {});
      final ctrl = c.read(requestControllerProvider.notifier);
      await ctrl.open('bakery', 'product');
      await ctrl.review();
      repo.reject = true;
      await ctrl.submit();
      expect(c.read(requestControllerProvider).uncertain, false);
      expect(c.read(requestControllerProvider).draft!.token, isNull);
      expect(repo.creates, 0);
      repo.reject = false;
      await ctrl.review();
      repo.submitGate = Completer<void>();
      final pending = ctrl.submit();
      await Future<void>.delayed(Duration.zero);
      await ctrl.submit();
      repo.submitGate!.complete();
      await pending;
      expect(repo.calls, 2);
      expect(repo.creates, 1);
    },
  );
  test('Late review cannot restore another account draft', () async {
    final repo = FakeRequests();
    final c = harness(repo);
    addTearDown(c.dispose);
    c.listen(requestControllerProvider, (_, _) {});
    final ctrl = c.read(requestControllerProvider.notifier);
    await ctrl.open('bakery', 'product');
    repo.reviewGate = Completer<void>();
    final pending = ctrl.review();
    await Future<void>.delayed(Duration.zero);
    (c.read(authControllerProvider.notifier) as RequestAuthStub).switchUser();
    expect(c.read(requestControllerProvider).draft, isNull);
    repo.reviewGate!.complete();
    await pending;
    expect(c.read(requestControllerProvider).draft, isNull);
  });
  test(
    'Unavailable catalog clears stale choices without discarding contact input',
    () async {
      final repo = FakeRequests();
      final c = harness(repo);
      addTearDown(c.dispose);
      c.listen(requestControllerProvider, (_, _) {});
      final ctrl = c.read(requestControllerProvider.notifier);
      await ctrl.open('bakery', 'product');
      repo.unavailable = true;
      await ctrl.refreshCatalog();
      expect(c.read(requestControllerProvider).catalog, isNull);
      expect(c.read(requestControllerProvider).draft!.input.name, 'Customer');
    },
  );
  testWidgets(
    'Builder preserves quantity with Back at large text and narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeRequests();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(RequestAuthStub.new),
            requestRepositoryProvider.overrideWith((ref) async => repo),
          ],
          child: const MaterialApp(
            home: RequestBuilderPage(business: 'bakery', product: 'product'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextFormField, 'Quantity (minimum 1)');
      await tester.scrollUntilVisible(
        field,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, '2');
      final next = find.widgetWithText(FilledButton, 'Next');
      await tester.scrollUntilVisible(
        next,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
      final back = find.widgetWithText(OutlinedButton, 'Back');
      await tester.scrollUntilVisible(
        back,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(back);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        field,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

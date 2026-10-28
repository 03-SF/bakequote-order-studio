import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakequote_mobile/features/availability/domain/availability.dart';
import 'package:bakequote_mobile/features/availability/application/availability_controller.dart';
import 'package:bakequote_mobile/features/availability/presentation/availability_panel.dart';
import 'package:bakequote_mobile/features/auth/application/auth_controller.dart';
import 'package:bakequote_mobile/features/auth/domain/auth_models.dart';

class AuthStub extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(phase: AuthPhase.signedIn);
}

class CalendarFake implements AvailabilityRepository {
  bool fail = false, blocked = false;
  int revision = 0;
  Completer<void>? gate;
  @override
  Future<AvailabilityCalendar?> calendar(String code, String? start) async =>
      AvailabilityCalendar(
        configured: true,
        timezone: 'Asia/Karachi',
        today: '2026-12-31',
        leadDays: 1,
        days: [
          AvailabilityDay('2027-01-01', blocked ? 'blocked' : 'available'),
        ],
      );
  @override
  Future<AvailabilitySettings> settings(String businessId) async =>
      AvailabilitySettings('Asia/Karachi', 1, 2, revision);
  @override
  Future<void> save(
    String businessId,
    int rev,
    String timezone,
    int leadDays,
    int capacity,
  ) async {
    if (gate != null) await gate!.future;
    if (fail) {
      throw const AvailabilityFailure(
        'Another edit was saved. Reload and review before retrying.',
      );
    }
    revision++;
  }

  @override
  Future<void> block(
    String businessId,
    int revision,
    String date,
    bool value,
  ) async {
    blocked = value;
  }
}

void main() {
  test(
    'Date-only navigation crosses years and leap months without timezone conversion',
    () {
      expect(
        serviceDate(calendarMonth(DateTime.utc(2026, 12, 31), 1)),
        '2027-01-01',
      );
      expect(
        serviceDate(calendarMonth(DateTime.utc(2027, 1, 1), -1)),
        '2026-12-01',
      );
      expect(serviceDate(DateTime.utc(2028, 3, 0)), '2028-02-29');
    },
  );
  test(
    'Failure is not success, duplicates prevented and block refreshes',
    () async {
      final repo = CalendarFake();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(AuthStub.new),
          availabilityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.listen(availabilityControllerProvider, (_, _) {});
      final controller = container.read(
        availabilityControllerProvider.notifier,
      );
      await controller.load('code', null, 'owner');
      repo.fail = true;
      await controller.save('code', 'owner', null, 'Asia/Karachi', 1, 2);
      expect(
        container.read(availabilityControllerProvider).message,
        contains('Reload'),
      );
      expect(repo.revision, 0);
      repo.fail = false;
      repo.gate = Completer<void>();
      final first = controller.save(
        'code',
        'owner',
        null,
        'Asia/Karachi',
        1,
        2,
      );
      await controller.save('code', 'owner', null, 'Asia/Karachi', 1, 2);
      repo.gate!.complete();
      await first;
      expect(repo.revision, 1);
      await controller.block(
        'code',
        'owner',
        null,
        const AvailabilityDay('2027-01-01', 'available'),
      );
      expect(
        container
            .read(availabilityControllerProvider)
            .calendar!
            .days
            .single
            .state,
        'blocked',
      );
    },
  );
  testWidgets(
    'Calendar form preserves input on conflict at large text and narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = CalendarFake()..fail = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(AuthStub.new),
            availabilityRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AvailabilityPanel(code: 'code', ownerId: 'owner'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '3');
      await tester.ensureVisible(find.text('Save availability'));
      await tester.tap(find.text('Save availability'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Another edit'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '3',
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Next month'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Today'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

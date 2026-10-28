import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../../core/config/backend_config.dart';
import '../data/availability_repository.dart';
import '../domain/availability.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (ref.watch(backendConfigProvider).isPreview ||
      auth.phase != AuthPhase.signedIn) {
    throw const AvailabilityFailure('Sign in to load availability.');
  }
  return SupabaseAvailabilityRepository(
    ref.watch(supabaseClientProvider),
    auth.identity!.id,
  );
});

final availabilityDirtyProvider = NotifierProvider<AvailabilityDirty, bool>(
  AvailabilityDirty.new,
);

class AvailabilityDirty extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authControllerProvider.select((s) => s.identity?.id));
    return false;
  }

  void set(bool value) => state = value;
}

class AvailabilityState {
  const AvailabilityState({
    this.calendar,
    this.settings,
    this.busy = false,
    this.message,
  });
  final AvailabilityCalendar? calendar;
  final AvailabilitySettings? settings;
  final bool busy;
  final String? message;
}

final availabilityControllerProvider =
    NotifierProvider.autoDispose<AvailabilityController, AvailabilityState>(
      AvailabilityController.new,
    );

class AvailabilityController extends Notifier<AvailabilityState> {
  int _epoch = 0;
  String? _target;
  @override
  AvailabilityState build() {
    ref.watch(authControllerProvider.select((s) => s.identity?.id));
    _epoch++;
    _target = null;
    return const AvailabilityState();
  }

  Future<void> load(String code, String? start, String? owner) {
    if (_target != code) {
      _epoch++;
      _target = code;
      state = const AvailabilityState();
    }
    return _run((repo) async {
      final settings = owner == null ? null : await repo.settings(owner);
      final calendar = await repo.calendar(code, start);
      return AvailabilityState(
        calendar: calendar,
        settings: settings,
        message: calendar == null ? 'Bakery unavailable.' : null,
      );
    });
  }

  Future<void> save(
    String code,
    String owner,
    String? start,
    String timezone,
    int lead,
    int capacity,
  ) => _run((repo) async {
    await repo.save(owner, state.settings!.revision, timezone, lead, capacity);
    return AvailabilityState(
      calendar: await repo.calendar(code, start),
      settings: await repo.settings(owner),
      message: 'Availability saved.',
    );
  });
  Future<void> block(
    String code,
    String owner,
    String? start,
    AvailabilityDay day,
  ) => _run((repo) async {
    await repo.block(
      owner,
      state.settings!.revision,
      day.date,
      day.state != 'blocked',
    );
    return AvailabilityState(
      calendar: await repo.calendar(code, start),
      settings: await repo.settings(owner),
      message: 'Date updated.',
    );
  });
  Future<void> _run(
    Future<AvailabilityState> Function(AvailabilityRepository) action,
  ) async {
    if (state.busy) return;
    final epoch = _epoch;
    state = AvailabilityState(
      calendar: state.calendar,
      settings: state.settings,
      busy: true,
    );
    try {
      final result = await action(ref.read(availabilityRepositoryProvider));
      if (ref.mounted && epoch == _epoch) state = result;
    } catch (error) {
      if (ref.mounted && epoch == _epoch) {
        state = AvailabilityState(
          calendar: state.calendar,
          settings: state.settings,
          message: error is AvailabilityFailure
              ? error.message
              : 'Could not load or save. Retry; your input is preserved.',
        );
      }
    }
  }
}

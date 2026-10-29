import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/media/image_validation.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/request_repository.dart';
import '../domain/request.dart';

final requestRepositoryProvider = FutureProvider.autoDispose<RequestRepository>(
  (ref) async {
    final auth = ref.watch(authControllerProvider),
        config = ref.watch(backendConfigProvider);
    if (config.isPreview || auth.phase != AuthPhase.signedIn) {
      throw const RequestFailure(
        'Sign in to manage real requests.',
        definite: true,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    return SupabaseRequestRepository(
      ref.read(supabaseClientProvider),
      prefs,
      auth.identity!.id,
      config.url,
    );
  },
  retry: (_, _) => null,
);
final requestImageProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) async =>
      (await ref.watch(requestRepositoryProvider.future)).image(path),
  retry: (_, _) => null,
);
final requestsProvider = FutureProvider.autoDispose<List<RequestRecord>>(
  (ref) async => (await ref.watch(requestRepositoryProvider.future)).orders(),
  retry: (_, _) => null,
);
final requestPageProvider = FutureProvider.autoDispose
    .family<List<RequestRecord>, String>(
      (ref, after) async => (await ref.watch(
        requestRepositoryProvider.future,
      )).orders(after: after.isEmpty ? null : after),
      retry: (_, _) => null,
    );
final requestDetailProvider = FutureProvider.autoDispose
    .family<RequestRecord, String>(
      (ref, id) async =>
          (await ref.watch(requestRepositoryProvider.future)).order(id),
      retry: (_, _) => null,
    );
final requestEventsProvider = FutureProvider.autoDispose
    .family<List<String>, String>(
      (ref, id) async =>
          (await ref.watch(requestRepositoryProvider.future)).events(id),
      retry: (_, _) => null,
    );

class RequestState {
  const RequestState({
    this.draft,
    this.catalog,
    this.step = 0,
    this.busy = false,
    this.uncertain = false,
    this.message,
    this.orderId,
    this.retryUpload = false,
    this.formRevision = 0,
  });
  final RequestDraft? draft;
  final RequestCatalog? catalog;
  final int step;
  final int formRevision;
  final bool busy, uncertain, retryUpload;
  final String? message, orderId;
  RequestState copy({
    RequestDraft? draft,
    RequestCatalog? catalog,
    int? step,
    bool? busy,
    bool? uncertain,
    String? message,
    String? orderId,
    bool? retryUpload,
  }) => RequestState(
    draft: draft ?? this.draft,
    catalog: catalog ?? this.catalog,
    step: step ?? this.step,
    busy: busy ?? this.busy,
    uncertain: uncertain ?? this.uncertain,
    message: message,
    orderId: orderId ?? this.orderId,
    retryUpload: retryUpload ?? this.retryUpload,
    formRevision: formRevision,
  );
}

final requestControllerProvider =
    NotifierProvider.autoDispose<RequestController, RequestState>(
      RequestController.new,
    );

class RequestController extends Notifier<RequestState> {
  int _epoch = 0;
  Uint8List? _lastUpload;
  @override
  RequestState build() {
    ref.watch(authControllerProvider.select((s) => s.identity?.id));
    _epoch++;
    _lastUpload = null;
    return const RequestState();
  }

  Future<void> _run(
    Future<RequestState> Function(RequestRepository, bool Function()) action,
  ) async {
    if (state.busy) return;
    final epoch = _epoch;
    state = state.copy(busy: true);
    try {
      final repo = await ref.read(requestRepositoryProvider.future);
      if (!ref.mounted || epoch != _epoch) return;
      final next = await action(repo, () => ref.mounted && epoch == _epoch);
      if (ref.mounted && epoch == _epoch) {
        state = next.copy(busy: false, message: next.message);
      }
    } catch (e) {
      if (ref.mounted && epoch == _epoch) {
        state = state.copy(
          busy: false,
          message: e is RequestFailure
              ? e.message
              : e is ImageValidationFailure
              ? e.message
              : 'Connection failed. Your draft is preserved; check saved status before retrying.',
        );
      }
    }
  }

  Future<void> open(String business, String product) async {
    _epoch++;
    state = const RequestState();
    await _run((repo, current) async {
      final cached = await repo.cached(business);
      if (!current()) return const RequestState();
      if (current() && cached != null) {
        state = state.copy(draft: cached.draft, uncertain: cached.uncertain);
      }
      var remote = cached == null
          ? await repo.open(business)
          : await repo.draft(cached.draft.id);
      if (remote.orderId != null) {
        return RequestState(
          draft: remote,
          orderId: remote.orderId,
          message: 'This draft was submitted. Open the saved request.',
        );
      }
      final d = cached != null ? cached.draft : remote;
      final input = d.input.productId.isEmpty
          ? d.input.copy(productId: product)
          : d.input;
      final restored = d.input.productId.isEmpty ? d.edited(input) : d;
      final catalog = await repo.catalog(business, input.productId);
      if (!current()) return const RequestState();
      await repo.cache(restored, uncertain: cached?.uncertain ?? false);
      return RequestState(
        draft: restored,
        catalog: catalog,
        uncertain: cached?.uncertain ?? false,
        message: remote.revision != d.revision
            ? 'A newer draft exists. Local edits are kept. Reload the server draft before saving.'
            : input.productId != product
            ? 'Restored your existing draft for another product. Use Change product to replace its selections.'
            : 'Unsent draft restored. Edits stay on this device until Save draft or Review succeeds.',
      );
    });
  }

  Future<void> edit(RequestInput input) async {
    if (state.busy || state.uncertain || state.orderId != null) return;
    final d = state.draft!.edited(input), epoch = _epoch;
    state = state.copy(draft: d);
    try {
      final repo = await ref.read(requestRepositoryProvider.future);
      if (!ref.mounted || epoch != _epoch) return;
      await repo.cache(d);
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = state.copy(
          message:
              'Could not preserve the latest edit locally. Keep this page open and save the draft.',
        );
      }
    }
  }

  Future<void> newDraft(String business, String product) =>
      _run((repo, current) async {
        final remote = await repo.open(business);
        final d = remote.edited(remote.input.copy(productId: product));
        final catalog = await repo.catalog(business, product);
        if (!current()) return const RequestState();
        await repo.cache(d);
        return RequestState(
          draft: d,
          catalog: catalog,
          message: 'New unsent draft. Your previous request remains saved.',
        );
      });

  void step(int direction) {
    if (state.busy || state.uncertain) return;
    var error = direction > 0 ? state.draft?.input.validate(state.step) : null;
    final input = state.draft?.input, catalog = state.catalog;
    if (direction > 0 &&
        state.step == 0 &&
        (input == null || catalog == null || !catalog.accepts(input))) {
      error = 'Choose current catalog options and meet the minimum quantity.';
    }
    if (direction > 0 &&
        state.step == 1 &&
        input != null &&
        catalog != null &&
        ((input.fulfilment == 'pickup' && !catalog.pickup) ||
            (input.fulfilment == 'delivery' &&
                (!catalog.delivery ||
                    !catalog.zones.any((z) => z.id == input.zoneId))))) {
      error = 'Choose an available fulfilment method and delivery zone.';
    }
    state = error != null
        ? state.copy(message: error)
        : state.copy(step: (state.step + direction).clamp(0, 3));
  }

  Future<void> save() => _run((repo, current) async {
    final d = await repo.save(state.draft!);
    if (!current()) return const RequestState();
    await repo.cache(d);
    return state.copy(
      draft: d,
      message: 'Draft saved to your account. Not submitted.',
    );
  });
  Future<void> reload() => _run((repo, current) async {
    final d = await repo.draft(state.draft!.id);
    if (!current()) return const RequestState();
    await repo.cache(d);
    return RequestState(
      draft: d,
      catalog: await repo.catalog(d.businessId, d.input.productId),
      orderId: d.orderId,
      message: 'Loaded the saved server draft.',
      formRevision: state.formRevision + 1,
    );
  });
  Future<void> refreshCatalog() => _run((repo, current) async {
    final d = state.draft!;
    final catalog = await repo.catalog(d.businessId, d.input.productId);
    if (!current()) return const RequestState();
    final cleared = d.edited(d.input);
    await repo.cache(cleared);
    return RequestState(
      draft: cleared,
      catalog: catalog,
      step: state.step,
      message: catalog == null
          ? 'Product is no longer available. Return to the bakery to choose another product.'
          : 'Catalog refreshed. Check selections and review the current estimate again.',
    );
  });
  Future<void> changeProduct(String product) => _run((repo, current) async {
    final d = state.draft!.edited(
      state.draft!.input.copy(
        productId: product,
        variantId: '',
        optionIds: [],
        message: '',
      ),
    );
    final c = await repo.catalog(d.businessId, product);
    if (!current()) return const RequestState();
    await repo.cache(d);
    return RequestState(
      draft: d,
      catalog: c,
      message: 'Product changed. Select its size and options again.',
    );
  });
  Future<void> review() => _run((repo, current) async {
    for (var i = 0; i < 3; i++) {
      final error = state.draft!.input.validate(i);
      if (error != null) throw RequestFailure(error, definite: true);
    }
    var d = await repo.save(state.draft!);
    if (!current()) return const RequestState();
    await repo.cache(d);
    // Keep the acknowledged revision if review itself fails.
    if (current()) state = state.copy(draft: d);
    d = await repo.review(d);
    if (!current()) return const RequestState();
    await repo.cache(d);
    return state.copy(
      draft: d,
      step: 3,
      message:
          'Review the current server estimate below. No capacity is reserved.',
    );
  });
  Future<void> submit() => _run((repo, current) async {
    final d = state.draft!;
    if (d.token == null) {
      throw const RequestFailure(
        'Review the current server estimate first.',
        definite: true,
      );
    }
    await repo.cache(d, uncertain: true);
    if (!current()) return const RequestState();
    if (current()) state = state.copy(uncertain: true);
    String id;
    try {
      id = await repo.submit(d);
    } on RequestFailure catch (e) {
      if (e.definite && current()) {
        final cleared = d.edited(d.input);
        await repo.cache(cleared);
        if (current()) state = state.copy(uncertain: false, draft: cleared);
      }
      rethrow;
    }
    if (!current()) return const RequestState();
    final persisted = RequestDraft(
      d.id,
      d.businessId,
      d.revision,
      d.input,
      token: d.token,
      estimate: d.estimate,
      orderId: id,
    );
    if (current()) {
      state = state.copy(draft: persisted, orderId: id, uncertain: false);
      ref.invalidate(requestsProvider);
    }
    try {
      await repo.cache(persisted);
    } catch (_) {
      return state.copy(
        draft: persisted,
        orderId: id,
        uncertain: false,
        message:
            'Pending request saved. Local cache could not update; reopen it from Your requests.',
      );
    }
    return state.copy(
      draft: persisted,
      orderId: id,
      uncertain: false,
      message: 'Pending request saved. This is not a confirmed order.',
    );
  });

  Future<void> checkOutcome() => _run((repo, current) async {
    final d = await repo.draft(state.draft!.id);
    if (!current()) return const RequestState();
    if (d.orderId != null) {
      await repo.cache(d);
      if (current()) ref.invalidate(requestsProvider);
      return state.copy(
        draft: d,
        orderId: d.orderId,
        uncertain: false,
        message: 'Submission found. Pending request saved.',
      );
    }
    // A still-in-flight call may commit later. Keep input frozen; retry the same token only.
    return state.copy(
      message:
          'No completed submission found yet. Retry the same submission safely, or check again.',
    );
  });
  Future<void> upload(Uint8List bytes) async {
    if (state.busy || state.uncertain || state.orderId != null) return;
    _lastUpload = bytes;
    state = state.copy(retryUpload: true);
    await _run((repo, current) async {
      if (state.draft!.input.attachments.length >= 3) {
        throw const RequestFailure(
          'Maximum three reference images.',
          definite: true,
        );
      }
      final original = state.draft!;
      final path = await repo.upload(original.id, bytes);
      if (!current()) return const RequestState();
      final d = state.draft!.edited(
        state.draft!.input.copy(
          attachments: [...state.draft!.input.attachments, path],
        ),
      );
      await repo.cache(d);
      _lastUpload = null;
      return state.copy(
        draft: d,
        retryUpload: false,
        message:
            'Reference uploaded privately. Save or review to synchronize the draft.',
      );
    });
  }

  Future<void> retryUpload() async {
    if (_lastUpload != null) await upload(_lastUpload!);
  }

  Future<void> remove(String path) => _run((repo, current) async {
    var d = state.draft!.edited(
      state.draft!.input.copy(
        attachments: state.draft!.input.attachments
            .where((p) => p != path)
            .toList(),
      ),
    );
    await repo.cache(d);
    d = await repo.save(d);
    if (!current()) return const RequestState();
    await repo.cache(d);
    if (current()) state = state.copy(draft: d);
    await repo.removeUpload(path);
    return state.copy(draft: d, message: 'Reference removed.');
  });
  Future<void> cleanup() => _run((repo, current) async {
    await repo.cleanup(state.draft!);
    return state.copy(
      message:
          'Abandoned upload cleanup checked. Submitted attachments remain protected.',
    );
  });
}

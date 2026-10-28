import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/discovery_repository.dart';
import '../domain/discovery.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  final config = ref.watch(backendConfigProvider);
  final auth = ref.watch(authControllerProvider);
  if (config.isPreview || auth.phase != AuthPhase.signedIn) {
    throw const UserFacingFailure('Sign in to browse live bakeries.');
  }
  return SupabaseDiscoveryRepository(
    ref.read(supabaseClientProvider),
    auth.identity!.id,
  );
});

class DiscoveryState {
  const DiscoveryState({
    this.bakery,
    this.products = const [],
    this.saved = const [],
    this.recent = const [],
    this.isSaved = false,
    this.busy = false,
    this.moreMenu = false,
    this.moreSaved = false,
    this.message,
  });
  final Bakery? bakery;
  final List<MenuProduct> products;
  final List<SavedBakery> saved;
  final List<SavedBakery> recent;
  final bool isSaved, busy, moreMenu, moreSaved;
  final String? message;
  DiscoveryState copy({
    Bakery? bakery,
    List<MenuProduct>? products,
    List<SavedBakery>? saved,
    List<SavedBakery>? recent,
    bool? isSaved,
    bool? busy,
    bool? moreMenu,
    bool? moreSaved,
    String? message,
  }) => DiscoveryState(
    bakery: bakery ?? this.bakery,
    products: products ?? this.products,
    saved: saved ?? this.saved,
    recent: recent ?? this.recent,
    isSaved: isSaved ?? this.isSaved,
    busy: busy ?? this.busy,
    moreMenu: moreMenu ?? this.moreMenu,
    moreSaved: moreSaved ?? this.moreSaved,
    message: message,
  );
}

final discoveryControllerProvider =
    NotifierProvider.autoDispose<DiscoveryController, DiscoveryState>(
      DiscoveryController.new,
    );

class DiscoveryController extends Notifier<DiscoveryState> {
  int _epoch = 0;
  @override
  DiscoveryState build() {
    ref.watch(authControllerProvider.select((s) => s.identity?.id));
    _epoch++;
    return const DiscoveryState();
  }

  Future<void> _run(
    Future<void> Function(DiscoveryRepository, bool Function()) action,
  ) async {
    if (state.busy) return;
    final epoch = _epoch;
    bool current() => ref.mounted && epoch == _epoch;
    state = state.copy(busy: true);
    try {
      await action(ref.read(discoveryRepositoryProvider), current);
    } catch (_) {
      if (current()) {
        state = state.copy(
          message:
              'Could not load or save. Check your connection and try again.',
        );
      }
    } finally {
      if (current()) state = state.copy(busy: false, message: state.message);
    }
  }

  Future<void> lookup(String input) async {
    if (state.busy) return;
    final code = bakeryCode(input);
    if (code == null) {
      state = state.copy(
        message: 'Enter a 32-character bakery code or BakeQuote bakery link.',
      );
      return;
    }
    // Clear the previous result so failed/unavailable lookups never show stale bakery details.
    state = DiscoveryState(
      saved: state.saved,
      recent: state.recent,
      moreSaved: state.moreSaved,
    );
    await _run((repo, current) async {
      final bakery = await repo.find(code);
      if (!current()) return;
      if (bakery == null) {
        state = state.copy(
          message: 'Bakery unavailable. Check the code with the baker.',
        );
        return;
      }
      final menu = await repo.menu(code);
      final saved = await repo.isSaved(bakery.id);
      if (current()) {
        state = state.copy(
          bakery: bakery,
          products: menu,
          isSaved: saved,
          moreMenu: menu.length == 20,
        );
      }
      if (!current()) return;
      await repo.recordOpen(bakery.id);
      final recent = await repo.recent();
      if (current()) state = state.copy(recent: recent);
    });
  }

  Future<void> moreProducts() => _run((repo, current) async {
    if (state.bakery == null || !state.moreMenu) return;
    final more = await repo.menu(
      state.bakery!.code,
      after: state.products.last.id,
    );
    if (current()) {
      state = state.copy(
        products: [...state.products, ...more],
        moreMenu: more.length == 20,
      );
    }
  });

  Future<void> loadSaved({bool more = false}) => _run((repo, current) async {
    final list = await repo.saved(
      after: more && state.saved.isNotEmpty ? state.saved.last.id : null,
    );
    if (current()) {
      state = state.copy(
        saved: more ? [...state.saved, ...list] : list,
        moreSaved: list.length == 20,
      );
    }
  });

  Future<void> loadRecent() => _run((repo, current) async {
    final list = await repo.recent();
    if (current()) state = state.copy(recent: list);
  });

  Future<void> setSaved(String id, bool value) => _run((repo, current) async {
    await repo.save(id, value);
    if (!current()) return;
    // Only report success after the server commits. Refresh is a separate recoverable action.
    state = state.copy(
      isSaved: state.bakery?.id == id ? value : state.isSaved,
      saved: value
          ? state.saved
          : state.saved.where((s) => s.id != id).toList(),
      message: value ? 'Bakery saved.' : 'Bakery removed from saved.',
    );
  });
}

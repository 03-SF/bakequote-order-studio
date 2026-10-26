import 'package:flutter_riverpod/flutter_riverpod.dart';

class PreviewBakery {
  const PreviewBakery();
  final String name = 'Sweet Crumb by Ayesha';
  final String code = 'SWEETCRUMB';
}

/// Explicit fixture repository, replaced by scoped data repositories in later phases.
abstract interface class BakeryPreviewRepository {
  PreviewBakery read();
}

class FixtureBakeryRepository implements BakeryPreviewRepository {
  @override
  PreviewBakery read() => const PreviewBakery();
}

final bakeryPreviewRepositoryProvider = Provider<BakeryPreviewRepository>(
  (ref) => FixtureBakeryRepository(),
);
final bakeryPreviewProvider = Provider(
  (ref) => ref.watch(bakeryPreviewRepositoryProvider).read(),
);

import 'dart:typed_data';

import 'baker_workspace.dart';

abstract interface class BakerRepository {
  Future<BakerWorkspace> load();
  Future<BakerWorkspace> save(BakerWorkspace workspace);
  Future<BakerWorkspace> activate(BakerWorkspace workspace);
  Future<Json> estimate(
    BakerWorkspace workspace,
    String productId,
    String variantId,
    List<String> options,
    int quantity,
    String? zoneId,
  );
  Future<BakerWorkspace> image(
    BakerWorkspace workspace,
    String slot,
    String? productId,
    Uint8List? bytes,
    void Function(String) progress,
  );
  Future<int> retryCleanup();
  String imageUrl(String path, String slot);
}

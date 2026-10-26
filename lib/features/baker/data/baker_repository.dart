import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/media/image_validation.dart';
import '../domain/baker_repository.dart';
import '../domain/baker_workspace.dart';

class PreviewBakerRepository implements BakerRepository {
  PreviewBakerRepository(this.preferences);
  final SharedPreferences preferences;
  static const key = 'bakequote.preview.baker.v3';
  @override
  Future<BakerWorkspace> load() async {
    final saved = preferences.getString(key);
    if (saved != null) return BakerWorkspace.fromJson(jsonDecode(saved));
    return BakerWorkspace(
      {
        'id': 'preview-business',
        'revision': 0,
        'name': 'My preview bakery',
        'description': '',
        'owner_name': '',
        'contact_phone': '',
        'location': '',
        'pickup_address': '',
        'pickup_enabled': true,
        'delivery_enabled': false,
        'minimum_paisa': 0,
        'onboarding_complete': false,
        'code': 'PREVIEW-${const Uuid().v4().substring(0, 8).toUpperCase()}',
        'image_path': null,
        'cover_path': null,
      },
      [],
      [],
    );
  }

  Future<BakerWorkspace> _store(BakerWorkspace w) async {
    await preferences.setString(key, jsonEncode(w.toJson()));
    return w.copy();
  }

  @override
  Future<BakerWorkspace> save(BakerWorkspace w) async {
    w.validate();
    final old = await load();
    if (old.revision != w.revision) {
      throw const FormatException('Workspace changed; reload before saving');
    }
    final next = w.copy();
    next.business['revision'] = w.revision + 1;
    return _store(next);
  }

  @override
  Future<BakerWorkspace> activate(BakerWorkspace w) async {
    w.validate(activation: true);
    final next = w.copy();
    next.business['onboarding_complete'] = true;
    return save(next);
  }

  @override
  Future<Json> estimate(
    BakerWorkspace w,
    String p,
    String v,
    List<String> o,
    int q,
    String? z,
  ) async => previewEstimate(w, p, v, o, q, z);
  @override
  Future<BakerWorkspace> image(
    BakerWorkspace w,
    String slot,
    String? productId,
    Uint8List? bytes,
    void Function(String) progress,
  ) async {
    progress('Saving preview image');
    if (bytes != null) validateImage(bytes);
    final next = w.copy();
    final value = bytes == null
        ? null
        : 'data:image;base64,${base64Encode(bytes)}';
    if (slot == 'product') {
      next.products.firstWhere((p) => p['id'] == productId)['image_path'] =
          value;
    } else {
      next.business[slot == 'profile' ? 'image_path' : 'cover_path'] = value;
    }
    return save(next);
  }

  @override
  Future<int> retryCleanup() async => 0;
  @override
  String imageUrl(String path, String slot) => path;
}

class SupabaseBakerRepository implements BakerRepository {
  SupabaseBakerRepository(
    this.client,
    this.preferences,
    this.userId,
    this.businessId,
  );
  final SupabaseClient client;
  final SharedPreferences preferences;
  final String userId, businessId;
  String get _cleanupKey =>
      'bakequote.cleanup.${Uri.parse(client.rest.url).host}.$userId';
  void _check() {
    if (client.auth.currentUser?.id != userId) {
      throw const FormatException(
        'Session changed. Sign in again before editing.',
      );
    }
  }

  @override
  Future<BakerWorkspace> load() async {
    _check();
    final b = await client
        .from('businesses')
        .select()
        .eq('id', businessId)
        .single();
    final products = await client
        .from('products')
        .select()
        .eq('business_id', businessId)
        .order('created_at');
    final zones = await client
        .from('delivery_zones')
        .select()
        .eq('business_id', businessId)
        .order('name');
    _check();
    return BakerWorkspace(b, rows(products), rows(zones));
  }

  @override
  Future<BakerWorkspace> save(BakerWorkspace w) async {
    _check();
    w.validate();
    await client.rpc(
      'save_baker_workspace',
      params: {
        'p_business_id': businessId,
        'p_revision': w.revision,
        'p_business': w.business,
        'p_products': w.products,
        'p_zones': w.zones,
      },
    );
    return load();
  }

  @override
  Future<BakerWorkspace> activate(BakerWorkspace w) async {
    _check();
    w.validate(activation: true);
    await client.rpc(
      'activate_business',
      params: {'p_business_id': businessId, 'p_revision': w.revision},
    );
    return load();
  }

  @override
  Future<Json> estimate(
    BakerWorkspace w,
    String p,
    String v,
    List<String> o,
    int q,
    String? z,
  ) async {
    _check();
    return Map<String, dynamic>.from(
      await client.rpc(
        'catalog_estimate',
        params: {
          'p_product_id': p,
          'p_variant_id': v,
          'p_option_ids': o,
          'p_quantity': q,
          'p_zone_id': z,
        },
      ),
    );
  }

  Future<void> _queue(String bucket, String path) async {
    final items = preferences.getStringList(_cleanupKey) ?? [];
    final entry = jsonEncode([bucket, path]);
    if (!items.contains(entry)) items.add(entry);
    await preferences.setStringList(_cleanupKey, items);
  }

  @override
  Future<int> retryCleanup() async {
    _check();
    final remaining = <String>[];
    for (final item in preferences.getStringList(_cleanupKey) ?? []) {
      final parts = (jsonDecode(item) as List).cast<String>();
      try {
        _check();
        final business = await client
            .from('businesses')
            .select('image_path,cover_path')
            .eq('id', businessId)
            .single();
        final products = await client
            .from('products')
            .select('image_path')
            .eq('business_id', businessId)
            .eq('image_path', parts[1]);
        if (business['image_path'] == parts[1] ||
            business['cover_path'] == parts[1] ||
            products.isNotEmpty) {
          continue;
        }
        await client.storage.from(parts[0]).remove([parts[1]]);
      } catch (_) {
        remaining.add(item);
      }
    }
    await preferences.setStringList(_cleanupKey, remaining);
    return remaining.length;
  }

  @override
  Future<BakerWorkspace> image(
    BakerWorkspace w,
    String slot,
    String? productId,
    Uint8List? bytes,
    void Function(String) progress,
  ) async {
    _check();
    final bucket = slot == 'product' ? 'product-images' : 'business-images';
    final record = slot == 'product'
        ? w.products.firstWhere((p) => p['id'] == productId)
        : w.business;
    final old =
        record[slot == 'cover' ? 'cover_path' : 'image_path'] as String?;
    String? path;
    if (bytes != null) {
      progress('Checking image');
      final kind = validateImage(bytes);
      path =
          '$businessId/${slot == 'product' ? productId : slot}/${const Uuid().v4()}.${kind.extension}';
      // Persist cleanup intent before upload, so an interrupted upload is retryable.
      await _queue(bucket, path);
      progress('Uploading image');
      _check();
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: kind.mime, upsert: false),
          );
    }
    try {
      progress('Saving image');
      _check();
      await client.rpc(
        'set_baker_image',
        params: {
          'p_business_id': businessId,
          'p_revision': w.revision,
          'p_slot': slot,
          'p_product_id': productId,
          'p_path': path,
        },
      );
    } catch (_) {
      await retryCleanup();
      rethrow;
    }
    // The new path is now referenced: remove cleanup intent before removing old bytes.
    if (path != null) {
      final items = preferences.getStringList(_cleanupKey) ?? [];
      items.remove(jsonEncode([bucket, path]));
      await preferences.setStringList(_cleanupKey, items);
    }
    if (old != null) await _queue(bucket, old);
    await retryCleanup();
    return load();
  }

  @override
  String imageUrl(String path, String slot) => client.storage
      .from(slot == 'product' ? 'product-images' : 'business-images')
      .getPublicUrl(path);
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/discovery.dart';

class SupabaseDiscoveryRepository implements DiscoveryRepository {
  SupabaseDiscoveryRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _session() {
    if (client.auth.currentUser?.id != userId) {
      throw const AuthException('Session changed');
    }
  }

  String? _image(dynamic path) => path == null
      ? null
      : client.storage.from('business-images').getPublicUrl(path as String);
  Bakery _bakery(Map<String, dynamic> p) => Bakery(
    id: p['id'],
    code: p['code'],
    name: p['name'],
    description: p['description'],
    location: p['location'],
    minimum: p['minimum_paisa'],
    pickup: p['pickup_enabled'],
    delivery: p['delivery_enabled'],
    imageUrl: _image(p['image_path']),
    coverUrl: _image(p['cover_path']),
    deliveryZones: [
      for (final z in p['delivery_zones'] ?? [])
        MenuChoice(z['name'], z['fee_paisa'], 'Delivery'),
    ],
  );

  @override
  Future<Bakery?> find(String code) async {
    _session();
    final result = await client.rpc(
      'public_business',
      params: {'p_code': code},
    );
    _session();
    return result == null ? null : _bakery(Map<String, dynamic>.from(result));
  }

  @override
  Future<List<MenuProduct>> menu(String code, {String? after}) async {
    _session();
    final result = await client.rpc(
      'public_menu',
      params: {'p_code': code, 'p_after': after, 'p_limit': 20},
    );
    _session();
    return (result as List)
        .map(
          (p) => MenuProduct(
            p['id'],
            p['name'],
            p['description'],
            p['kind'],
            p['minimum_quantity'],
            List.unmodifiable([
              for (final v in p['variants'])
                MenuChoice(v['label'], v['price_paisa'], 'Size / pack'),
              for (final v in p['options'])
                MenuChoice(v['label'], v['price_paisa'], v['kind']),
            ]),
            p['image_path'] == null
                ? null
                : client.storage
                      .from('product-images')
                      .getPublicUrl(p['image_path']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<SavedBakery>> saved({String? after}) async {
    _session();
    final result = await client.rpc(
      'saved_bakeries',
      params: {'p_after': after, 'p_limit': 20},
    );
    _session();
    return (result as List)
        .map(
          (r) => SavedBakery(
            r['business_id'],
            r['profile'] == null
                ? null
                : _bakery(Map<String, dynamic>.from(r['profile'])),
          ),
        )
        .toList();
  }

  @override
  Future<bool> isSaved(String id) async {
    _session();
    final result = await client
        .from('saved_businesses')
        .select('business_id')
        .eq('user_id', userId)
        .eq('business_id', id)
        .maybeSingle();
    _session();
    return result != null;
  }

  @override
  Future<List<SavedBakery>> recent() async {
    _session();
    final result = await client.rpc('recent_bakeries');
    _session();
    return [
      for (final r in result)
        SavedBakery(
          r['business_id'],
          r['profile'] == null
              ? null
              : _bakery(Map<String, dynamic>.from(r['profile'])),
        ),
    ];
  }

  @override
  Future<void> recordOpen(String id) async {
    _session();
    await client.rpc('record_bakery_open', params: {'p_business_id': id});
    _session();
  }

  @override
  Future<void> save(String id, bool saved) async {
    _session();
    await client.rpc(
      'set_saved_business',
      params: {'p_business_id': id, 'p_saved': saved},
    );
    _session();
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/media/image_validation.dart';
import '../domain/request.dart';

Map<String, dynamic> inputJson(RequestInput x) => {
  'product_id': x.productId,
  'variant_id': x.variantId,
  'option_ids': x.optionIds,
  'quantity': x.quantity,
  'service_date': x.date,
  'fulfilment': x.fulfilment,
  'zone_id': x.zoneId.isEmpty ? null : x.zoneId,
  'address': x.address,
  'contact_name': x.name,
  'phone': x.phone,
  'cake_message': x.message,
  'instructions': x.instructions,
  'attachments': x.attachments,
};
RequestInput readInput(dynamic x) => RequestInput(
  productId: x['product_id'] ?? '',
  variantId: x['variant_id'] ?? '',
  optionIds: List<String>.from(x['option_ids'] ?? []),
  quantity: x['quantity'] ?? 1,
  date: x['service_date'] ?? '',
  fulfilment: x['fulfilment'] ?? 'pickup',
  zoneId: x['zone_id'] ?? '',
  address: x['address'] ?? '',
  name: x['contact_name'] ?? '',
  phone: x['phone'] ?? '',
  message: x['cake_message'] ?? '',
  instructions: x['instructions'] ?? '',
  attachments: List<String>.from(x['attachments'] ?? []),
);
RequestEstimate readEstimate(dynamic x) => RequestEstimate(
  x['subtotal_paisa'],
  x['delivery_paisa'],
  x['total_paisa'],
  [for (final l in x['lines']) EstimateLine(l['label'], l['amount_paisa'])],
);
RequestDraft readDraft(dynamic x) => RequestDraft(
  x['id'],
  x['business_id'],
  x['revision'],
  readInput(x['input']),
  token: x['review_token'],
  estimate: x['review'] == null ? null : readEstimate(x['review']['estimate']),
  orderId: x['submitted_order_id'],
);

class SupabaseRequestRepository implements RequestRepository {
  SupabaseRequestRepository(this.client, this.prefs, this.user, this.project);
  final SupabaseClient client;
  final SharedPreferences prefs;
  final String user, project;
  Future<void> _writes = Future.value();
  String get _prefix => 'requests:$project:$user:';
  void session() {
    if (client.auth.currentUser?.id != user) {
      throw const RequestFailure(
        'Session changed. Sign in again.',
        definite: true,
      );
    }
  }

  Future<T> guarded<T>(Future<T> Function() action) async {
    session();
    try {
      final result = await action();
      session();
      return result;
    } on PostgrestException catch (e) {
      throw RequestFailure(
        switch (e.code) {
          '40001' =>
            'Draft, catalog or price changed. Reload the catalog and review the server estimate again.',
          '23514' =>
            'The date is unavailable or this request is already submitted. Check its saved status.',
          '42501' =>
            'Access denied. Check your account and attachment ownership.',
          '22023' || '22007' || '22008' || '22P02' =>
            'Check selections, date, contact details and minimum order. A catalog option may no longer be available.',
          _ =>
            'Could not complete the request. Check saved status before retrying.',
        },
        definite: {
          '40001',
          '23514',
          '42501',
          '22023',
          '22007',
          '22008',
          '22P02',
        }.contains(e.code),
      );
    }
  }

  @override
  Future<RequestDraft> open(String businessId) => guarded(
    () async => readDraft(
      await client.rpc(
        'open_request_draft',
        params: {'p_business_id': businessId},
      ),
    ),
  );
  @override
  Future<RequestDraft> draft(String id) => guarded(
    () async => readDraft(
      await client.from('request_drafts').select().eq('id', id).single(),
    ),
  );
  @override
  Future<RequestCatalog?> catalog(String businessId, String productId) =>
      guarded(() async {
        final c = await client.rpc(
          'request_catalog',
          params: {'p_business_id': businessId, 'p_product_id': productId},
        );
        if (c == null) return null;
        List<RequestChoice> choices(dynamic list, String kind) => [
          for (final x in list)
            RequestChoice(
              x['id'],
              x['label'] ?? x['name'],
              x['kind'] ?? kind,
              x['price_paisa'] ?? x['fee_paisa'],
            ),
        ];
        final p = c['product'];
        return RequestCatalog(
          p['name'],
          p['kind'],
          c['code'],
          p['minimum_quantity'],
          c['pickup'],
          c['delivery'],
          choices(p['variants'], 'size'),
          choices(p['options'], 'option'),
          choices(c['zones'], 'zone'),
        );
      });
  @override
  Future<RequestDraft> save(RequestDraft d) => guarded(
    () async => readDraft(
      await client.rpc(
        'save_request_draft',
        params: {
          'p_id': d.id,
          'p_revision': d.revision,
          'p_input': inputJson(d.input),
        },
      ),
    ),
  );
  @override
  Future<RequestDraft> review(RequestDraft d) => guarded(
    () async => readDraft(
      await client.rpc(
        'review_request',
        params: {'p_id': d.id, 'p_revision': d.revision},
      ),
    ),
  );
  @override
  Future<String> submit(RequestDraft d) => guarded(
    () async =>
        await client.rpc(
              'submit_request',
              params: {'p_id': d.id, 'p_review_token': d.token},
            )
            as String,
  );
  @override
  Future<DraftCache?> cached(String businessId) async {
    session();
    final raw = prefs.getString('$_prefix$businessId');
    if (raw == null) return null;
    final c = jsonDecode(raw);
    final d = readDraft(c);
    return DraftCache(d, c['uncertain'] == true);
  }

  @override
  Future<void> cache(RequestDraft d, {bool uncertain = false}) {
    session();
    final data = jsonEncode({
      'id': d.id,
      'business_id': d.businessId,
      'revision': d.revision,
      'input': inputJson(d.input),
      'review_token': d.token,
      'review': d.estimate == null
          ? null
          : {
              'estimate': {
                'subtotal_paisa': d.estimate!.subtotal,
                'delivery_paisa': d.estimate!.delivery,
                'total_paisa': d.estimate!.total,
                'lines': [
                  for (final l in d.estimate!.lines)
                    {'label': l.label, 'amount_paisa': l.amount},
                ],
              },
            },
      'submitted_order_id': d.orderId,
      'uncertain': uncertain,
    });
    _writes = _writes.catchError((_) {}).then((_) async {
      session();
      if (!await prefs.setString('$_prefix${d.businessId}', data)) {
        throw const RequestFailure(
          'Could not preserve the draft locally. Keep this page open.',
        );
      }
    });
    return _writes;
  }

  @override
  Future<String> upload(String draftId, Uint8List bytes) => guarded(() async {
    final kind = validateImage(bytes),
        path =
            '$user/$draftId/${const Uuid().v4()}.${validateImage(bytes).extension}';
    final queue = prefs.getStringList('${_prefix}uploads') ?? [];
    if (!await prefs.setStringList('${_prefix}uploads', [...queue, path])) {
      throw const RequestFailure(
        'Could not preserve upload recovery information.',
      );
    }
    await client.rpc(
      'register_request_upload',
      params: {'p_draft_id': draftId, 'p_path': path},
    );
    await client.storage
        .from('order-references')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: kind.mime, upsert: false),
        );
    return path;
  });
  @override
  Future<void> removeUpload(String path) => guarded(() async {
    await client.rpc('retire_request_upload', params: {'p_path': path});
    await client.storage.from('order-references').remove([path]);
    final q = prefs.getStringList('${_prefix}uploads') ?? [];
    q.remove(path);
    await prefs.setStringList('${_prefix}uploads', q);
  });
  @override
  Future<void> cleanup(RequestDraft d) async {
    session();
    // Reconcile authoritative status first. Submitted references are never removed.
    final remote = await draft(d.id);
    if (remote.orderId != null) return;
    for (final p in List<String>.from(
      prefs.getStringList('${_prefix}uploads') ?? [],
    )) {
      if (p.startsWith('$user/${d.id}/') &&
          !d.input.attachments.contains(p) &&
          !remote.input.attachments.contains(p)) {
        await removeUpload(p);
      }
    }
  }

  @override
  Future<String> image(String path) => guarded(
    () => client.storage.from('order-references').createSignedUrl(path, 300),
  );
  RequestRecord _record(dynamic r) {
    final s = r['snapshot'];
    return RequestRecord(
      r['id'],
      r['reference'],
      r['status'],
      r['created_at'],
      s['business_name'],
      s['product_name'],
      readInput(s),
      s['variant']['label'],
      [for (final o in s['options']) o['label'] as String],
      readEstimate(s['estimate']),
      s['timezone'],
      s['zone'] ?? '',
      s['pickup_address'] ?? '',
      version: r['version'] ?? 1,
      currentQuoteVersion: r['current_quote_version'] ?? 1,
      agreedQuoteVersion: r['agreed_quote_version'],
      dueAt: r['due_at'],
    );
  }

  @override
  Future<List<RequestRecord>> orders({String? after}) => guarded(() async {
    var q = client.from('order_requests').select();
    if (after != null) q = q.gt('id', after);
    return [for (final r in await q.order('id').limit(20)) _record(r)];
  });
  @override
  Future<RequestRecord> order(String id) => guarded(
    () async => _record(
      await client.from('order_requests').select().eq('id', id).single(),
    ),
  );
  @override
  Future<List<String>> events(String id) => guarded(() async {
    final requested = await client
        .from('request_events')
        .select('kind,created_at')
        .eq('order_id', id)
        .order('created_at')
        .limit(50);
    final progression = await client
        .from('order_events')
        .select('kind,created_at,details')
        .eq('order_id', id)
        .order('created_at')
        .limit(50);
    final rows = [
      for (final e in requested) (e['kind'], e['created_at'], null),
      for (final e in progression) (e['kind'], e['created_at'], e['details']),
    ]..sort((a, b) => a.$2.toString().compareTo(b.$2.toString()));
    return [
      for (final e in rows)
        if (e.$1 == 'rescheduled' && e.$3 is Map)
          'Rescheduled: ${(e.$3 as Map)['old_date']} ${(e.$3 as Map)['old_due_at']} → ${(e.$3 as Map)['new_date']} ${(e.$3 as Map)['new_due_at']} (${(e.$3 as Map)['timezone']}) · ${e.$2}'
        else
          '${e.$1} · ${e.$2}',
    ];
  });
}

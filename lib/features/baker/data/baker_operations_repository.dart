import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/backend_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/baker_operations.dart';

class BakerOperationsFailure implements Exception {
  const BakerOperationsFailure(this.message);
  final String message;
}

class BakerOperationsRepository {
  BakerOperationsRepository(this.client, this.userId, this.businessId);
  final SupabaseClient client;
  final String userId, businessId;

  void _session() {
    if (client.auth.currentUser?.id != userId) {
      throw const BakerOperationsFailure('Session changed. Sign in again.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    _session();
    try {
      final result = await client.rpc(name, params: params);
      _session();
      return result;
    } on PostgrestException catch (error) {
      throw BakerOperationsFailure(switch (error.code) {
        '40001' => 'This screen is stale. Reload before trying again.',
        '23514' => 'The requested operational change is not available.',
        'quota_reached' => 'The monthly confirmation limit has been reached.',
        '42501' => 'You do not have access to this bakery.',
        _ => 'Could not complete the bakery operation. Retry the request.',
      });
    }
  }

  Future<BakerDay> today([String? date]) async {
    final result = await _rpc('baker_today', {
      'p_business_id': businessId,
      'p_date': date,
    });
    return BakerDay(
      date: result['date'] ?? '',
      timezone: result['timezone'] ?? '',
      pending: result['pending'] ?? 0,
      orders: [
        for (final row in result['orders'] ?? <dynamic>[])
          BakerOrderSummary(
            id: row['id'],
            reference: row['reference'],
            status: row['status'],
            date: row['snapshot']['service_date'],
            name: row['snapshot']['contact_name'] ?? 'Manual customer',
            totalPaisa: row['snapshot']['estimate']['total_paisa'],
            dueAt: row['due_at'],
          ),
      ],
    );
  }

  Future<void> addNote(String orderId, String body) async {
    await _rpc('add_order_private_note', {
      'p_order_id': orderId,
      'p_body': body,
    });
  }

  Future<void> recordAdvance(String orderId, int amountPaisa) async {
    await _rpc('record_order_advance', {
      'p_order_id': orderId,
      'p_amount_paisa': amountPaisa,
    });
  }

  Future<void> addManualOrder({
    required String name,
    required String phone,
    required DateTime date,
    required int totalPaisa,
    bool acknowledgeLeadTime = false,
  }) async {
    await _rpc('add_manual_order', {
      'p_business_id': businessId,
      'p_name': name,
      'p_phone': phone,
      'p_snapshot': const {'product_name': 'Manual order'},
      'p_total_paisa': totalPaisa,
      'p_service_date': date.toIso8601String().substring(0, 10),
      'p_operation_id': const Uuid().v4(),
      'p_acknowledge_lead_time': acknowledgeLeadTime,
    });
  }

  Future<void> saveContact({
    required String name,
    required String phone,
    String notes = '',
  }) async {
    await _rpc('upsert_baker_contact', {
      'p_business_id': businessId,
      'p_name': name,
      'p_phone': phone,
      'p_notes': notes,
    });
  }

  Future<List<BakerContact>> contacts({String query = ''}) async {
    _session();
    final rows = await client
        .from('baker_contacts')
        .select()
        .eq('business_id', businessId)
        .or('display_name.ilike.%$query%,phone_normalized.ilike.%$query%')
        .order('display_name')
        .limit(50);
    return [
      for (final row in rows)
        BakerContact(
          row['id'],
          row['display_name'],
          row['phone_normalized'],
          row['notes'],
        ),
    ];
  }
}

final bakerOperationsRepositoryProvider =
    FutureProvider.autoDispose<BakerOperationsRepository>((ref) async {
      final auth = ref.watch(authControllerProvider);
      final config = ref.watch(backendConfigProvider);
      if (config.isPreview ||
          auth.phase != AuthPhase.signedIn ||
          auth.profile?.businessId == null) {
        throw const BakerOperationsFailure('Sign in as the bakery owner.');
      }
      return BakerOperationsRepository(
        ref.read(supabaseClientProvider),
        auth.identity!.id,
        auth.profile!.businessId!,
      );
    });

final bakerTodayProvider = FutureProvider.autoDispose.family<BakerDay, String?>(
  (ref, date) async {
    final repo = await ref.watch(bakerOperationsRepositoryProvider.future);
    return repo.today(date);
  },
);

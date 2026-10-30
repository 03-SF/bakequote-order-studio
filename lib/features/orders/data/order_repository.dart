import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/order_rules.dart';
import '../domain/order_sync.dart';

class OrderCommandFailure implements Exception {
  const OrderCommandFailure(this.message, this.code);
  final String message;
  final String code;
}

class OrderRepository {
  OrderRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  void _session() {
    if (client.auth.currentUser?.id != userId) {
      throw const OrderCommandFailure(
        'Session changed. Sign in again.',
        'SESSION',
      );
    }
  }

  Future<T> _rpc<T>(String name, Map<String, dynamic> params) async {
    _session();
    try {
      final result = await client.rpc(name, params: params);
      _session();
      return result as T;
    } on PostgrestException catch (error) {
      final code = error.code ?? '';
      throw OrderCommandFailure(switch (code) {
        '40001' =>
          'This screen is stale. Reload the order before trying again.',
        '23514' => 'The order cannot be changed in its current state.',
        'quota_reached' =>
          'The bakery has reached its monthly confirmation limit.',
        '42501' => 'You do not have access to this order.',
        '22023' => error.message,
        _ => 'Could not update the order. Check the connection and retry.',
      }, code);
    }
  }

  Future<Map<String, dynamic>> reviseQuote({
    required String orderId,
    required int expectedVersion,
    required Map<String, dynamic> estimate,
    required String reason,
  }) async => await _rpc<Map<String, dynamic>>('revise_order_quote', {
    'p_order_id': orderId,
    'p_expected_version': expectedVersion,
    'p_estimate': estimate,
    'p_reason': reason,
  });

  Future<Map<String, dynamic>> recordAgreement({
    required String orderId,
    required int quoteVersion,
    required String basis,
    String? messageId,
  }) async => await _rpc<Map<String, dynamic>>('record_order_agreement', {
    'p_order_id': orderId,
    'p_quote_version': quoteVersion,
    'p_basis': basis,
    'p_message_id': messageId,
  });

  Future<List<Map<String, dynamic>>> quotes(String orderId) async {
    _session();
    final rows = await client
        .from('request_quotes')
        .select('version,estimate,reason,created_at')
        .eq('order_id', orderId)
        .order('version');
    _session();
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  Future<Map<String, dynamic>> confirm({
    required String orderId,
    required int expectedVersion,
    required int quoteVersion,
    required String localTime,
    required String operationId,
  }) async => await _rpc<Map<String, dynamic>>('confirm_order_local', {
    'p_order_id': orderId,
    'p_expected_version': expectedVersion,
    'p_quote_version': quoteVersion,
    'p_local_time': localTime,
    'p_operation_id': operationId,
  });

  Future<Map<String, dynamic>> transition({
    required String orderId,
    required int expectedVersion,
    required OrderStatus status,
    required String operationId,
  }) async => await _rpc<Map<String, dynamic>>('transition_order', {
    'p_order_id': orderId,
    'p_expected_version': expectedVersion,
    'p_next_status': status.name,
    'p_operation_id': operationId,
  });

  Future<OrderSyncResult> synchronize({
    int afterSequence = 0,
    int limit = 100,
  }) async {
    final result = await _rpc<dynamic>('sync_order_changes', {
      'p_after_sequence': afterSequence,
      'p_limit': limit,
    });
    final data = Map<String, dynamic>.from(result as Map);
    final changes = (data['changes'] as List<dynamic>? ?? []).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return OrderChange(
        sequence: row['feed_sequence'],
        eventId: row['event_id'],
        orderId: row['order_id'],
        kind: row['kind'],
        status: row['status'],
        version: row['version'],
        createdAt: row['created_at'],
      );
    }).toList();
    return OrderSyncResult(data['cursor'] ?? afterSequence, changes);
  }

  String newOperationId() => const Uuid().v4();

  Future<Map<String, dynamic>> schedule(String id) async =>
      await _rpc<Map<String, dynamic>>('order_schedule_view', {
        'p_order_id': id,
      });

  Future<String?> cancellationStatus(String id) async {
    _session();
    final row = await client
        .from('order_cancellation_requests')
        .select('status')
        .eq('order_id', id)
        .maybeSingle();
    _session();
    return row?['status'] as String?;
  }

  Future<Map<String, dynamic>> reschedule({
    required String id,
    required int version,
    required String date,
    required String time,
    required String operationId,
  }) async => await _rpc<Map<String, dynamic>>('reschedule_order_local', {
    'p_order_id': id,
    'p_expected_version': version,
    'p_service_date': date,
    'p_local_time': time,
    'p_operation_id': operationId,
  });

  Future<Map<String, dynamic>> cancelCommand({
    required String id,
    required int version,
    required String action,
    required String operationId,
  }) async => await _rpc<Map<String, dynamic>>('cancellation_command', {
    'p_order_id': id,
    'p_expected_version': version,
    'p_action': action,
    'p_operation_id': operationId,
  });
}

final orderRepositoryProvider = FutureProvider.autoDispose<OrderRepository>((
  ref,
) async {
  final config = ref.watch(backendConfigProvider);
  final auth = ref.watch(authControllerProvider);
  if (config.isPreview ||
      auth.phase != AuthPhase.signedIn ||
      auth.identity == null) {
    throw const OrderCommandFailure('Sign in to manage orders.', 'AUTH');
  }
  return OrderRepository(ref.read(supabaseClientProvider), auth.identity!.id);
});

final orderQuotesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, orderId) async =>
          (await ref.watch(orderRepositoryProvider.future)).quotes(orderId),
      retry: (_, _) => null,
    );

final orderScheduleProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, id) async =>
          (await ref.watch(orderRepositoryProvider.future)).schedule(id),
      retry: (_, _) => null,
    );
final orderCancellationProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, id) async => (await ref.watch(
        orderRepositoryProvider.future,
      )).cancellationStatus(id),
      retry: (_, _) => null,
    );

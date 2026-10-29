import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/backend_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/billing.dart';

class BillingRepository {
  BillingRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  void _session() {
    if (client.auth.currentUser?.id != userId) {
      throw const BillingFailure('Session changed. Sign in again.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    _session();
    try {
      final result = await client.rpc(name, params: params);
      _session();
      return result;
    } on PostgrestException catch (error) {
      throw BillingFailure(switch (error.code) {
        '22023' => error.message,
        '42501' => 'This account action is not available.',
        _ => 'Could not complete the account action. Retry.',
      });
    }
  }

  Future<Entitlement?> entitlement(String productId) async {
    final row = await _rpc('current_entitlement', {'p_product_id': productId});
    if (row == null) return null;
    final data = Map<String, dynamic>.from(row as Map);
    return Entitlement(
      productId: data['product_id'],
      state: EntitlementState.values.byName(data['state']),
      expiresAt: data['expires_at'],
    );
  }

  Future<String> exportSnapshot() async {
    final data = await _rpc('account_export_snapshot', {});
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<DeletionRequest> requestDeletion() async {
    final row = await _rpc('request_account_deletion', {
      'p_confirmation': 'DELETE',
    });
    final data = Map<String, dynamic>.from(row as Map);
    return DeletionRequest(data['status'], data['requested_at']);
  }
}

final billingRepositoryProvider = FutureProvider.autoDispose<BillingRepository>(
  (ref) async {
    final config = ref.watch(backendConfigProvider);
    final auth = ref.watch(authControllerProvider);
    if (config.isPreview ||
        auth.phase != AuthPhase.signedIn ||
        auth.identity == null) {
      throw const BillingFailure('Sign in to manage account billing.');
    }
    return BillingRepository(
      ref.read(supabaseClientProvider),
      auth.identity!.id,
    );
  },
);

final entitlementProvider = FutureProvider.autoDispose
    .family<Entitlement?, String>(
      (ref, productId) async => (await ref.watch(
        billingRepositoryProvider.future,
      )).entitlement(productId),
    );

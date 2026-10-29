import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/media/image_validation.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/communication.dart';

class CommunicationRepository {
  CommunicationRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  void _session() {
    if (client.auth.currentUser?.id != userId) {
      throw const CommunicationFailure('Session changed. Sign in again.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    _session();
    try {
      final result = await client.rpc(name, params: params);
      _session();
      return result;
    } on PostgrestException catch (error) {
      throw CommunicationFailure(switch (error.code) {
        '42501' => 'Messaging is unavailable for this order.',
        '23514' => 'This communication action is no longer available.',
        '22023' => 'Check the message and try again.',
        _ => 'Could not complete the communication action. Retry.',
      });
    }
  }

  Future<List<OrderMessage>> messages(String orderId) async {
    _session();
    final rows = await client
        .from('order_messages')
        .select('id,sender_id,body,sequence,created_at')
        .eq('order_id', orderId)
        .order('sequence')
        .limit(50);
    return [
      for (final row in rows)
        OrderMessage(
          id: row['id'],
          senderId: row['sender_id'],
          body: row['body'],
          sequence: row['sequence'],
          createdAt: row['created_at'],
        ),
    ];
  }

  Future<String> uploadAttachment(String orderId, Uint8List bytes) async {
    _session();
    final kind = validateImage(bytes);
    final path = '$orderId/${const Uuid().v4()}.${kind.extension}';
    try {
      await client.storage
          .from('conversation-attachments')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: kind.mime, upsert: false),
          );
      return path;
    } on StorageException {
      throw const CommunicationFailure(
        'Could not upload the image. Check access and try again.',
      );
    }
  }

  Future<void> removeAttachment(String path) async {
    _session();
    try {
      await client.storage.from('conversation-attachments').remove([path]);
    } on StorageException {
      throw const CommunicationFailure('Could not remove the image.');
    }
  }

  Future<void> send(
    String orderId,
    String body, {
    List<String> attachmentPaths = const [],
  }) async {
    await _rpc('send_order_message', {
      'p_order_id': orderId,
      'p_client_message_id': const Uuid().v4(),
      'p_body': body,
      'p_attachment_paths': attachmentPaths,
    });
  }

  Future<void> markRead(String orderId, int sequence) async {
    await _rpc('mark_order_messages_read', {
      'p_order_id': orderId,
      'p_sequence': sequence,
    });
  }

  Future<void> report(String orderId, String category, String body) async {
    await _rpc('report_order', {
      'p_order_id': orderId,
      'p_category': category,
      'p_body': body,
    });
  }

  Future<void> block(String orderId) async {
    await _rpc('block_order_participant', {'p_order_id': orderId});
  }

  Future<void> review(String orderId, int rating, String body) async {
    await _rpc('submit_order_review', {
      'p_order_id': orderId,
      'p_rating': rating,
      'p_body': body.trim(),
    });
  }

  Future<List<OrderNotification>> notifications() async {
    _session();
    final rows = await client
        .from('notifications')
        .select('id,order_id,kind,body,created_at,read_at')
        .order('created_at', ascending: false)
        .limit(50);
    return [
      for (final row in rows)
        OrderNotification(
          id: row['id'],
          orderId: row['order_id'] ?? '',
          kind: row['kind'],
          body: row['body'],
          createdAt: row['created_at'],
          readAt: row['read_at'],
        ),
    ];
  }
}

final communicationRepositoryProvider =
    FutureProvider.autoDispose<CommunicationRepository>((ref) async {
      final auth = ref.watch(authControllerProvider);
      final config = ref.watch(backendConfigProvider);
      if (config.isPreview ||
          auth.phase != AuthPhase.signedIn ||
          auth.identity == null) {
        throw const CommunicationFailure('Sign in to use order messaging.');
      }
      return CommunicationRepository(
        ref.read(supabaseClientProvider),
        auth.identity!.id,
      );
    });

final orderMessagesProvider = FutureProvider.autoDispose
    .family<List<OrderMessage>, String>(
      (ref, orderId) async => (await ref.watch(
        communicationRepositoryProvider.future,
      )).messages(orderId),
    );

final notificationsProvider =
    FutureProvider.autoDispose<List<OrderNotification>>(
      (ref) async => (await ref.watch(
        communicationRepositoryProvider.future,
      )).notifications(),
    );

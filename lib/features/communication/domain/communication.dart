class OrderMessage {
  const OrderMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sequence,
    required this.createdAt,
  });
  final String id, senderId, body, createdAt;
  final int sequence;
}

class OrderNotification {
  const OrderNotification({
    required this.id,
    required this.orderId,
    required this.kind,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });
  final String id, orderId, kind, body, createdAt;
  final String? readAt;
}

class CommunicationFailure implements Exception {
  const CommunicationFailure(this.message);
  final String message;
}

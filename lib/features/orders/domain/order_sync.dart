class OrderChange {
  const OrderChange({
    required this.sequence,
    required this.eventId,
    required this.orderId,
    required this.kind,
    required this.status,
    required this.version,
    required this.createdAt,
  });
  final int sequence, version;
  final String eventId, orderId, kind, status, createdAt;
}

class OrderSyncResult {
  const OrderSyncResult(this.cursor, this.changes);
  final int cursor;
  final List<OrderChange> changes;
}

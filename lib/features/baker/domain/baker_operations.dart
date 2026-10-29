class BakerDay {
  const BakerDay({
    required this.date,
    required this.timezone,
    required this.pending,
    required this.orders,
  });
  final String date, timezone;
  final int pending;
  final List<BakerOrderSummary> orders;
}

class BakerOrderSummary {
  const BakerOrderSummary({
    required this.id,
    required this.reference,
    required this.status,
    required this.date,
    required this.name,
    required this.totalPaisa,
    this.dueAt,
  });
  final String id, reference, status, date, name;
  final int totalPaisa;
  final String? dueAt;
}

class BakerContact {
  const BakerContact(this.id, this.name, this.phone, this.notes);
  final String id, name, phone, notes;
}

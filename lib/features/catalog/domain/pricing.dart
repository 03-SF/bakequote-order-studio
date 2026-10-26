/// Money is integer PKR minor units (paisa), never floating point.
class PriceLine {
  PriceLine(this.label, this.amount) {
    if (label.trim().isEmpty || amount < 0) {
      throw ArgumentError('Invalid price line');
    }
  }
  final String label;
  final int amount;
}

class Estimate {
  Estimate({required List<PriceLine> productLines, PriceLine? delivery})
    : lines = List.unmodifiable([...productLines, ?delivery]),
      productSubtotal = productLines.fold(0, (sum, line) => sum + line.amount),
      deliveryFee = delivery?.amount ?? 0;
  final List<PriceLine> lines;
  final int productSubtotal, deliveryFee;
  int get total => productSubtotal + deliveryFee;
}

/// Input amounts must come from a trusted catalog, not editable mobile totals.
/// Phase 5 will calculate and snapshot authoritative prices in PostgreSQL.
Estimate estimate({
  required PriceLine base,
  PriceLine? flavour,
  PriceLine? finish,
  List<PriceLine> extras = const [],
  PriceLine? delivery,
}) => Estimate(
  productLines: [base, ?flavour, ?finish, ...extras],
  delivery: delivery,
);

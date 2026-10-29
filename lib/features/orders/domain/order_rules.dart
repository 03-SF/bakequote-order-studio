import '../../catalog/domain/pricing.dart';

enum OrderStatus {
  pending,
  confirmed,
  baking,
  decorating,
  ready,
  delivered,
  declined,
  withdrawn,
  cancelled,
}

class RuleViolation implements Exception {
  const RuleViolation(this.message);
  final String message;
  @override
  String toString() => message;
}

class Quote {
  Quote(this.version, List<PriceLine> lines)
    : lines = List.unmodifiable(lines) {
    if (version < 1 || lines.isEmpty || total <= 0) {
      throw const RuleViolation('Invalid quotation');
    }
  }
  final int version;
  final List<PriceLine> lines;
  int get total => lines.fold(0, (sum, line) => sum + line.amount);
}

/// Pure advisory rules only: these do not authorize, persist or reserve capacity.
/// Backend transactions, ownership checks, events and idempotency arrive later.
class OrderRules {
  OrderRules({
    required List<Quote> quotes,
    this.status = OrderStatus.pending,
    this.agreedVersion,
    this.manual = false,
    this.cancellationRequested = false,
    this.dueAt,
  }) : quotes = List.unmodifiable(quotes) {
    if (quotes.isEmpty) throw const RuleViolation('Order has no quotation');
  }
  final List<Quote> quotes;
  final OrderStatus status;
  final int? agreedVersion;
  final bool manual, cancellationRequested;
  final DateTime? dueAt;
  Quote get currentQuote => quotes.last;
  bool get isAgreed => agreedVersion == currentQuote.version;
  bool get reservesCapacity => {
    OrderStatus.confirmed,
    OrderStatus.baking,
    OrderStatus.decorating,
    OrderStatus.ready,
    OrderStatus.delivered,
  }.contains(status);
  OrderRules _copy({
    List<Quote>? newQuotes,
    OrderStatus? newStatus,
    int? agreement,
    bool clearAgreement = false,
    bool? cancel,
    DateTime? dueAt,
  }) => OrderRules(
    quotes: newQuotes ?? quotes,
    status: newStatus ?? status,
    manual: manual,
    agreedVersion: clearAgreement ? null : (agreement ?? agreedVersion),
    cancellationRequested: cancel ?? cancellationRequested,
    dueAt: dueAt ?? this.dueAt,
  );
  void _pending() {
    if (status != OrderStatus.pending) {
      throw const RuleViolation('Only pending requests');
    }
  }

  OrderRules agree(int version) {
    _pending();
    if (manual) {
      throw const RuleViolation('Manual orders have no agreement flow');
    }
    if (version != currentQuote.version) {
      throw const RuleViolation('Quotation revised');
    }
    if (isAgreed) throw const RuleViolation('Already agreed');
    return _copy(agreement: version);
  }

  OrderRules revise(List<PriceLine> lines) {
    _pending();
    if (manual) throw const RuleViolation('Manual orders have no quote flow');
    return _copy(
      newQuotes: [...quotes, Quote(currentQuote.version + 1, lines)],
      clearAgreement: true,
    );
  }

  OrderRules confirm({
    required bool online,
    required bool available,
    required String dueTime,
  }) {
    _pending();
    if (manual) throw const RuleViolation('Manual orders use a separate flow');
    if (!online) throw const RuleViolation('Offline');
    if (!isAgreed) throw const RuleViolation('Current quotation not agreed');
    if (!available) throw const RuleViolation('Date unavailable');
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(dueTime)) {
      throw const RuleViolation('Invalid due time');
    }
    return _copy(newStatus: OrderStatus.confirmed);
  }

  OrderRules advance(OrderStatus next) {
    const transitions = {
      OrderStatus.confirmed: OrderStatus.baking,
      OrderStatus.baking: OrderStatus.ready,
      OrderStatus.decorating: OrderStatus.ready,
      OrderStatus.ready: OrderStatus.delivered,
    };
    if (cancellationRequested || transitions[status] != next) {
      throw const RuleViolation('Invalid production transition');
    }
    return _copy(newStatus: next);
  }

  OrderRules decline() {
    _pending();
    return _copy(newStatus: OrderStatus.declined);
  }

  bool canBakerTransition(OrderStatus next) =>
      {
        OrderStatus.confirmed: OrderStatus.baking,
        OrderStatus.baking: OrderStatus.ready,
        OrderStatus.decorating: OrderStatus.ready,
        OrderStatus.ready: OrderStatus.delivered,
      }[status] ==
      next;

  OrderRules withdraw() {
    _pending();
    if (manual) {
      throw const RuleViolation('Manual orders cannot be withdrawn');
    }
    return _copy(newStatus: OrderStatus.withdrawn);
  }

  OrderRules requestCancellation() {
    if (cancellationRequested ||
        !{OrderStatus.confirmed, OrderStatus.baking}.contains(status)) {
      throw const RuleViolation('Cancellation unavailable');
    }
    return _copy(cancel: true);
  }

  OrderRules resolveCancellation({required bool approve}) {
    if (!cancellationRequested) {
      throw const RuleViolation('No open cancellation request');
    }
    return _copy(
      cancel: false,
      newStatus: approve ? OrderStatus.cancelled : status,
    );
  }

  bool canReview({
    required String actorId,
    required String customerId,
    required bool reviewed,
  }) =>
      !manual &&
      status == OrderStatus.delivered &&
      actorId == customerId &&
      !reviewed;
}

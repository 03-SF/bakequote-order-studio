import 'package:flutter_test/flutter_test.dart';
import 'package:bakequote_mobile/features/catalog/domain/pricing.dart';
import 'package:bakequote_mobile/features/orders/domain/order_rules.dart';

void main() {
  List<PriceLine> product() => [
    PriceLine('Cake', 300000),
    PriceLine('Buttercream', 50000),
    PriceLine('Topper', 30000),
  ];
  OrderRules pending() => OrderRules(
    quotes: [
      Quote(1, [...product(), PriceLine('Delivery', 30000)]),
    ],
  );
  test('Reference itemized estimate: 3800 + 300 = 4100 PKR', () {
    final e = estimate(
      base: product()[0],
      finish: product()[1],
      extras: [product()[2]],
      delivery: PriceLine('Delivery', 30000),
    );
    expect(e.productSubtotal, 380000);
    expect(e.deliveryFee, 30000);
    expect(e.total, 410000);
    expect(estimate(base: product()[0]).total, 300000);
    expect(() => PriceLine('Invalid', -1), throwsArgumentError);
  });
  test(
    'No quotation fails clearly',
    () => expect(() => OrderRules(quotes: []), throwsA(isA<RuleViolation>())),
  );
  test(
    'Revision invalidates specific-version agreement and preserves history',
    () {
      final agreed = pending().agree(1);
      final revised = agreed.revise([
        ...agreed.currentQuote.lines,
        PriceLine('Design', 40000),
      ]);
      expect(agreed.isAgreed, isTrue);
      expect(revised.isAgreed, isFalse);
      expect(revised.currentQuote.total, 450000);
      expect(revised.quotes.first.total, 410000);
      expect(() => revised.agree(1), throwsA(isA<RuleViolation>()));
      expect(() => agreed.agree(1), throwsA(isA<RuleViolation>()));
    },
  );
  test('Agreement, availability, connection and valid time required', () {
    OrderRules confirm(
      OrderRules o, {
      bool online = true,
      bool available = true,
      String time = '16:00',
    }) => o.confirm(online: online, available: available, dueTime: time);
    expect(() => confirm(pending()), throwsA(isA<RuleViolation>()));
    final agreed = pending().agree(1);
    expect(() => confirm(agreed, online: false), throwsA(isA<RuleViolation>()));
    expect(
      () => confirm(agreed, available: false),
      throwsA(isA<RuleViolation>()),
    );
    for (final time in ['25:00', '12:60', 'oops']) {
      expect(() => confirm(agreed, time: time), throwsA(isA<RuleViolation>()));
    }
    expect(pending().reservesCapacity, isFalse);
    final c = confirm(agreed);
    expect(c.reservesCapacity, isTrue);
    expect(() => confirm(c), throwsA(isA<RuleViolation>()));
    expect(
      () => c.advance(OrderStatus.delivered),
      throwsA(isA<RuleViolation>()),
    );
    expect(
      c
          .advance(OrderStatus.baking)
          .advance(OrderStatus.decorating)
          .advance(OrderStatus.ready)
          .advance(OrderStatus.delivered)
          .status,
      OrderStatus.delivered,
    );
  });
  test('Cancellation request is distinct from cancellation', () {
    final c = pending()
        .agree(1)
        .confirm(online: true, available: true, dueTime: '16:00');
    final r = c.requestCancellation();
    expect(r.status, OrderStatus.confirmed);
    expect(() => r.advance(OrderStatus.baking), throwsA(isA<RuleViolation>()));
    expect(r.resolveCancellation(approve: true).status, OrderStatus.cancelled);
    expect(r.resolveCancellation(approve: false).status, OrderStatus.confirmed);
  });
  test('Only owning customer reviews a delivered app order', () {
    final delivered = OrderRules(
      quotes: pending().quotes,
      status: OrderStatus.delivered,
    );
    expect(
      delivered.canReview(actorId: 'sara', customerId: 'sara', reviewed: false),
      isTrue,
    );
    expect(
      delivered.canReview(
        actorId: 'other',
        customerId: 'sara',
        reviewed: false,
      ),
      isFalse,
    );
    expect(
      delivered.canReview(actorId: 'sara', customerId: 'sara', reviewed: true),
      isFalse,
    );
    expect(
      OrderRules(
        quotes: pending().quotes,
        status: OrderStatus.delivered,
        manual: true,
      ).canReview(actorId: 'sara', customerId: 'sara', reviewed: false),
      isFalse,
    );
  });
}

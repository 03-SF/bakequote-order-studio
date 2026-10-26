import 'dart:convert';

typedef Json = Map<String, dynamic>;
List<Json> rows(dynamic value) =>
    (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class BakerWorkspace {
  BakerWorkspace(this.business, this.products, this.zones);
  final Json business;
  final List<Json> products, zones;
  factory BakerWorkspace.fromJson(Json value) => BakerWorkspace(
    Map<String, dynamic>.from(value['business']),
    rows(value['products']),
    rows(value['zones']),
  );
  Json toJson() => {'business': business, 'products': products, 'zones': zones};
  BakerWorkspace copy() =>
      BakerWorkspace.fromJson(jsonDecode(jsonEncode(toJson())));
  String get id => business['id'];
  int get revision => business['revision'];
  bool get active => business['onboarding_complete'] == true;
  List<String> get setupIssues {
    final issues = <String>[];
    for (final field in [
      'name',
      'description',
      'owner_name',
      'contact_phone',
      'location',
    ]) {
      if ((business[field] as String? ?? '').trim().isEmpty) {
        issues.add('Complete ${field.replaceAll('_', ' ')}');
      }
    }
    if (business['pickup_enabled'] != true &&
        business['delivery_enabled'] != true) {
      issues.add('Enable pickup or delivery');
    }
    if (business['pickup_enabled'] == true &&
        (business['pickup_address'] as String? ?? '').trim().isEmpty) {
      issues.add('Enter the pickup address');
    }
    if (business['delivery_enabled'] == true &&
        !zones.any((z) => z['active'] == true)) {
      issues.add('Add an active delivery zone');
    }
    return issues;
  }

  void validate({bool activation = false}) {
    if (activation || active) {
      if (setupIssues.isNotEmpty) throw FormatException(setupIssues.join('. '));
    }
    bounded(business['name'], 100, 'Business name');
    bounded(business['description'], 2000, 'Description', required: false);
    bounded(business['owner_name'], 100, 'Owner name', required: false);
    bounded(business['contact_phone'], 40, 'Contact phone', required: false);
    bounded(business['location'], 200, 'Location', required: false);
    bounded(business['pickup_address'], 500, 'Pickup address', required: false);
    money(business['minimum_paisa']);
    final ids = <String>{};
    for (final p in products) {
      if (!ids.add(p['id'])) throw const FormatException('Duplicate product');
      validateProduct(p);
    }
    for (final z in zones) {
      bounded(z['name'], 100, 'Zone name');
      money(z['fee_paisa']);
    }
  }
}

void bounded(dynamic value, int max, String label, {bool required = true}) {
  if (value is! String ||
      value.length > max ||
      (required && value.trim().isEmpty)) {
    throw FormatException(
      '$label must contain ${required ? '1' : '0'} to $max characters',
    );
  }
}

void money(dynamic value) {
  if (value is! int || value < 0 || value > 100000000000) {
    throw const FormatException(
      'Enter a nonnegative price up to PKR 1,000,000,000',
    );
  }
}

void validateProduct(Json p) {
  bounded(p['name'], 100, 'Product name');
  bounded(p['description'], 2000, 'Product description', required: false);
  if (!['cake', 'cupcakes'].contains(p['kind'])) {
    throw const FormatException('Choose cake or cupcakes');
  }
  if (p['minimum_quantity'] is! int ||
      p['minimum_quantity'] < 1 ||
      p['minimum_quantity'] > 10000) {
    throw const FormatException('Minimum quantity must be 1 to 10,000');
  }
  final variants = rows(p['variants']),
      options = rows(p['options']),
      ids = <String>{};
  if (variants.length > 200 || options.length > 200) {
    throw const FormatException('Too many options');
  }
  for (final o in [...variants, ...options]) {
    if (!ids.add(o['id'])) throw const FormatException('Duplicate option');
    bounded(o['label'], 100, 'Option name');
    money(o['price_paisa']);
    if (o['active'] is! bool) {
      throw const FormatException('Choose availability');
    }
  }
  for (final v in variants) {
    if (v['units'] is! int || v['units'] < 1 || v['units'] > 999999) {
      throw const FormatException('Size/pack quantity must be 1 to 999,999');
    }
  }
  for (final o in options) {
    if (!['flavour', 'finish', 'extra'].contains(o['kind'])) {
      throw const FormatException('Invalid customization');
    }
  }
  if (p['active'] == true && !variants.any((v) => v['active'] == true)) {
    throw const FormatException(
      'Add an active size or pack before activating this product',
    );
  }
}

int parsePkr(String input) {
  final match = RegExp(
    r'^(\d{1,10})(?:\.(\d{1,2}))?$',
  ).firstMatch(input.trim());
  if (match == null) {
    throw const FormatException('Enter PKR with up to two decimal places');
  }
  final value =
      int.parse(match[1]!) * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
  money(value);
  return value;
}

String pkrInput(int value) =>
    '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
String pkr(int value) => 'PKR ${pkrInput(value)}';
Json previewEstimate(
  BakerWorkspace w,
  String productId,
  String variantId,
  List<String> optionIds,
  int quantity,
  String? zoneId,
) {
  final p = w.products.where((p) => p['id'] == productId).firstOrNull;
  if (p == null ||
      p['active'] != true ||
      quantity < p['minimum_quantity'] ||
      quantity > 10000) {
    throw const FormatException(
      'Product unavailable or minimum quantity not met',
    );
  }
  final v = rows(
    p['variants'],
  ).where((v) => v['id'] == variantId && v['active'] == true).firstOrNull;
  if (v == null) throw const FormatException('Size or pack unavailable');
  var subtotal = v['price_paisa'] as int;
  final seen = <String>{};
  var flavours = 0, finishes = 0;
  for (final id in optionIds) {
    if (!seen.add(id)) throw const FormatException('Duplicate selection');
    final o = rows(
      p['options'],
    ).where((o) => o['id'] == id && o['active'] == true).firstOrNull;
    if (o == null) {
      throw const FormatException('Option unavailable for product');
    }
    if (o['kind'] == 'flavour') flavours++;
    if (o['kind'] == 'finish') finishes++;
    subtotal += o['price_paisa'] as int;
  }
  if (flavours > 1 || finishes > 1) {
    throw const FormatException('Choose at most one flavour and finish');
  }
  if (subtotal > 9007199254740991 ~/ quantity) {
    throw const FormatException('Estimate is too large to display exactly');
  }
  subtotal *= quantity;
  if (subtotal < w.business['minimum_paisa']) {
    throw const FormatException('Minimum order value not met');
  }
  var delivery = 0;
  if (zoneId == null) {
    if (w.business['pickup_enabled'] != true) {
      throw const FormatException('Pickup unavailable');
    }
  } else {
    final z = w.zones
        .where((z) => z['id'] == zoneId && z['active'] == true)
        .firstOrNull;
    if (w.business['delivery_enabled'] != true || z == null) {
      throw const FormatException('Delivery zone unavailable');
    }
    delivery = z['fee_paisa'];
  }
  if (delivery > 9007199254740991 - subtotal) {
    throw const FormatException('Estimate is too large to display exactly');
  }
  return {
    'subtotal_paisa': subtotal,
    'delivery_paisa': delivery,
    'total_paisa': subtotal + delivery,
    'currency': 'PKR',
    'business_revision': w.revision,
  };
}

String? bakeryCode(String input) {
  var value = input.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.scheme.isNotEmpty) {
    if (uri.scheme == 'http' &&
        uri.host == 'localhost' &&
        uri.port == 7357 &&
        uri.path == '/' &&
        uri.fragment.startsWith('/bakery/')) {
      return bakeryCode(uri.fragment.substring('/bakery/'.length));
    }
    if (uri.scheme != 'dev.bakequote.mobile' ||
        uri.host != 'bakery' ||
        uri.pathSegments.length != 1 ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    value = uri.pathSegments.single;
  }
  value = value.toUpperCase();
  return RegExp(r'^[A-F0-9]{32}$').hasMatch(value) ? value : null;
}

String paisaText(int value) =>
    'PKR ${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';

class Bakery {
  const Bakery({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.location,
    required this.minimum,
    required this.pickup,
    required this.delivery,
    this.imageUrl,
    this.coverUrl,
    this.deliveryZones = const [],
  });
  final String id, code, name, description, location;
  final int minimum;
  final bool pickup, delivery;
  final String? imageUrl, coverUrl;
  final List<MenuChoice> deliveryZones;
  String get sharedLink => 'dev.bakequote.mobile://bakery/$code';
}

class MenuChoice {
  const MenuChoice(this.label, this.price, this.kind);
  final String label, kind;
  final int price;
}

class MenuProduct {
  const MenuProduct(
    this.id,
    this.name,
    this.description,
    this.kind,
    this.minimumQuantity,
    this.choices,
    this.imageUrl,
  );
  final String id, name, description, kind;
  final int minimumQuantity;
  final List<MenuChoice> choices;
  final String? imageUrl;
  int? get startingPrice {
    final prices = choices
        .where((c) => c.kind == 'Size / pack')
        .map((c) => c.price);
    return prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
  }
}

class SavedBakery {
  const SavedBakery(this.id, this.profile);
  final String id;
  final Bakery? profile;
}

abstract interface class DiscoveryRepository {
  Future<Bakery?> find(String code);
  Future<List<MenuProduct>> menu(String code, {String? after});
  Future<List<SavedBakery>> saved({String? after});
  Future<bool> isSaved(String id);
  Future<void> save(String id, bool saved);
  Future<List<SavedBakery>> recent();
  Future<void> recordOpen(String id);
}

import 'dart:typed_data';

class RequestInput {
  const RequestInput({
    required this.productId,
    this.variantId = '',
    this.optionIds = const [],
    this.quantity = 1,
    this.date = '',
    this.fulfilment = 'pickup',
    this.zoneId = '',
    this.address = '',
    this.name = '',
    this.phone = '',
    this.message = '',
    this.instructions = '',
    this.attachments = const [],
  });
  final String productId,
      variantId,
      date,
      fulfilment,
      zoneId,
      address,
      name,
      phone,
      message,
      instructions;
  final int quantity;
  final List<String> optionIds, attachments;
  RequestInput copy({
    String? productId,
    String? variantId,
    List<String>? optionIds,
    int? quantity,
    String? date,
    String? fulfilment,
    String? zoneId,
    String? address,
    String? name,
    String? phone,
    String? message,
    String? instructions,
    List<String>? attachments,
  }) => RequestInput(
    productId: productId ?? this.productId,
    variantId: variantId ?? this.variantId,
    optionIds: optionIds ?? this.optionIds,
    quantity: quantity ?? this.quantity,
    date: date ?? this.date,
    fulfilment: fulfilment ?? this.fulfilment,
    zoneId: zoneId ?? this.zoneId,
    address: address ?? this.address,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    message: message ?? this.message,
    instructions: instructions ?? this.instructions,
    attachments: attachments ?? this.attachments,
  );
  String? validate(int step) {
    if (step == 0 && (variantId.isEmpty || quantity < 1 || quantity > 10000)) {
      return 'Choose a size or pack and a valid quantity.';
    }
    if (step == 1) {
      if (!['pickup', 'delivery'].contains(fulfilment) ||
          address.length > 500) {
        return 'Choose pickup or delivery and check the address length.';
      }
      final d = DateTime.tryParse(date);
      if (d == null || d.toIso8601String().substring(0, 10) != date) {
        return 'Choose a valid service date (YYYY-MM-DD).';
      }
      if (fulfilment == 'delivery' &&
          (zoneId.isEmpty || address.trim().isEmpty)) {
        return 'Choose a delivery zone and enter the address.';
      }
    }
    if (step == 2 &&
        (name.trim().isEmpty ||
            name.length > 100 ||
            phone.trim().length < 3 ||
            phone.length > 40 ||
            instructions.length > 2000 ||
            message.length > 200 ||
            attachments.length > 3)) {
      return 'Complete contact details and check text/image limits.';
    }
    return null;
  }
}

class RequestChoice {
  const RequestChoice(this.id, this.label, this.kind, this.price);
  final String id, label, kind;
  final int price;
}

class RequestCatalog {
  const RequestCatalog(
    this.name,
    this.kind,
    this.code,
    this.minimum,
    this.pickup,
    this.delivery,
    this.variants,
    this.options,
    this.zones,
  );
  final String name, kind, code;
  final int minimum;
  final bool pickup, delivery;
  final List<RequestChoice> variants, options, zones;
  bool accepts(RequestInput input) =>
      input.quantity >= minimum &&
      variants.any((v) => v.id == input.variantId) &&
      input.optionIds.every((id) => options.any((o) => o.id == id));
}

class EstimateLine {
  const EstimateLine(this.label, this.amount);
  final String label;
  final int amount;
}

class RequestEstimate {
  const RequestEstimate(this.subtotal, this.delivery, this.total, this.lines);
  final int subtotal, delivery, total;
  final List<EstimateLine> lines;
}

class RequestDraft {
  const RequestDraft(
    this.id,
    this.businessId,
    this.revision,
    this.input, {
    this.token,
    this.estimate,
    this.orderId,
  });
  final String id, businessId;
  final int revision;
  final RequestInput input;
  final String? token, orderId;
  final RequestEstimate? estimate;
  RequestDraft edited(RequestInput input) =>
      RequestDraft(id, businessId, revision, input);
}

class DraftCache {
  const DraftCache(this.draft, this.uncertain);
  final RequestDraft draft;
  final bool uncertain;
}

class RequestRecord {
  const RequestRecord(
    this.id,
    this.reference,
    this.status,
    this.created,
    this.businessName,
    this.productName,
    this.input,
    this.variant,
    this.options,
    this.estimate,
    this.timezone,
    this.zone,
    this.pickupAddress, {
    this.version = 1,
    this.currentQuoteVersion = 1,
    this.agreedQuoteVersion,
    this.dueAt,
  });
  final String id,
      reference,
      status,
      created,
      businessName,
      productName,
      variant;
  final RequestInput input;
  final List<String> options;
  final RequestEstimate estimate;
  final String timezone, zone, pickupAddress;
  final int version, currentQuoteVersion;
  final int? agreedQuoteVersion;
  final String? dueAt;
}

class RequestFailure implements Exception {
  const RequestFailure(this.message, {this.definite = false});
  final String message;
  final bool definite;
}

abstract interface class RequestRepository {
  Future<RequestDraft> open(String businessId);
  Future<RequestDraft> draft(String id);
  Future<RequestCatalog?> catalog(String businessId, String productId);
  Future<RequestDraft> save(RequestDraft draft);
  Future<RequestDraft> review(RequestDraft draft);
  Future<String> submit(RequestDraft draft);
  Future<DraftCache?> cached(String businessId);
  Future<void> cache(RequestDraft draft, {bool uncertain = false});
  Future<String> upload(String draftId, Uint8List bytes);
  Future<void> cleanup(RequestDraft draft);
  Future<void> removeUpload(String path);
  Future<String> image(String path);
  Future<List<RequestRecord>> orders({String? after});
  Future<RequestRecord> order(String id);
  Future<List<String>> events(String id);
}

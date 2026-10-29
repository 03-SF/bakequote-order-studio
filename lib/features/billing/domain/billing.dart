enum EntitlementState { active, grace, expired, revoked }

class Entitlement {
  const Entitlement({
    required this.productId,
    required this.state,
    required this.expiresAt,
  });
  final String productId;
  final EntitlementState state;
  final String? expiresAt;
  bool get available =>
      state == EntitlementState.active || state == EntitlementState.grace;
}

class DeletionRequest {
  const DeletionRequest(this.status, this.requestedAt);
  final String status, requestedAt;
}

class BillingFailure implements Exception {
  const BillingFailure(this.message);
  final String message;
}

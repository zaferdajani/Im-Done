import '../../core/flags.dart';

/// The single door to in-app purchases. Apple 3.1.1 / Play Billing: in the
/// native apps digital plans may only be sold through the platform store, so
/// no Stripe or external checkout exists in this codebase. Wire a real
/// implementation (RevenueCat `purchases_flutter`, free tier, or
/// `in_app_purchase`) behind this interface and set PURCHASES_ENABLED=true.
abstract class PurchaseService {
  /// True when buying is possible on this build.
  bool get available;

  /// Re-fetches existing purchases from the store. Returns how many
  /// entitlements were restored (0 = nothing to restore).
  Future<int> restore();
}

/// Default: no store product is live yet, so nothing can be bought and
/// restoring finds nothing. Replace when products exist in the stores.
class NoopPurchaseService implements PurchaseService {
  const NoopPurchaseService();
  @override
  bool get available => Flags.purchasesEnabled;
  @override
  Future<int> restore() async => 0;
}

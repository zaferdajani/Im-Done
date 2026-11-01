import 'package:flutter/foundation.dart';

/// Feature flags. Anything unfinished is visible in debug builds only, so a
/// store build never shows a "coming soon" / placeholder screen.
class Flags {
  Flags._();

  /// "Purchases will be available soon" style copy.
  static const bool showComingSoon = kDebugMode;

  /// Set true only once a real StoreKit / Play Billing implementation of
  /// [PurchaseService] is wired in (see docs/APP_STORE_COMPLIANCE.md).
  static const bool purchasesEnabled = bool.fromEnvironment('PURCHASES_ENABLED');
}

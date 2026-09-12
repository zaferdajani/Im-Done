import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// The one switch every cloud feature checks. Personal tasks never need it.
class Cloud {
  static bool available = false;

  /// Public web client id used by Google Sign-In on Android to mint an ID
  /// token Firebase accepts. Filled in by the setup step (README).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// Where invite links point. The page there must serve the AASA /
  /// assetlinks files (see docs/STORE_COMPLIANCE.md) and fall back to the
  /// store listing when the app is not installed.
  static const String inviteBaseUrl = String.fromEnvironment(
    'INVITE_BASE_URL',
    defaultValue: 'https://doneby.me/j',
  );

  static const String privacyPolicyUrl = 'https://doneby.me/privacy';
  static const String termsUrl = 'https://doneby.me/terms';
  static const String deleteAccountWebUrl = 'https://doneby.me/delete-account';

  static Future<void> init() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      available = false;
      return;
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      available = true;
    } catch (e) {
      debugPrint('Firebase unavailable: $e');
      available = false;
    }
  }
}

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
    defaultValue: 'https://zaferdajani.github.io/Im-Done/j',
  );

  /// Personal-code links (QR + share): /p/CODE opens "add this person".
  static const String personBaseUrl = 'https://zaferdajani.github.io/Im-Done/p';

  /// The push sender (Cloudflare Worker in push-worker/). Empty = no pushes,
  /// everything else still works. Set at build time or after deploy.
  static const String pushEndpoint = String.fromEnvironment(
    'PUSH_ENDPOINT',
    defaultValue: 'https://imdone-push.zaferdajani.workers.dev',
  );

  static const String privacyPolicyUrl = 'https://imdone.me/privacy';
  static const String termsUrl = 'https://imdone.me/terms';
  static const String deleteAccountWebUrl = 'https://imdone.me/delete-account';

  /// Store links for the invite landing page. Placeholders until the app is
  /// listed; until then Android testers get the CI build from GitHub.
  static const String playStoreUrl = 'https://github.com/zaferdajani/Im-Done/actions/workflows/app.yml';
  static const String appStoreUrl = 'https://github.com/zaferdajani/Im-Done';
  static const String webAppUrl = 'https://zaferdajani.github.io/Im-Done/';

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

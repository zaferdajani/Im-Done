// Placeholder. Run `flutterfire configure` (see README) to replace this file
// with the real per-platform options. Until then the app boots in
// personal-only mode: everything works except sharing.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static bool get isConfigured => false;

  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Firebase is not configured for this build.');
}

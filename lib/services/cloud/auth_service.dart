import 'dart:convert';
import '../../core/platform.dart';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'cloud.dart';

/// Identity for SHARED tasks only. Two providers, both "social" in the store
/// sense: Google, and Sign in with Apple (required by App Store guideline 4.8
/// whenever another third-party login is offered).
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> get changes => Cloud.available ? _auth.authStateChanges() : const Stream.empty();
  User? get current => Cloud.available ? _auth.currentUser : null;

  bool _googleReady = false;

  Future<User?> signInWithGoogle() async {
    if (isWeb) {
      // Firebase's own popup: no OAuth client id to configure on the web.
      final result = await _auth.signInWithPopup(GoogleAuthProvider());
      return result.user;
    }
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(
        serverClientId: Cloud.googleServerClientId.isEmpty ? null : Cloud.googleServerClientId,
      );
      _googleReady = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final cred = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(cred);
    return result.user;
  }

  static bool get appleAvailable => isApple;

  Future<User?> signInWithApple() async {
    final rawNonce = _randomNonce();
    final hashed = sha256.convert(utf8.encode(rawNonce)).toString();
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: hashed,
    );
    final cred = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      rawNonce: rawNonce,
    );
    final result = await _auth.signInWithCredential(cred);
    final user = result.user;
    // Apple only sends the name on the FIRST sign-in; keep it.
    if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
      final name = [apple.givenName, apple.familyName].whereType<String>().join(' ').trim();
      if (name.isNotEmpty) await user.updateDisplayName(name);
    }
    return user;
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// App Store 5.1.1(v) / Play account-deletion policy: the whole account and
  /// its data go, from inside the app. The server function removes the
  /// user's memberships, the shared tasks they own, their tokens, and the
  /// Auth user itself — so a stale client can never leave half a record.
  Future<void> deleteAccount() async {
    await FirebaseFunctions.instance.httpsCallable('deleteAccount').call<void>();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  String _randomNonce([int length = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

import 'dart:convert';
import '../../core/platform.dart';
import 'dart:math';

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

  /// The fastest door: an account with no email or password. The person
  /// types a name and is in. They can attach Google later (`linkGoogle`) to
  /// keep the same account on another phone.
  Future<User?> signInQuick(String displayName) async {
    final result = await _auth.signInAnonymously();
    final user = result.user;
    if (user != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
    }
    return _auth.currentUser;
  }

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Email + password. Signs in if the address is known, otherwise creates
  /// the account. A quick (anonymous) account is LINKED instead, so its
  /// tasks and code are kept.
  Future<User?> signInWithEmail(String email, String password, {String? displayName}) async {
    final e = email.trim();
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      final r = await current.linkWithCredential(EmailAuthProvider.credential(email: e, password: password));
      return r.user;
    }
    try {
      final r = await _auth.signInWithEmailAndPassword(email: e, password: password);
      return r.user;
    } on FirebaseAuthException catch (ex) {
      if (ex.code != 'user-not-found' && ex.code != 'invalid-credential') rethrow;
      // Unknown address (invalid-credential is what newer SDKs return for it
      // too): create the account. A wrong password on a known address fails
      // here with email-already-in-use, which is the honest answer.
      final r = await _auth.createUserWithEmailAndPassword(email: e, password: password);
      final user = r.user;
      if (user != null && displayName != null && displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
      }
      return _auth.currentUser;
    }
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  /// Attach Google to a quick account so it survives a new phone.
  Future<User?> linkGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    if (isWeb) {
      final r = await user.linkWithPopup(GoogleAuthProvider());
      return r.user;
    }
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(
        serverClientId: Cloud.googleServerClientId.isEmpty ? null : Cloud.googleServerClientId,
      );
      _googleReady = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final r = await user.linkWithCredential(GoogleAuthProvider.credential(idToken: account.authentication.idToken));
    return r.user;
  }

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
  /// Throws [FirebaseAuthException] with code `requires-recent-login` when
  /// the sign-in is too old; the caller re-authenticates and retries.
  Future<void> deleteAccount(Future<void> Function(String uid) eraseData) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await eraseData(user.uid);
    await user.delete();
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

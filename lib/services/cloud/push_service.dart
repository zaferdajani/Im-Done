import '../../core/platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this device for pushes about SHARED tasks (new task, someone
/// marked it done, creator confirmed). Local reminders never use push.
class PushService {
  Future<void> register(String uid, {required String languageCode, required String displayName}) async {
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission(alert: true, badge: true, sound: true);
    final token = await fm.getToken();
    if (token != null) await _save(uid, token, languageCode, displayName);
    fm.onTokenRefresh.listen((t) => _save(uid, t, languageCode, displayName));
  }

  Future<void> _save(String uid, String token, String languageCode, String displayName) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'displayName': displayName,
      'languageCode': languageCode,
      'platform': isWeb ? 'web' : (isIOS ? 'ios' : 'android'),
      'tokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unregister(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'tokens': FieldValue.arrayRemove([token]),
      });
    } catch (_) {}
  }
}

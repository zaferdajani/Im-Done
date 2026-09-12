import '../../core/platform.dart';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cloud.dart';

/// Registers this device for pushes about SHARED tasks (new task, someone
/// marked it done, creator confirmed). Local reminders never use push.
class PushService {
  Future<void> register(String uid, {required String languageCode, required String displayName}) async {
    // Web push needs a VAPID key + service worker; not set up yet, so the web
    // app keeps its profile fresh but registers no device token.
    if (isWeb) {
      await _save(uid, null, languageCode, displayName);
      return;
    }
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission(alert: true, badge: true, sound: true);
    final token = await fm.getToken();
    if (token != null) await _save(uid, token, languageCode, displayName);
    fm.onTokenRefresh.listen((t) => _save(uid, t, languageCode, displayName));
  }

  Future<void> _save(String uid, String? token, String languageCode, String displayName) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'displayName': displayName,
      'languageCode': languageCode,
      'platform': isWeb ? 'web' : (isIOS ? 'ios' : 'android'),
      if (token != null) 'tokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Asks the push sender to tell the right members about an event. The
  /// sender re-checks membership itself; this call is best-effort and never
  /// blocks the action that triggered it.
  Future<void> notify(String kind, String taskId, {String? toUid}) async {
    if (Cloud.pushEndpoint.isEmpty) return;
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) return;
      final res = await http
          .post(
            Uri.parse('${Cloud.pushEndpoint}/notify'),
            headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
            body: jsonEncode({'kind': kind, 'taskId': taskId, if (toUid != null) 'toUid': toUid}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) debugPrint('push sender: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('push sender unreachable: $e');
    }
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

import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform.dart';

/// True while the device can reach the internet. Dependency-free: a cheap DNS
/// lookup every 15 seconds. On the web the browser handles it, so we report
/// online.
final onlineProvider = StreamProvider<bool>((ref) async* {
  if (isWeb) {
    yield true;
    return;
  }
  Future<bool> probe() async {
    try {
      final r = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 4));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  yield await probe();
  yield* Stream.periodic(const Duration(seconds: 15)).asyncMap((_) => probe());
});

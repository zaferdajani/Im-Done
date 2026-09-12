import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Platform checks that are safe on the web (dart:io's Platform throws there).
bool get isWeb => kIsWeb;
bool get isIOS => !kIsWeb && Platform.isIOS;
bool get isAndroid => !kIsWeb && Platform.isAndroid;
bool get isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

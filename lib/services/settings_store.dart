import 'package:shared_preferences/shared_preferences.dart';

/// Small, per-device preferences.
class AppSettings {
  const AppSettings({
    required this.languageCode, // null = follow the system
    required this.onboarded,
    required this.displayName,
  });

  final String? languageCode;
  final bool onboarded;
  final String displayName;

  AppSettings copyWith({String? languageCode, bool clearLanguage = false, bool? onboarded, String? displayName}) =>
      AppSettings(
        languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
        onboarded: onboarded ?? this.onboarded,
        displayName: displayName ?? this.displayName,
      );

  static const empty = AppSettings(languageCode: null, onboarded: false, displayName: '');
}

class SettingsStore {
  static const _kLang = 'languageCode';
  static const _kOnboarded = 'onboarded';
  static const _kName = 'displayName';

  Future<AppSettings> read() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      languageCode: p.getString(_kLang),
      onboarded: p.getBool(_kOnboarded) ?? false,
      displayName: p.getString(_kName) ?? '',
    );
  }

  Future<void> write(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    if (s.languageCode == null) {
      await p.remove(_kLang);
    } else {
      await p.setString(_kLang, s.languageCode!);
    }
    await p.setBool(_kOnboarded, s.onboarded);
    await p.setString(_kName, s.displayName);
  }
}

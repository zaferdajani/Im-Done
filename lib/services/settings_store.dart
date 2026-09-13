import 'package:shared_preferences/shared_preferences.dart';

/// Small, per-device preferences.
class AppSettings {
  const AppSettings({
    required this.languageCode, // null = follow the system
    required this.onboarded,
    required this.displayName,
    this.voiceEngine = VoiceEngine.cloud,
    this.setupDone = false,
    this.themeMode = AppTheme.system,
  });

  final String? languageCode;
  final bool onboarded;
  final String displayName;

  /// Where speech is understood: the cloud (every language, needs internet)
  /// or the phone's own recogniser (English/Arabic, nothing leaves it).
  final VoiceEngine voiceEngine;

  /// The welcome screen (language question) has been answered.
  final bool setupDone;

  /// Light, dark, or whatever the phone is set to.
  final AppTheme themeMode;

  AppSettings copyWith({String? languageCode, bool clearLanguage = false, bool? onboarded, String? displayName, VoiceEngine? voiceEngine, bool? setupDone, AppTheme? themeMode}) =>
      AppSettings(
        languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
        onboarded: onboarded ?? this.onboarded,
        displayName: displayName ?? this.displayName,
        voiceEngine: voiceEngine ?? this.voiceEngine,
        setupDone: setupDone ?? this.setupDone,
        themeMode: themeMode ?? this.themeMode,
      );

  static const empty = AppSettings(languageCode: null, onboarded: false, displayName: '');
}

enum VoiceEngine { cloud, device }

enum AppTheme { system, light, dark }

class SettingsStore {
  static const _kLang = 'languageCode';
  static const _kOnboarded = 'onboarded';
  static const _kName = 'displayName';
  static const _kVoice = 'voiceEngine';
  static const _kSetup = 'setupDone';
  static const _kTheme = 'themeMode';

  Future<AppSettings> read() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      languageCode: p.getString(_kLang),
      onboarded: p.getBool(_kOnboarded) ?? false,
      displayName: p.getString(_kName) ?? '',
      voiceEngine: p.getString(_kVoice) == 'device' ? VoiceEngine.device : VoiceEngine.cloud,
      // Anyone who used the app before the welcome screen existed has
      // already made their choice (or is happy with the device language).
      setupDone: p.getBool(_kSetup) ?? (p.getBool(_kOnboarded) ?? false),
      themeMode: AppTheme.values.where((t) => t.name == p.getString(_kTheme)).firstOrNull ?? AppTheme.system,
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
    await p.setString(_kVoice, s.voiceEngine.name);
    await p.setBool(_kSetup, s.setupDone);
    await p.setString(_kTheme, s.themeMode.name);
  }
}

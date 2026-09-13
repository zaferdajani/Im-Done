/// The languages the app can be shown in, with their own names (what a
/// person looks for on a language picker), and which of them read right
/// to left. A code appears here only when l10n/<code>.json exists — the
/// test in test/l10n_pipeline_test.dart holds the two in step.
library;

const List<(String, String)> supportedLanguages = [
  ('en', 'English'),
  ('ar', 'العربية'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('pt', 'Português'),
  ('it', 'Italiano'),
  ('tr', 'Türkçe'),
  ('ru', 'Русский'),
  ('uk', 'Українська'),
  ('hi', 'हिन्दी'),
  ('ur', 'اردو'),
  ('gu', 'ગુજરાતી'),
  ('fa', 'فارسی'),
  ('zh', '中文'),
  ('ja', '日本語'),
  ('ko', '한국어'),
];

const Set<String> rtlLanguages = {'ar', 'ur', 'fa', 'he'};

bool isSupportedLanguage(String code) => supportedLanguages.any((l) => l.$1 == code);

String nativeLanguageName(String code) => supportedLanguages.where((l) => l.$1 == code).map((l) => l.$2).firstOrNull ?? code;

/// The list separator a language uses between items ("a, b" / "أ، ب").
String listSeparator(String code) => rtlLanguages.contains(code) ? '، ' : ', ';

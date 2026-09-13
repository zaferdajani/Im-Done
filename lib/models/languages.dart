/// Names for the languages and Arabic varieties a task can be spoken in,
/// in the two UI languages. Codes come from the server (ISO 639-1 for the
/// language, a fixed list for the dialect) and are stored on the task; the
/// name is only ever a display concern, so an unknown code still renders.
library;

const Map<String, (String, String)> languageNames = {
  'en': ('English', 'الإنجليزية'),
  'ar': ('Arabic', 'العربية'),
  'es': ('Spanish', 'الإسبانية'),
  'zh': ('Chinese', 'الصينية'),
  'ur': ('Urdu', 'الأردية'),
  'gu': ('Gujarati', 'الغوجاراتية'),
  'pt': ('Portuguese', 'البرتغالية'),
  'fr': ('French', 'الفرنسية'),
  'it': ('Italian', 'الإيطالية'),
  'ru': ('Russian', 'الروسية'),
  'uk': ('Ukrainian', 'الأوكرانية'),
  'ko': ('Korean', 'الكورية'),
  'ja': ('Japanese', 'اليابانية'),
  'hi': ('Hindi', 'الهندية'),
  'de': ('German', 'الألمانية'),
  'tr': ('Turkish', 'التركية'),
  'fa': ('Persian', 'الفارسية'),
  'bn': ('Bengali', 'البنغالية'),
  'id': ('Indonesian', 'الإندونيسية'),
  'ms': ('Malay', 'الملايوية'),
  'pa': ('Punjabi', 'البنجابية'),
  'ta': ('Tamil', 'التاميلية'),
  'te': ('Telugu', 'التيلوغوية'),
  'ml': ('Malayalam', 'المالايالامية'),
  'tl': ('Filipino', 'الفلبينية'),
  'nl': ('Dutch', 'الهولندية'),
  'pl': ('Polish', 'البولندية'),
  'sv': ('Swedish', 'السويدية'),
  'he': ('Hebrew', 'العبرية'),
  'sw': ('Swahili', 'السواحلية'),
  'so': ('Somali', 'الصومالية'),
};

const Map<String, (String, String)> arabicDialectNames = {
  'msa': ('Standard Arabic', 'الفصحى'),
  'egyptian': ('Egyptian', 'مصري'),
  'sudanese': ('Sudanese', 'سوداني'),
  'levantine': ('Levantine', 'شامي'),
  'jordanian': ('Jordanian', 'أردني'),
  'palestinian': ('Palestinian', 'فلسطيني'),
  'syrian': ('Syrian', 'سوري'),
  'lebanese': ('Lebanese', 'لبناني'),
  'gulf': ('Gulf', 'خليجي'),
  'saudi': ('Saudi', 'سعودي'),
  'hejazi': ('Hejazi', 'حجازي'),
  'najdi': ('Najdi', 'نجدي'),
  'emirati': ('Emirati', 'إماراتي'),
  'kuwaiti': ('Kuwaiti', 'كويتي'),
  'qatari': ('Qatari', 'قطري'),
  'bahraini': ('Bahraini', 'بحريني'),
  'omani': ('Omani', 'عُماني'),
  'iraqi': ('Iraqi', 'عراقي'),
  'yemeni': ('Yemeni', 'يمني'),
  'maghrebi': ('Maghrebi', 'مغاربي'),
  'moroccan': ('Moroccan', 'مغربي'),
  'algerian': ('Algerian', 'جزائري'),
  'tunisian': ('Tunisian', 'تونسي'),
  'libyan': ('Libyan', 'ليبي'),
};

/// "Arabic · Jordanian" / "العربية · أردني". Null when nothing is known.
String? languageLabel(String? code, String? dialect, String uiLanguage) {
  if (code == null || code.isEmpty) return null;
  final ar = uiLanguage == 'ar';
  final lang = languageNames[code];
  final name = lang == null ? code.toUpperCase() : (ar ? lang.$2 : lang.$1);
  if (code == 'ar' && dialect != null) {
    final d = arabicDialectNames[dialect];
    if (d != null) return '$name · ${ar ? d.$2 : d.$1}';
  }
  return name;
}

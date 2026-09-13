import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imdone/l10n/strings.dart';
import 'package:imdone/l10n/supported.dart';

/// The translation pipeline's lock: every language the picker offers has a
/// complete generated table, the generated Dart matches the JSON it came
/// from, and no placeholder was lost on the way.
void main() {
  test('every supported language has a generated table', () {
    for (final lang in supportedLanguages) {
      expect(l10nTables.containsKey(lang.$1), isTrue, reason: '${lang.$1} is offered but l10n/${lang.$1}.json is missing or not generated');
      expect(L10n.forCode(lang.$1).holdToSpeak, isNotEmpty);
    }
  });

  test('tables.g.dart is in step with l10n/*.json (run tool/gen_l10n.py)', () {
    final dir = Directory('l10n');
    final codes = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).map((f) => f.uri.pathSegments.last.replaceAll('.json', '')).toSet();
    expect(l10nTables.keys.toSet(), codes);
    final en = jsonDecode(File('l10n/en.json').readAsStringSync()) as Map<String, dynamic>;
    for (final code in codes) {
      final j = jsonDecode(File('l10n/$code.json').readAsStringSync()) as Map<String, dynamic>;
      expect(j.keys.toSet(), en.keys.toSet(), reason: '$code has a different key set from en');
      expect(L10n.forCode(code).holdToSpeak, j['holdToSpeak'], reason: '$code table is stale');
      expect(L10n.forCode(code).fromDate, contains('{date}'), reason: '$code lost the {date} placeholder');
    }
  });

  test('an unknown code shows english rather than crashing', () {
    expect(L10n.forCode('xx').holdToSpeak, L10n.forCode('en').holdToSpeak);
  });

  test('right-to-left languages are named', () {
    expect(rtlLanguages, containsAll(['ar', 'ur', 'fa']));
    expect(listSeparator('ar'), '، ');
    expect(listSeparator('es'), ', ');
  });
}

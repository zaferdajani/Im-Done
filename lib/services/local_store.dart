import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/platform.dart';
import '../models/task.dart';

/// Personal tasks live in ONE json file in the app's documents directory.
/// No database, no account, nothing leaves the phone. The same file is read
/// by the background notification handler, so every write is atomic
/// (write to a temp file, then rename).
class LocalStore {
  LocalStore._(this._file);

  /// Null on the web, where the browser's local storage holds the JSON instead.
  final File? _file;
  static const _webKey = 'tasks_json_v1';

  static Future<LocalStore> open() async {
    if (isWeb) return LocalStore._(null);
    final dir = await getApplicationDocumentsDirectory();
    return LocalStore._(File('${dir.path}/tasks.json'));
  }

  Future<String?> _readRaw() async {
    if (_file == null) return (await SharedPreferences.getInstance()).getString(_webKey);
    if (!await _file.exists()) return null;
    return _file.readAsString();
  }

  Future<List<Task>> readAll() async {
    try {
      final raw = await _readRaw();
      if (raw == null || raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // A corrupt file must never brick the app: start empty, keep the bytes.
      try {
        await _file?.copy('${_file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      } catch (_) {}
      return [];
    }
  }

  Future<void> writeAll(List<Task> tasks) async {
    final json = jsonEncode(tasks.map((t) => t.toJson()).toList());
    if (_file == null) {
      await (await SharedPreferences.getInstance()).setString(_webKey, json);
      return;
    }
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_file.path);
  }

  Future<Task?> find(String id) async =>
      (await readAll()).where((t) => t.id == id).firstOrNull;

  Future<void> upsert(Task task) async {
    final all = await readAll();
    final i = all.indexWhere((t) => t.id == task.id);
    if (i >= 0) {
      all[i] = task;
    } else {
      all.add(task);
    }
    await writeAll(all);
  }

  Future<void> remove(String id) async {
    final all = await readAll();
    all.removeWhere((t) => t.id == id);
    await writeAll(all);
  }
}

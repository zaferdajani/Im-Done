import 'package:app_links/app_links.dart';

/// Invite links look like  https://imdone.me/j/ABCD2345  or  imdone://join/ABCD2345
class DeepLinks {
  final _links = AppLinks();

  static String? inviteCode(Uri uri) {
    final q = uri.queryParameters['join'];
    if (q != null) return _clean(q);
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == 'imdone' && uri.host == 'join' && segs.isNotEmpty) return _clean(segs.first);
    if (segs.length >= 2 && segs[segs.length - 2] == 'j') return _clean(segs.last);
    return null;
  }

  /// A personal code from a scanned QR / opened link: https://…/p/CODE,
  /// imdone://add/CODE, ?add=CODE, or the bare 8-character code.
  static String? personCode(Uri uri) {
    final q = uri.queryParameters['add'];
    if (q != null) return _clean(q);
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == 'imdone' && uri.host == 'add' && segs.isNotEmpty) return _clean(segs.first);
    if (segs.length >= 2 && segs[segs.length - 2] == 'p') return _clean(segs.last);
    return null;
  }

  static String? personCodeFromText(String text) {
    final t = text.trim();
    final asUri = Uri.tryParse(t);
    if (asUri != null && (asUri.hasScheme || t.contains('/'))) return personCode(asUri);
    return _clean(t.replaceAll('-', ''));
  }

  Stream<String> personCodes() => _links.uriLinkStream.map(personCode).where((c) => c != null).cast<String>();

  Future<String?> initialPersonCode() async {
    try {
      final u = await _links.getInitialLink();
      return u == null ? null : personCode(u);
    } catch (_) {
      return null;
    }
  }

  static String? _clean(String s) {
    final c = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return c.length == 8 ? c : null;
  }

  Future<String?> initialCode() async {
    try {
      final u = await _links.getInitialLink();
      return u == null ? null : inviteCode(u);
    } catch (_) {
      return null;
    }
  }

  Stream<String> codes() => _links.uriLinkStream.map(inviteCode).where((c) => c != null).cast<String>();
}

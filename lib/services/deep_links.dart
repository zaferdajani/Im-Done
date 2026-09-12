import 'package:app_links/app_links.dart';

/// Invite links look like  https://imdone.me/j/ABCD2345  or  imdone://join/ABCD2345
class DeepLinks {
  final _links = AppLinks();

  static String? inviteCode(Uri uri) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == 'imdone' && uri.host == 'join' && segs.isNotEmpty) return _clean(segs.first);
    if (segs.length >= 2 && segs[segs.length - 2] == 'j') return _clean(segs.last);
    return null;
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

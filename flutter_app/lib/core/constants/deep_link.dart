/// Stable deep-link contract shared by the invite share sheet and the
/// auto-join handler: `ludo://join/<ROOMCODE>`
class DeepLink {
  DeepLink._();

  static const String scheme = 'ludo';
  static const String host = 'join';

  static String room(String code) => '$scheme://$host/${code.toUpperCase()}';

  /// Parses a deep link URI back into a room code (uppercase), or null when
  /// the URI does not look like one of our invites.
  static String? parseCode(Uri uri) {
    if (uri.scheme.toLowerCase() == scheme &&
        uri.host.toLowerCase() == host) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) return segments.first.toUpperCase();
    }
    // Also tolerate a fallback https route: <host>/join/<code>
    if (uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.toLowerCase() == 'join') {
      if (uri.pathSegments.length >= 2 && uri.pathSegments[1].isNotEmpty) {
        return uri.pathSegments[1].toUpperCase();
      }
    }
    return null;
  }
}
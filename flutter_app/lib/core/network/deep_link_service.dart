import 'dart:async';

import 'package:app_links/app_links.dart';

import '../constants/deep_link.dart';

/// Listens for `ludo://join/<CODE>` intents (warm + cold app start) and
/// exposes them as a stream of room codes.
class DeepLinkService {
  DeepLinkService();

  final AppLinks _appLinks = AppLinks();
  final StreamController<String> _links =
      StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;
  String? _pending;
  bool _started = false;

  /// Begin listening. At most one cold-start link is captured and replayed
  /// for the first subscriber (which is the whole point of a deep link).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = _appLinks.uriLinkStream.listen((uri) => _push(uri));
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _push(initial);
    } catch (_) {
      // No cold-start link - normal app open.
    }
  }

  void _push(Uri uri) {
    final code = DeepLink.parseCode(uri);
    if (code == null) return;
    _pending ??= code;
    if (!_links.isClosed) _links.add(code);
  }

  /// Room codes as they arrive; always replays the cold-start link first.
  Stream<String> get codes async* {
    final pending = _pending;
    if (pending != null) yield pending;
    yield* _links.stream;
  }

  Future<void> dispose() async {
    _pending = null;
    await _sub?.cancel();
    await _links.close();
  }
}
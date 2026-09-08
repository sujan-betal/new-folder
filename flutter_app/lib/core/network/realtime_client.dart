import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_endpoints.dart';
import 'token_storage.dart';

/// Realtime subscription layer over WebSockets.
///
/// One socket per topic (`/api/v1/ws/room/<code>` or `/api/v1/ws/game/<id>`).
/// The backend pushes JSON frames `{"kind": ..., ...}` (room snapshots, game
/// snapshots, game-started events). The client transparently reconnects with
/// exponential backoff and tolerates brief network blips, so online play stays
/// smooth like Ludo King rather than stuttery request-polling.
class RealtimeClient {
  RealtimeClient(this._storage);

  final TokenStorage _storage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _keepAlive;
  Timer? _retryTimer;

  /// Called for every normal (non-retry) JSON frame received.
  Future<void> Function(String message)? onData;

  /// Called when the socket drops and we start reconnecting.
  VoidCallbackPlus? onReconnecting;

  bool _disposed = false;
  String? _activePath;
  int _attempt = 0;

  String _wsUrl(String apiPath) {
    final base = ApiEndpoints.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final token = _storage.read() ?? '';
    final sep = apiPath.contains('?') ? '&' : '?';
    return '$base$apiPath$sep' 'token=$token';
  }

  void connect(String apiPath) {
    disconnect();
    _disposed = false;
    _activePath = apiPath;
    _open();
  }

  void _open() {
    if (_disposed || _activePath == null) return;
    final path = _activePath!;
    WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(_wsUrl(path)));
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;

    _sub?.cancel();
    _sub = channel.stream.listen(
      (raw) {
        _attempt = 0;
        final text = raw is String ? raw : (raw is List<int> ? utf8.decode(raw) : raw.toString());
        if (text.startsWith('{') && onData != null) onData!(text);
      },
      onError: (_) => _scheduleRetry(),
      onDone: () => _scheduleRetry(),
      cancelOnError: true,
    );

    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(
      const Duration(seconds: 20),
      (_) => channel.sink.add('keepalive'),
    );
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _attempt += 1;
    final delay = Duration(milliseconds: _attempt == 1 ? 600 : 2400);
    onReconnecting?.call();
    _sub?.cancel();
    _keepAlive?.cancel();
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _open);
  }

  void disconnect() {
    _disposed = true;
    _retryTimer?.cancel();
    _keepAlive?.cancel();
    _sub?.cancel();
    _sub = null;
    _retryTimer = null;
    _channel?.sink.close();
    _channel = null;
    _activePath = null;
  }
}

typedef VoidCallbackPlus = void Function();
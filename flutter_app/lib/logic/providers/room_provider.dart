import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/realtime_client.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';

class RoomProvider extends ChangeNotifier {
  RoomProvider(this._repository, this._realtime);

  final RoomRepository _repository;
  final RealtimeClient _realtime;

  List<RoomModel> openRooms = [];
  RoomModel? room;
  bool loading = false;
  String? error;

  /// Fired when the host closes the room (everyone is kicked back).
  VoidCallback? onClosed;

  /// Fired for EVERY player the moment the game starts - the server pushes
  /// `game_started` to the whole room, so no one is stuck in the lobby.
  void Function(int gameId)? onGameStarted;

  Future<void> loadOpenRooms() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      openRooms = await _repository.openRooms();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> createRoom({required String name, required int maxPlayers}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      room = await _repository.create(name: name, maxPlayers: maxPlayers);
      _subscribe();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> join(String code) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      room = await _repository.join(code);
      _subscribe();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Fetch + subscribe again (used when the waiting room re-attaches, e.g.
  /// after a deep-link join while the app was already running).
  Future<bool> attach(String code) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      room = await _repository.get(code);
      _subscribe();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _subscribe() {
    final code = room?.code;
    if (code == null) return;
    _realtime.onData = _handleFrame;
    _realtime.connect('/api/v1/ws/room/$code');
  }

  Future<void> _handleFrame(String raw) async {
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      if (msg['kind'] != 'room') return;

      if (msg['closed'] == true) {
        if (room != null) {
          room = null;
          notifyListeners();
        }
        onClosed?.call();
        return;
      }

      final roomData = msg['room'] as Map<String, dynamic>?;
      final started = msg['game_started'] == true;
      if (roomData == null) return;

      final fresh = RoomModel.fromJson(roomData);
      final changed = fresh.players.length != room?.players.length ||
          fresh.players.toString() != room?.players.toString() ||
          fresh.status != room?.status;

      room = fresh;
      if (changed) notifyListeners();

      if (started && fresh.activeGameId != null) {
        onGameStarted?.call(fresh.activeGameId!);
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (room == null) return;
    try {
      final fresh = await _repository.get(room!.code);
      final changed =
          fresh.players.length != room!.players.length ||
              fresh.players.toString() != room!.players.toString() ||
              fresh.status != room!.status;
      room = fresh;
      if (changed) notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleReady() async {
    if (room == null) return;
    try {
      room = await _repository.toggleReady(room!.code);
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> leave() async {
    _realtime.disconnect();
    if (room == null) return;
    try {
      await _repository.leave(room!.code);
    } finally {
      room = null;
      notifyListeners();
    }
  }

  /// Detach from the live room WITHOUT touching app-wide state - used when the
  /// waiting room screen is popped so the shared provider stays usable.
  void disconnect() {
    _realtime.disconnect();
  }

  @override
  void dispose() {
    _realtime.disconnect();
    super.dispose();
  }
}
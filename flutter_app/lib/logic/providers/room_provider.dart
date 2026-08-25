import 'package:flutter/foundation.dart';

import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';

class RoomProvider extends ChangeNotifier {
  RoomProvider(this._repository);

  final RoomRepository _repository;

  List<RoomModel> openRooms = [];
  RoomModel? room;
  bool loading = false;
  String? error;

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
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
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
    if (room == null) return;
    try {
      await _repository.leave(room!.code);
    } finally {
      room = null;
      notifyListeners();
    }
  }
}

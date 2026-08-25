import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ludo King style sound effects.
///
/// All effects are short one-shot WAVs bundled in assets/sounds and played
/// through a dedicated low-latency player each time.
class SoundManager {
  SoundManager._();

  static final SoundManager instance = SoundManager._();

  final Map<String, AudioPlayer> _pool = {};
  bool _enabled = true;
  bool _initialized = false;

  bool get enabled => _enabled;

  Future<void> init([SharedPreferences? prefs]) async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (prefs != null) {
        _enabled = prefs.getBool('sound_enabled') ?? true;
      }
      for (final name in _allSounds) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(AssetSource('sounds/$name.wav'));
        _pool[name] = player;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SoundManager init: $e');
    }
  }

  static const List<String> _allSounds = [
    'dice_roll',
    'move',
    'capture',
    'safe',
    'home',
    'turn',
    'win',
  ];

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', value);
    } catch (_) {}
  }

  void toggle() => setEnabled(!_enabled);

  /// Fire-and-forget one-shot. Safe to call from anywhere.
  void play(String name) {
    if (!_enabled) return;
    final player = _pool[name];
    if (player == null) return;
    player.stop().then((_) => player.resume()).catchError((_) {});
  }

  // Named helpers so gameplay code stays readable.
  void diceRoll() => play('dice_roll');
  void move() => play('move');
  void capture() => play('capture');
  void safe() => play('safe');
  void home() => play('home');
  void turn() => play('turn');
  void win() => play('win');

  Future<void> dispose() async {
    for (final p in _pool.values) {
      await p.dispose();
    }
    _pool.clear();
    _initialized = false;
  }
}

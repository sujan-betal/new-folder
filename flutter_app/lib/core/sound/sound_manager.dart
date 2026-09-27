import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound identity. Every cue is a short one-shot WAV in assets/sounds.
///
/// [voices] is how many parallel players are pre-warmed for the cue. More than
/// one matters for cues that can retrigger while still sounding (token hops,
/// UI taps) so rapid repeats never cut each other off. Extra voices are
/// pre-pitched slightly differently, which is what makes repeated hops feel
/// hand-made instead of machine-gunned.
class Cue {
  const Cue(this.file, {this.voices = 1, this.pitchSpread = 0.0});

  final String file;
  final int voices;

  /// +/- pitch jitter applied across the voices (0 = identical).
  final double pitchSpread;
}

const Map<String, Cue> kCues = {
  'dice_throw': Cue('dice_throw'),
  'dice_roll': Cue('dice_roll'),
  'move': Cue('move', voices: 4, pitchSpread: 0.10),
  'release': Cue('release', voices: 2, pitchSpread: 0.05),
  'capture': Cue('capture'),
  'safe': Cue('safe'),
  'home': Cue('home'),
  'six': Cue('six'),
  'turn': Cue('turn'),
  'invalid': Cue('invalid'),
  'win': Cue('win'),
  'lose': Cue('lose'),
  'tap': Cue('tap', voices: 2, pitchSpread: 0.12),
  'coin': Cue('coin', voices: 2, pitchSpread: 0.07),
  'countdown': Cue('countdown'),
};

const String kMusicLoop = 'music_loop';

/// Game audio: a pool of pre-loaded low-latency players for effects plus a
/// separate looping music track.
///
/// Everything is fire-and-forget from the caller's point of view - gameplay
/// code can call [diceRoll] from a `build` listener without awaiting.
class SoundManager {
  SoundManager._();

  static final SoundManager instance = SoundManager._();

  final Map<String, List<AudioPlayer>> _pool = {};
  final Map<String, int> _cursor = {};

  AudioPlayer? _music;
  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  bool _initialized = false;
  double _sfxVolume = 0.9;
  double _musicVolume = 0.32;
  bool _musicStarted = false;

  /// Bumped on every settings change so UI can react to the toggles.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  bool get enabled => _sfxEnabled;
  bool get musicEnabled => _musicEnabled;
  double get volume => _sfxVolume;
  double get musicVolume => _musicVolume;

  /// Pre-load every cue. Call once at startup, before the first frame.
  Future<void> init([SharedPreferences? prefs]) async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (prefs != null) {
        _sfxEnabled = prefs.getBool('sound_enabled') ?? true;
        _musicEnabled = prefs.getBool('music_enabled') ?? true;
        _sfxVolume = prefs.getDouble('sound_volume') ?? _sfxVolume;
        _musicVolume = prefs.getDouble('music_volume') ?? _musicVolume;
      }

      for (final entry in kCues.entries) {
        final name = entry.key;
        final cue = entry.value;
        final players = <AudioPlayer>[];
        for (var i = 0; i < cue.voices; i++) {
          final player = AudioPlayer();
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(AssetSource('sounds/${cue.file}.wav'));
          await player.setVolume(_sfxVolume);
          if (cue.voices > 1 && cue.pitchSpread > 0) {
            // Spread the voices around the cue's centre pitch.
            final t = cue.voices == 1
                ? 0.0
                : (i / (cue.voices - 1)) * 2.0 - 1.0;
            await player.setPlaybackRate(1.0 + t * cue.pitchSpread);
          }
          players.add(player);
        }
        _pool[name] = players;
        _cursor[name] = 0;
      }

      _music = AudioPlayer();
      await _music!.setPlayerMode(PlayerMode.mediaPlayer);
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setSource(AssetSource('sounds/$kMusicLoop.wav'));
      await _music!.setVolume(_musicEnabled ? _musicVolume : 0.0);
    } catch (e) {
      if (kDebugMode) debugPrint('SoundManager init failed: $e');
    }
  }

  // ----------------------------------------------------------------- effects

  /// Fire a cue. Round-robins through the pre-warmed voices.
  void play(String name) {
    if (!_sfxEnabled) return;
    final players = _pool[name];
    if (players == null || players.isEmpty) return;
    final index = _cursor[name]!;
    _cursor[name] = (index + 1) % players.length;
    _trigger(players[index]);
  }

  void _trigger(AudioPlayer player) {
    player.stop().then((_) => player.resume()).catchError((_) {
      player.seek(Duration.zero).then((_) => player.resume()).catchError((_) {});
    });
  }

  // -------------------------------------------------------------- cue names

  /// Light pre-roll while the hand shakes the dice.
  void diceThrow() => play('dice_throw');

  /// The main rattle + tumble.
  void diceRoll() => play('dice_roll');

  /// One hop of a token. Safe to call many times in a second.
  void move() => play('move');

  /// Token lifted out of the yard onto the track.
  void release() => play('release');

  /// A token was cut and sent home.
  void capture() => play('capture');

  /// Landed on a starred safe square.
  void safe() => play('safe');

  /// Token reached the finish triangle.
  void home() => play('home');

  /// Rolled a six - extra turn.
  void six() => play('six');

  /// Pass of the baton to the next player.
  void turn() => play('turn');

  /// Illegal / unavailable action.
  void invalid() => play('invalid');

  void win() => play('win');

  void lose() => play('lose');

  void tap() => play('tap');

  void coin() => play('coin');

  void countdown() => play('countdown');

  // ------------------------------------------------------------------ music

  /// Start the background loop (idempotent).
  Future<void> startMusic() async {
    if (!_initialized || _music == null || _musicStarted) return;
    _musicStarted = true;
    try {
      await _music!.resume();
    } catch (e) {
      if (kDebugMode) debugPrint('startMusic: $e');
    }
  }

  Future<void> stopMusic() async {
    if (_music == null || !_musicStarted) return;
    _musicStarted = false;
    try {
      await _music!.pause();
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    _sfxEnabled = value;
    if (!value) {
      for (final players in _pool.values) {
        for (final p in players) {
          p.stop().catchError((_) {});
        }
      }
    }
    await _persist();
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    await _music?.setVolume(value ? _musicVolume : 0.0);
    if (value) {
      await startMusic();
    } else {
      await stopMusic();
    }
    await _persist();
  }

  Future<void> setVolume(double value) async {
    _sfxVolume = value.clamp(0.0, 1.0);
    for (final players in _pool.values) {
      for (final p in players) {
        await p.setVolume(_sfxVolume);
      }
    }
    await _persist();
  }

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    if (_musicEnabled) await _music?.setVolume(_musicVolume);
    await _persist();
  }

  void toggle() => setEnabled(!_sfxEnabled);
  void toggleMusic() => setMusicEnabled(!_musicEnabled);

  Future<void> _persist() async {
    changes.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', _sfxEnabled);
      await prefs.setBool('music_enabled', _musicEnabled);
      await prefs.setDouble('sound_volume', _sfxVolume);
      await prefs.setDouble('music_volume', _musicVolume);
    } catch (_) {}
  }

  // ------------------------------------------------------------- lifecycle

  /// Duck everything while the app is backgrounded.
  Future<void> pauseAll() async {
    for (final players in _pool.values) {
      for (final p in players) {
        p.pause().catchError((_) {});
      }
    }
    await _music?.pause();
    _musicStarted = false;
  }

  Future<void> resumeAll() async {
    for (final players in _pool.values) {
      for (final p in players) {
        p.resume().catchError((_) {});
      }
    }
    if (_musicEnabled) await startMusic();
  }

  Future<void> dispose() async {
    for (final players in _pool.values) {
      for (final p in players) {
        await p.dispose();
      }
    }
    _pool.clear();
    await _music?.dispose();
    _music = null;
    _musicStarted = false;
    _initialized = false;
  }
}

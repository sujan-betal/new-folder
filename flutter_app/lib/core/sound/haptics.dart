import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin, persistable wrapper over [HapticFeedback].
///
/// Sound and haptics share one preference so a single toggle silences both -
/// half the players who mute a board game want the buzz gone too.
class Haptics {
  Haptics._();

  static final Haptics instance = Haptics._();

  static const _key = 'haptics_enabled';

  bool _enabled = true;
  bool _initialized = false;

  bool get enabled => _enabled;

  Future<void> init([SharedPreferences? prefs]) async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (prefs != null) _enabled = prefs.getBool(_key) ?? true;
    } catch (e) {
      if (kDebugMode) debugPrint('Haptics init: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }

  void toggle() => setEnabled(!_enabled);

  /// Token hops and small acknowledgements.
  void light() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  /// Rolling the dice, a valid move.
  void medium() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  /// Captures, heavy landings.
  void heavy() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  /// A token finishes, a six is rolled.
  void success() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  /// Illegal action, someone else won.
  void error() {
    if (_enabled) HapticFeedback.heavyImpact();
  }
}

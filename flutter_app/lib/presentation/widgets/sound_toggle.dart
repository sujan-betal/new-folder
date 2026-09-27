import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/sound/haptics.dart';
import '../../core/sound/sound_manager.dart';

/// Speaker button that mutes/unmutes all game audio, plus a long-press style
/// panel for the full mix (music, vibration, volumes).
class SoundToggle extends StatelessWidget {
  const SoundToggle({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final sound = SoundManager.instance;
    return IconButton(
      tooltip: 'Sound & music',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const _AudioPanel(),
      ),
      icon: ValueListenableBuilder<int>(
        valueListenable: sound.changes,
        builder: (context, _, __) {
          final enabled = sound.enabled;
          final musicOn = sound.musicEnabled;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: enabled ? AppColors.gold : Colors.white38,
                size: size,
              ),
              if (enabled && musicOn)
                Positioned(
                  right: -3,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.navy,
                      border: Border.all(color: AppColors.gold, width: 1),
                    ),
                    child: Icon(Icons.music_note,
                        size: size * 0.44, color: AppColors.gold),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AudioPanel extends StatefulWidget {
  const _AudioPanel();

  @override
  State<_AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<_AudioPanel> {
  late bool _sound = SoundManager.instance.enabled;
  late bool _music = SoundManager.instance.musicEnabled;
  late bool _haptics = Haptics.instance.enabled;
  late double _sfx = SoundManager.instance.volume;
  late double _bgm = SoundManager.instance.musicVolume;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyLight, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sound & Feel',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 10),
          _row(
            icon: Icons.volume_up_rounded,
            label: 'Sound effects',
            value: _sound,
            onChanged: (v) {
              setState(() => _sound = v);
              SoundManager.instance.setEnabled(v);
              if (v) {
                SoundManager.instance.tap();
                Haptics.instance.medium();
              }
            },
          ),
          _slider(
            icon: Icons.graphic_eq_rounded,
            value: _sfx,
            onChanged: (v) {
              setState(() => _sfx = v);
              SoundManager.instance.setVolume(v);
            },
          ),
          _row(
            icon: Icons.music_note_rounded,
            label: 'Background music',
            value: _music,
            onChanged: (v) {
              setState(() => _music = v);
              SoundManager.instance.setMusicEnabled(v);
              if (v) SoundManager.instance.tap();
            },
          ),
          _slider(
            icon: Icons.album_rounded,
            value: _bgm,
            onChanged: (v) {
              setState(() => _bgm = v);
              SoundManager.instance.setMusicVolume(v);
            },
          ),
          _row(
            icon: Icons.vibration_rounded,
            label: 'Vibration',
            value: _haptics,
            onChanged: (v) {
              setState(() => _haptics = v);
              Haptics.instance.setEnabled(v);
              if (v) Haptics.instance.heavy();
            },
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 19, color: value ? Colors.white : Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: value ? Colors.white : Colors.white54,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.gold,
            inactiveThumbColor: Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 2),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.white38),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.gold,
                inactiveTrackColor: Colors.white12,
                thumbColor: AppColors.gold,
                overlayColor: AppColors.gold.withValues(alpha: 0.18),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value,
                onChanged: (v) {
                  onChanged(v);
                  if (v > 0) {
                    HapticFeedback.selectionClick();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

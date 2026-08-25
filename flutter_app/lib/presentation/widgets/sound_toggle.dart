import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/sound/sound_manager.dart';

/// Speaker icon that mutes/unmutes all game sounds.
class SoundToggle extends StatefulWidget {
  const SoundToggle({super.key, this.size = 22});

  final double size;

  @override
  State<SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends State<SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final enabled = SoundManager.instance.enabled;
    return IconButton(
      tooltip: enabled ? 'Mute sounds' : 'Unmute sounds',
      onPressed: () async {
        await SoundManager.instance.setEnabled(!enabled);
        if (enabled) {
          // Play a tick so unmuting gives instant feedback.
          SoundManager.instance.turn();
        }
        if (mounted) setState(() {});
      },
      icon: Icon(
        enabled ? Icons.music_note : Icons.music_off,
        color: enabled ? AppColors.gold : Colors.white38,
        size: widget.size,
      ),
    );
  }
}

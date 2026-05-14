import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/call_provider.dart';
import '../../theme/app_theme.dart';

class ActiveCallScreen extends StatelessWidget {
  const ActiveCallScreen({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  IconData _audioOutputIcon(AudioOutput output) {
    switch (output) {
      case AudioOutput.earpiece:
        return Icons.phone_in_talk_rounded;
      case AudioOutput.headset:
        return Icons.headset_rounded;
      case AudioOutput.speaker:
        return Icons.volume_up_rounded;
    }
  }

  String _audioOutputLabel(AudioOutput output) {
    switch (output) {
      case AudioOutput.earpiece:
        return 'Earpiece';
      case AudioOutput.headset:
        return 'Headset';
      case AudioOutput.speaker:
        return 'Speaker';
    }
  }

  void _showAudioOutputPicker(BuildContext context, CallProvider cp) async {
    final available = await cp.availableAudioOutputs();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _AudioOutputSheet(
          available: available,
          current: cp.audioOutput,
          onSelect: (output) {
            cp.setAudioOutput(output);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CallProvider>();
    final session = cp.session;
    if (session == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),

            // Avatar / group icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withOpacity(0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: session.type == CallType.group
                    ? const Icon(Icons.group_rounded,
                        color: Colors.white, size: 46)
                    : Text(
                        session.displayName.isNotEmpty
                            ? session.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Name
            Text(
              session.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            // Status / duration
            _StatusLabel(session: session),

            const Spacer(),

            // Controls row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _CircleButton(
                    icon: cp.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: cp.isMuted ? 'Unmute' : 'Mute',
                    active: cp.isMuted,
                    onTap: () => cp.toggleMute(),
                  ),

                  // End call — larger red button
                  GestureDetector(
                    onTap: () {
                      cp.endCall();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),

                  // Audio output
                  _CircleButton(
                    icon: _audioOutputIcon(cp.audioOutput),
                    label: _audioOutputLabel(cp.audioOutput),
                    active: cp.audioOutput == AudioOutput.speaker,
                    onTap: () => _showAudioOutputPicker(context, cp),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final VoiceCallSession session;
  const _StatusLabel({required this.session});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (session.state) {
      case CallState.calling:
        label = 'Calling…';
        color = Colors.white70;
        break;
      case CallState.ringing:
        label = 'Incoming call';
        color = Colors.white70;
        break;
      case CallState.connected:
        label = _fmt(session.elapsed);
        color = const Color(0xFF4CAF50);
        break;
      case CallState.ended:
        label = 'Call ended';
        color = Colors.white38;
        break;
      default:
        label = '';
        color = Colors.white70;
    }
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.25)
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Audio output picker sheet ─────────────────────────────────────────────────

class _AudioOutputSheet extends StatelessWidget {
  final List<AudioOutput> available;
  final AudioOutput current;
  final ValueChanged<AudioOutput> onSelect;

  const _AudioOutputSheet({
    required this.available,
    required this.current,
    required this.onSelect,
  });

  IconData _icon(AudioOutput o) {
    switch (o) {
      case AudioOutput.earpiece:
        return Icons.phone_in_talk_rounded;
      case AudioOutput.headset:
        return Icons.headset_rounded;
      case AudioOutput.speaker:
        return Icons.volume_up_rounded;
    }
  }

  String _label(AudioOutput o) {
    switch (o) {
      case AudioOutput.earpiece:
        return 'Earpiece';
      case AudioOutput.headset:
        return 'Headset';
      case AudioOutput.speaker:
        return 'Speaker';
    }
  }

  String _subtitle(AudioOutput o) {
    switch (o) {
      case AudioOutput.earpiece:
        return 'Private — hold phone to ear';
      case AudioOutput.headset:
        return 'Connected headset / Bluetooth';
      case AudioOutput.speaker:
        return 'Loud speakerphone';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Audio output',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),

          ...available.map((output) {
            final selected = output == current;
            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF4CAF50).withOpacity(0.15)
                      : Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon(output),
                  color: selected ? const Color(0xFF4CAF50) : Colors.white60,
                  size: 22,
                ),
              ),
              title: Text(
                _label(output),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                _subtitle(output),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50), size: 22)
                  : null,
              onTap: () => onSelect(output),
            );
          }),
        ],
      ),
    );
  }
}
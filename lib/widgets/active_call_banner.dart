import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/call_provider.dart';
import '../providers/video_call_provider.dart';
import '../screens/call/active_call_screen.dart';
import '../screens/call/active_video_call_screen.dart';
import '../screens/call/active_group_video_call_screen.dart';

/// A persistent green banner shown whenever a voice or video call is active
/// in the background. Tap to return to the call screen.
class ActiveCallBanner extends StatelessWidget {
  const ActiveCallBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cp  = context.watch<CallProvider>();
    final vcp = context.watch<VideoCallProvider>();

    final hasVoice = cp.hasActiveCall;
    final hasVideo = vcp.hasActiveCall;

    if (!hasVoice && !hasVideo) return const SizedBox.shrink();

    // Prefer video when both are somehow active
    final isVideo = hasVideo;

    // Resolve name and elapsed from the correctly-typed session
    final String name;
    final Duration? elapsed;
    if (isVideo) {
      final s = vcp.session;          // VideoCallSession?
      name    = s?.displayName ?? '';
      elapsed = s?.elapsed;
    } else {
      final s = cp.session;           // VoiceCallSession?
      name    = s?.displayName ?? '';
      elapsed = s?.elapsed;
    }

    final String callLabel = isVideo ? 'Video call' : 'Voice call';
    final String status = (elapsed != null && elapsed.inSeconds > 0)
        ? '$callLabel · ${_fmt(elapsed)}'
        : '$callLabel · Connecting…';

    return GestureDetector(
      onTap: () {
        final nav = Navigator.of(context, rootNavigator: true);
        if (isVideo) {
          final isGroup = vcp.session?.type == VideoCallType.group;
          nav.push(MaterialPageRoute(
            builder: (_) => isGroup
                ? const ActiveGroupVideoCallScreen()
                : const ActiveVideoCallScreen(),
          ));
        } else {
          nav.push(MaterialPageRoute(
            builder: (_) => const ActiveCallScreen(),
          ));
        }
      },
      child: Container(
        width: double.infinity,
        color: const Color(0xFF1B5E20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _PulsingIcon(isVideo: isVideo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name.isNotEmpty ? name : callLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Return',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Pulsing icon ──────────────────────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  final bool isVideo;
  const _PulsingIcon({required this.isVideo});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
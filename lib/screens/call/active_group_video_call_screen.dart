import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../providers/video_call_provider.dart';
import '../../theme/app_theme.dart';

/// Full-screen group video call UI with a responsive grid of remote participants
/// and a draggable local PiP tile.
class ActiveGroupVideoCallScreen extends StatefulWidget {
  const ActiveGroupVideoCallScreen({super.key});

  @override
  State<ActiveGroupVideoCallScreen> createState() =>
      _ActiveGroupVideoCallScreenState();
}

class _ActiveGroupVideoCallScreenState
    extends State<ActiveGroupVideoCallScreen> {
  bool _showControls = true;
  Offset _pipOffset = const Offset(16, 100);

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  @override
  Widget build(BuildContext context) {
    final vcp = context.watch<VideoCallProvider>();
    final session = vcp.session;
    final svc = vcp.service;

    if (session == null || svc == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Snapshot of remote renderers at build time
    final renderers = Map<String, RTCVideoRenderer>.from(svc.remoteRenderers);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // ── Remote participant grid ──────────────────────────────────
            _ParticipantGrid(
              session: session,
              renderers: renderers,
            ),

            // ── Draggable local PiP ──────────────────────────────────────
            if (vcp.isVideoEnabled)
              Positioned(
                left: _pipOffset.dx,
                top: _pipOffset.dy,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      _pipOffset += d.delta;
                      // Clamp inside screen
                      _pipOffset = Offset(
                        _pipOffset.dx.clamp(0, size.width - 100),
                        _pipOffset.dy.clamp(topPad, size.height - 150),
                      );
                    });
                  },
                  child: _LocalPip(svc: svc),
                ),
              ),

            // ── Top bar ──────────────────────────────────────────────────
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: _TopBar(session: session, fmt: _fmt, topPad: topPad),
            ),

            // ── Bottom controls ──────────────────────────────────────────
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _ControlBar(vcp: vcp, svc: svc, bottomPad: bottomPad),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Participant grid ──────────────────────────────────────────────────────────

class _ParticipantGrid extends StatelessWidget {
  final dynamic session;
  final Map<String, RTCVideoRenderer> renderers;

  const _ParticipantGrid({required this.session, required this.renderers});

  @override
  Widget build(BuildContext context) {
    if (session.state != VideoCallState.connected || renderers.isEmpty) {
      return _WaitingView(session: session);
    }

    final ips = renderers.keys.toList();
    final count = ips.length;

    // Layout rules:
    // 1 peer  → full screen
    // 2 peers → 2 rows of 1
    // 3-4     → 2x2 grid
    // 5+      → 3-column grid
    int crossAxisCount;
    if (count == 1) {
      crossAxisCount = 1;
    } else if (count <= 2) {
      crossAxisCount = 1;
    } else if (count <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: count == 1 ? 9 / 16 : 3 / 4,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final ip = ips[i];
        final renderer = renderers[ip]!;
        return _RemoteTile(peerIp: ip, renderer: renderer);
      },
    );
  }
}

class _WaitingView extends StatelessWidget {
  final dynamic session;
  const _WaitingView({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_rounded,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              session.displayName ?? 'Group Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              session.state == VideoCallState.calling
                  ? 'Calling members…'
                  : 'Waiting for others to join…',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteTile extends StatelessWidget {
  final String peerIp;
  final RTCVideoRenderer renderer;

  const _RemoteTile({required this.peerIp, required this.renderer});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
        // IP label bottom-left
        Positioned(
          bottom: 6,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              peerIp,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Local PiP ─────────────────────────────────────────────────────────────────

class _LocalPip extends StatelessWidget {
  final dynamic svc;
  const _LocalPip({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white30, width: 1.5),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: RTCVideoView(
        svc.localRenderer,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final dynamic session;
  final String Function(Duration) fmt;
  final double topPad;

  const _TopBar({required this.session, required this.fmt, required this.topPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 32),
      child: Row(
        children: [
          const Icon(Icons.videocam_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.displayName ?? 'Group Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (session.state == VideoCallState.connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.5)),
              ),
              child: Text(
                fmt(session.elapsed),
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Control bar ───────────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  final VideoCallProvider vcp;
  final dynamic svc;
  final double bottomPad;

  const _ControlBar(
      {required this.vcp, required this.svc, required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CtrlButton(
            icon: vcp.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: vcp.isMuted ? 'Unmute' : 'Mute',
            active: vcp.isMuted,
            onTap: () => vcp.toggleMute(),
          ),
          _CtrlButton(
            icon: vcp.isVideoEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: vcp.isVideoEnabled ? 'Camera' : 'No Cam',
            active: !vcp.isVideoEnabled,
            onTap: () => vcp.toggleVideo(),
          ),

          // End call
          GestureDetector(
            onTap: () {
              vcp.endCall();
              Navigator.of(context).pop();
            },
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end_rounded,
                  color: Colors.white, size: 28),
            ),
          ),

          _CtrlButton(
            icon: Icons.flip_camera_android_rounded,
            label: 'Flip',
            active: false,
            onTap: () => vcp.switchCamera(),
          ),

          // Participant count badge
          _CtrlButton(
            icon: Icons.people_rounded,
            label: '${svc?.remoteRenderers?.length ?? 0} in call',
            active: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CtrlButton({
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.25)
                  : Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

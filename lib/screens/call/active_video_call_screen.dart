import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../providers/video_call_provider.dart';
import '../../theme/app_theme.dart';

class ActiveVideoCallScreen extends StatefulWidget {
  const ActiveVideoCallScreen({super.key});

  @override
  State<ActiveVideoCallScreen> createState() => _ActiveVideoCallScreenState();
}

class _ActiveVideoCallScreenState extends State<ActiveVideoCallScreen> {
  bool _showControls = true;

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Remote video (full screen) ─────────────────────────────
            _RemoteVideoView(svc: svc, session: session),

            // ── Local video (picture-in-picture) ──────────────────────
            if (vcp.isVideoEnabled)
              Positioned(
                right: 16,
                top: MediaQuery.of(context).padding.top + 16,
                child: _LocalPipVideo(svc: svc),
              ),

            // ── Status bar at top ──────────────────────────────────────
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: _TopBar(session: session, fmt: _fmt),
            ),

            // ── Controls at bottom ─────────────────────────────────────
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _ControlBar(vcp: vcp, svc: svc),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Remote video view ─────────────────────────────────────────────────────────

class _RemoteVideoView extends StatelessWidget {
  final dynamic svc;
  final VideoCallSession session;

  const _RemoteVideoView({required this.svc, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: session.state == VideoCallState.connected
          ? RTCVideoView(
              svc.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: session.type == VideoCallType.group
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
                  const SizedBox(height: 20),
                  Text(
                    session.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.state == VideoCallState.calling
                        ? 'Calling…'
                        : 'Connecting…',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Local PiP video ───────────────────────────────────────────────────────────

class _LocalPipVideo extends StatelessWidget {
  final dynamic svc;
  const _LocalPipVideo({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1.5),
        color: Colors.black,
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
  final VideoCallSession session;
  final String Function(Duration) fmt;

  const _TopBar({required this.session, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
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
              session.displayName,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

// ── Bottom control bar ────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  final VideoCallProvider vcp;
  final dynamic svc;

  const _ControlBar({required this.vcp, required this.svc});

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
      padding: EdgeInsets.fromLTRB(
          24, 32, 24, MediaQuery.of(context).padding.bottom + 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute
          _CtrlButton(
            icon: vcp.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: vcp.isMuted ? 'Unmute' : 'Mute',
            active: vcp.isMuted,
            onTap: () => vcp.toggleMute(),
          ),

          // Video on/off
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

          // Switch camera
          _CtrlButton(
            icon: Icons.flip_camera_android_rounded,
            label: 'Flip',
            active: false,
            onTap: () => vcp.switchCamera(),
          ),

          // Placeholder (balance layout)
          const SizedBox(width: 52),
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
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
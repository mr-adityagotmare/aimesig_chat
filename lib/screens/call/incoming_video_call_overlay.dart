import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/video_call_provider.dart';
import '../../theme/app_theme.dart';
import 'active_video_call_screen.dart';
import 'active_group_video_call_screen.dart';

/// Show this as a modal bottom sheet when an incoming video call arrives.
/// Call [showIncomingVideoCallSheet] from your onIncomingCall callback.
class IncomingVideoCallOverlay extends StatelessWidget {
  const IncomingVideoCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final vcp = context.watch<VideoCallProvider>();
    final session = vcp.session;
    if (session == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 28,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withOpacity(0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: session.type == VideoCallType.group
                    ? const Icon(Icons.group_rounded,
                        color: Colors.white, size: 36)
                    : Text(
                        session.displayName.isNotEmpty
                            ? session.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              session.displayName,
              style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),

            // Video call label with icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded,
                    size: 16,
                    color: AppColors.textMuted(isDark)),
                const SizedBox(width: 4),
                Text(
                  session.type == VideoCallType.group
                      ? 'Incoming group video call'
                      : 'Incoming video call',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline
                _CallButton(
                  icon: Icons.call_end_rounded,
                  label: 'Decline',
                  color: const Color(0xFFE53935),
                  onTap: () {
                    vcp.declineCall();
                    Navigator.of(context).pop();
                  },
                ),

                // Accept
                _CallButton(
                  icon: Icons.videocam_rounded,
                  label: 'Accept',
                  color: const Color(0xFF43A047),
                  onTap: () async {
                    // Capture the root navigator BEFORE popping the sheet,
                    // so we still have a valid navigator after dismissal.
                    final nav = Navigator.of(context, rootNavigator: true);
                    final isGroup = vcp.session?.type == VideoCallType.group;

                    // Init renderers, then accept
                    await vcp.service?.initRenderers();
                    await vcp.acceptCall();

                    // Dismiss the bottom sheet
                    nav.pop();

                    // Push the call screen onto the root navigator
                    nav.push(MaterialPageRoute(
                      builder: (_) => isGroup
                          ? const ActiveGroupVideoCallScreen()
                          : const ActiveVideoCallScreen(),
                    ));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Utility: show the incoming video call overlay as a modal bottom sheet.
void showIncomingVideoCallSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    builder: (_) => const IncomingVideoCallOverlay(),
  );
}
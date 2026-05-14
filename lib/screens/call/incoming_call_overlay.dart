import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/call_provider.dart';
import '../../theme/app_theme.dart';
import 'active_call_screen.dart';

/// Show this as a dialog/overlay when an incoming call arrives.
/// Typically called from main.dart via the onIncomingCall callback.
class IncomingCallOverlay extends StatelessWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CallProvider>();
    final session = cp.session;
    if (session == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 24,
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
                child: session.type == CallType.group
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
            Text(
              session.type == CallType.group
                  ? 'Incoming group voice call'
                  : 'Incoming voice call',
              style: TextStyle(
                color: AppColors.textMuted(isDark),
                fontSize: 13,
              ),
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
                    cp.declineCall();
                    Navigator.of(context).pop();
                  },
                ),

                // Accept
                _CallButton(
                  icon: Icons.call_rounded,
                  label: 'Accept',
                  color: const Color(0xFF43A047),
                  onTap: () async {
                    Navigator.of(context).pop(); // close overlay
                    await cp.acceptCall();
                    if (context.mounted) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ActiveCallScreen(),
                      ));
                    }
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Utility: show the incoming call overlay as a modal bottom sheet.
void showIncomingCallSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    builder: (_) => const IncomingCallOverlay(),
  );
}
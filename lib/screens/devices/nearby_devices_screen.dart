import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/udp_chat_service.dart';
import '../../models/peer.dart';
import '../../providers/peer_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';

class NearbyDevicesScreen extends StatefulWidget {
  final UdpChatService udp;
  final String myName;

  const NearbyDevicesScreen({
    super.key,
    required this.udp,
    required this.myName,
  });

  @override
  State<NearbyDevicesScreen> createState() => _NearbyDevicesScreenState();
}

class _NearbyDevicesScreenState extends State<NearbyDevicesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final accent = themeProvider.primaryColor;

    return Consumer<PeerProvider>(
      builder: (context, provider, _) {
        final peers = provider.peers;
        final online = peers.where((p) => p.online).toList();
        final offline = peers.where((p) => !p.online).toList();

        if (peers.isEmpty) {
          return _EmptyState(
            isDark: isDark,
            accent: accent,
            pulseController: _pulseController,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (online.isNotEmpty) ...[
              _SectionHeader(
                label: 'Online',
                count: online.length,
                isDark: isDark,
                accent: accent,
              ),
              const SizedBox(height: 8),
              ...online.map((peer) => _DeviceCard(
                    peer: peer,
                    isDark: isDark,
                    accent: accent,
                    myName: widget.myName,
                    udp: widget.udp,
                  )),
            ],
            if (offline.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionHeader(
                label: 'Recently seen',
                count: offline.length,
                isDark: isDark,
                accent: accent,
              ),
              const SizedBox(height: 8),
              ...offline.map((peer) => _DeviceCard(
                    peer: peer,
                    isDark: isDark,
                    accent: accent,
                    myName: widget.myName,
                    udp: widget.udp,
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final AnimationController pulseController;

  const _EmptyState({
    required this.isDark,
    required this.accent,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated scanning rings
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, _) {
              return SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring
                    Opacity(
                      opacity:
                          (1 - pulseController.value).clamp(0.0, 1.0) * 0.3,
                      child: Container(
                        width: 120 * pulseController.value,
                        height: 120 * pulseController.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: accent.withOpacity(0.5), width: 1.5),
                        ),
                      ),
                    ),
                    // Middle ring
                    Opacity(
                      opacity: pulseController.value < 0.5
                          ? pulseController.value * 2 * 0.4
                          : (1 - pulseController.value) * 2 * 0.4,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: accent.withOpacity(0.6), width: 1.5),
                        ),
                      ),
                    ),
                    // Center icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.wifi_find_rounded,
                          color: accent, size: 24),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Scanning for devices',
            style: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure others are on the\nsame Wi-Fi network',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool isDark;
  final Color accent;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMuted(isDark),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Peer peer;
  final bool isDark;
  final Color accent;
  final String myName;
  final UdpChatService udp;

  const _DeviceCard({
    required this.peer,
    required this.isDark,
    required this.accent,
    required this.myName,
    required this.udp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final unread = chatProvider.unreadCount(peer.name);

          return GestureDetector(
            onTap: () {
              chatProvider.openChat(peer.name);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    peer: peer,
                    udp: udp,
                    myName: myName,
                  ),
                ),
              ).then((_) => chatProvider.closeChat());
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: peer.online
                                ? [
                                    accent,
                                    accent.withOpacity(0.6),
                                  ]
                                : [
                                    AppColors.textMuted(isDark),
                                    AppColors.textMuted(isDark)
                                        .withOpacity(0.5),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            peer.name.isNotEmpty
                                ? peer.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (peer.online)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightSurface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          peer.name,
                          style: TextStyle(
                            color: AppColors.textPrimary(isDark),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.router_outlined,
                              size: 12,
                              color: AppColors.textMuted(isDark),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              peer.ip,
                              style: TextStyle(
                                color: AppColors.textMuted(isDark),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right side
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: peer.online
                              ? AppColors.accentGreen.withOpacity(0.12)
                              : (isDark
                                  ? AppColors.darkElevated
                                  : AppColors.lightCard),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          peer.online ? 'online' : 'offline',
                          style: TextStyle(
                            color: peer.online
                                ? AppColors.accentGreen
                                : AppColors.textMuted(isDark),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

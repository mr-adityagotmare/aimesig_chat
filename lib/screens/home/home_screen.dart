import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/udp_chat_service.dart';
import '../../models/peer.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/peer_provider.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';
import '../devices/nearby_devices_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final UdpChatService udp;
  final String username;
  final Function(String) onNameChanged;

  const HomeScreen({
    super.key,
    required this.udp,
    required this.username,
    required this.onNameChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final accent = themeProvider.primaryColor;

    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = AppColors.textPrimary(isDark);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          Container(
            color: bg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.wifi_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aimesig',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          widget.username,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _NetworkBadge(isDark: isDark, accent: accent),
                    const SizedBox(width: 8),
                    _IconBtn(
                      icon: Icons.settings_outlined,
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            onNameChanged: widget.onNameChanged,
                          ),
                        ),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            widget.username.isNotEmpty
                                ? widget.username[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            color: bg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _Tab(
                    label: 'Devices',
                    icon: Icons.devices_rounded,
                    active: _tab == 0,
                    accent: accent,
                    isDark: isDark,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'Chats',
                    icon: Icons.chat_bubble_outline_rounded,
                    active: _tab == 1,
                    accent: accent,
                    isDark: isDark,
                    onTap: () => setState(() => _tab = 1),
                    badge: context.watch<ChatProvider>().totalUnread,
                  ),
                ],
              ),
            ),
          ),

          Container(
            color: bg,
            child: Container(
              height: 1,
              margin: const EdgeInsets.only(top: 16),
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),

          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                NearbyDevicesScreen(udp: widget.udp, myName: widget.username),
                // Pass udp + myName down via the stateful wrapper so the
                // private _ChatsTab can open ChatScreen without a helper method.
                _ChatsTabWrapper(udp: widget.udp, myName: widget.username),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Public wrapper so _ChatsTab can be placed in IndexedStack ────────────────
// Using a public StatelessWidget here means Flutter's compiler can resolve
// ChatScreen (imported above) inside the builder lambda without issues.
class _ChatsTabWrapper extends StatelessWidget {
  final UdpChatService udp;
  final String myName;

  const _ChatsTabWrapper({required this.udp, required this.myName});

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final peerProvider = context.watch<PeerProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final accent = themeProvider.primaryColor;

    final conversations = chatProvider.messages.entries.toList()
      ..sort((a, b) {
        final aLast = a.value.isNotEmpty ? a.value.last.timestamp : 0;
        final bLast = b.value.isNotEmpty ? b.value.last.timestamp : 0;
        return bLast.compareTo(aLast);
      });

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  color: accent, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Go to Devices and tap a peer to start chatting',
              style: TextStyle(
                color: AppColors.textSecondary(isDark),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final entry = conversations[index];
        final peerName = entry.key;
        final msgs = entry.value;
        final lastMsg = msgs.isNotEmpty ? msgs.last : null;
        final unread = chatProvider.unreadCount(peerName);
        final peer = peerProvider.peers
            .where((p) => p.name == peerName)
            .firstOrNull;
        final online = peer?.online ?? false;

        // Always allow opening chat — use offline placeholder if peer not found
        final target = peer ??
            Peer(
              deviceId: peerName,
              name: peerName,
              ip: '',
              port: 0,
              online: false,
              lastSeen: DateTime.now(),
            );

        return _ConversationTile(
          peerName: peerName,
          lastMessage: lastMsg?.message,
          lastTimestamp: lastMsg?.timestamp,
          unreadCount: unread,
          online: online,
          isDark: isDark,
          accent: accent,
          onTap: () {
            chatProvider.openChat(peerName);
            Navigator.push(
              context,
              // Inline ChatScreen directly — avoids private-class resolution bug
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  peer: target,
                  udp: udp,
                  myName: myName,
                ),
              ),
            ).then((_) => chatProvider.closeChat());
          },
        );
      },
    );
  }
}

// Keep _ChatsTab as a thin alias so nothing else breaks if referenced elsewhere
typedef _ChatsTab = _ChatsTabWrapper;

class _NetworkBadge extends StatelessWidget {
  final bool isDark;
  final Color accent;
  const _NetworkBadge({required this.isDark, required this.accent});

  @override
  Widget build(BuildContext context) {
    final peers = context.watch<PeerProvider>().peers;
    final online = peers.where((p) => p.online).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: online > 0
            ? AppColors.accentGreen.withOpacity(0.12)
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: online > 0
              ? AppColors.accentGreen.withOpacity(0.3)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: online > 0 ? AppColors.accentGreen : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            online > 0 ? '$online online' : 'scanning',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: online > 0
                  ? AppColors.accentGreen
                  : AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: AppColors.textSecondary(isDark),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;
  final int badge;

  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.isDark,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? accent.withOpacity(0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? accent : AppColors.textSecondary(isDark),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: active ? accent : AppColors.textSecondary(isDark),
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String peerName;
  final String? lastMessage;
  final int? lastTimestamp;
  final int unreadCount;
  final bool online;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.peerName,
    this.lastMessage,
    this.lastTimestamp,
    required this.unreadCount,
    required this.online,
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(dt).inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (online)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontSize: 15,
                      fontWeight:
                          unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (lastMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unreadCount > 0
                            ? AppColors.textPrimary(isDark)
                            : AppColors.textSecondary(isDark),
                        fontSize: 13,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastTimestamp != null)
                  Text(
                    _formatTime(lastTimestamp!),
                    style: TextStyle(
                      color:
                          unreadCount > 0 ? accent : AppColors.textMuted(isDark),
                      fontSize: 11,
                      fontWeight: unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                const SizedBox(height: 4),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
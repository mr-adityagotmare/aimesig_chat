import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/udp_chat_service.dart';
import '../../models/group.dart';
import '../../models/peer.dart';
import '../../providers/group_provider.dart';
import '../../providers/peer_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class CreateGroupScreen extends StatefulWidget {
  final UdpChatService udp;
  final String myName;
  final String myDeviceId;

  const CreateGroupScreen({
    super.key,
    required this.udp,
    required this.myName,
    required this.myDeviceId,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final Set<String> _selectedDeviceIds = {};
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final groupName = _nameCtrl.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    final peerProvider = context.read<PeerProvider>();
    final selectedPeers = peerProvider.peers
        .where((p) => _selectedDeviceIds.contains(p.deviceId))
        .toList();

    if (selectedPeers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member')),
      );
      return;
    }

    setState(() => _creating = true);

    final groupId =
        '${widget.myDeviceId}_${DateTime.now().millisecondsSinceEpoch}';

    // Creator is always first member
    final memberDeviceIds = [
      widget.myDeviceId,
      ...selectedPeers.map((p) => p.deviceId),
    ];
    final memberNames = [
      widget.myName,
      ...selectedPeers.map((p) => p.name),
    ];

    final group = Group(
      id: groupId,
      name: groupName,
      creatorDeviceId: widget.myDeviceId,
      memberDeviceIds: memberDeviceIds,
      memberNames: memberNames,
      createdAt: DateTime.now(),
    );

    // Save locally
    await context.read<GroupProvider>().addGroup(group);

    // Broadcast invite to each selected peer
    final invitePayload = jsonEncode({
      'type': 'GROUP_INVITE',
      'groupId': groupId,
      'groupName': groupName,
      'creatorDeviceId': widget.myDeviceId,
      'creatorName': widget.myName,
      'memberDeviceIds': memberDeviceIds.join(','),
      'memberNames': memberNames.join(','),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    for (final peer in selectedPeers) {
      widget.udp.sendMessage(ip: peer.ip, data: jsonDecode(invitePayload));
    }

    if (mounted) {
      setState(() => _creating = false);
      Navigator.pop(context, group);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final accent = themeProvider.primaryColor;
    final peers = context.watch<PeerProvider>().peers.where((p) => p.online).toList();

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Group',
            style: TextStyle(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accent))
                : Text('Create',
                    style: TextStyle(
                        color: accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Group name field
          Container(
            color: surface,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [accent, accent.withOpacity(0.6)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Group name',
                      hintStyle: TextStyle(color: textSecondary),
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Members header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text(
                  'SELECT MEMBERS',
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8),
                ),
                const Spacer(),
                if (_selectedDeviceIds.isNotEmpty)
                  Text(
                    '${_selectedDeviceIds.length} selected',
                    style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          // Peer list
          Expanded(
            child: peers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.devices_other_rounded,
                            size: 48,
                            color: textSecondary.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('No devices online',
                            style: TextStyle(
                                color: textSecondary, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                            'Make sure other devices are on\nthe same Wi-Fi network',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: textSecondary.withOpacity(0.6),
                                fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: peers.length,
                    itemBuilder: (context, i) {
                      final peer = peers[i];
                      final selected =
                          _selectedDeviceIds.contains(peer.deviceId);
                      return _MemberTile(
                        peer: peer,
                        selected: selected,
                        isDark: isDark,
                        accent: accent,
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedDeviceIds.remove(peer.deviceId);
                          } else {
                            _selectedDeviceIds.add(peer.deviceId);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Peer peer;
  final bool selected;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;

  const _MemberTile({
    required this.peer,
    required this.selected,
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.1) : surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent.withOpacity(0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: accent.withOpacity(0.15),
                  child: Text(
                    peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: surface, width: 1.5),
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
                  Text(peer.name,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(peer.ip,
                      style:
                          TextStyle(color: textSecondary, fontSize: 11)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? accent : textSecondary.withOpacity(0.4),
                    width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

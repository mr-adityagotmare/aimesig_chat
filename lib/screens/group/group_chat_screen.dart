import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/udp_chat_service.dart';
import '../../models/chat_message.dart';
import '../../models/group.dart';
import '../../providers/group_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;
  final UdpChatService udp;
  final String myName;
  final String myDeviceId;

  const GroupChatScreen({
    super.key,
    required this.group,
    required this.udp,
    required this.myName,
    required this.myDeviceId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final gp = context.read<GroupProvider>();
    gp.openGroup(widget.group.id);
    gp.markGroupRead(widget.group.id);
  }

  @override
  void dispose() {
    context.read<GroupProvider>().closeGroup();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    final gp = context.read<GroupProvider>();
    final group = gp.getGroup(widget.group.id) ?? widget.group;
    final id = '${widget.myDeviceId}_${DateTime.now().millisecondsSinceEpoch}';
    final ts = DateTime.now().millisecondsSinceEpoch;

    // Persist locally
    await gp.addGroupMessage(
      group.id,
      ChatMessage(
        id: id,
        sender: widget.myName,
        receiver: group.id,
        message: text,
        timestamp: ts,
        mine: true,
        delivered: false,
        read: true,
      ),
    );

    // Broadcast to all members via UDP
    final payload = jsonEncode({
      'type': 'GROUP_MESSAGE',
      'groupId': group.id,
      'id': id,
      'sender': widget.myName,
      'senderDeviceId': widget.myDeviceId,
      'message': text,
      'timestamp': ts,
    });

    // We send to each member's IP — PeerProvider holds IPs by deviceId.
    // HomeScreen wires onMessage; we fire-and-forget here.
    // We broadcast the raw payload; the caller (main.dart) handles delivery.
    widget.udp.broadcastToGroup(group: group, payload: payload);

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final accent = themeProvider.primaryColor;
    final gp = context.watch<GroupProvider>();
    final msgs = gp.getGroupMessages(widget.group.id);
    final group = gp.getGroup(widget.group.id) ?? widget.group;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    _scrollToBottom();

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
        title: Row(
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
              child: const Icon(Icons.group_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text(
                    '${group.memberNames.length} members',
                    style:
                        TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded,
                color: textSecondary, size: 20),
            onPressed: () => _showGroupInfo(context, group, isDark, accent),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48, color: textSecondary.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('No messages yet',
                            style: TextStyle(
                                color: textSecondary, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Say hello to the group!',
                            style: TextStyle(
                                color: textSecondary.withOpacity(0.6),
                                fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final msg = msgs[i];
                      final showSender = !msg.mine &&
                          (i == 0 || msgs[i - 1].sender != msg.sender);
                      return _GroupBubble(
                        msg: msg,
                        isDark: isDark,
                        accent: accent,
                        showSenderName: showSender,
                      );
                    },
                  ),
          ),
          _InputBar(
            controller: _ctrl,
            isDark: isDark,
            accent: accent,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  void _showGroupInfo(
      BuildContext context, Group group, bool isDark, Color accent) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                    color: textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Group Info',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(group.name,
                style: TextStyle(color: accent, fontSize: 14)),
            const SizedBox(height: 20),
            Text('Members (${group.memberNames.length})',
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...group.memberNames.map((name) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: accent.withOpacity(0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(name,
                          style: TextStyle(color: textPrimary, fontSize: 14)),
                      if (name == group.memberNames.first) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Creator',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isDark;
  final Color accent;
  final bool showSenderName;

  const _GroupBubble({
    required this.msg,
    required this.isDark,
    required this.accent,
    required this.showSenderName,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);
    final bubbleBg = msg.mine
        ? accent
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final textColor = msg.mine ? Colors.white : textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            msg.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.mine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: accent.withOpacity(0.15),
              child: Text(
                msg.sender.isNotEmpty ? msg.sender[0].toUpperCase() : '?',
                style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showSenderName && !msg.mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 2),
                    child: Text(msg.sender,
                        style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(msg.mine ? 16 : 4),
                      bottomRight: Radius.circular(msg.mine ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(msg.message,
                          style:
                              TextStyle(color: textColor, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(msg.timestamp),
                        style: TextStyle(
                            color: msg.mine
                                ? Colors.white70
                                : textSecondary,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color accent;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isDark,
    required this.accent,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message group...',
                    hintStyle:
                        TextStyle(color: textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

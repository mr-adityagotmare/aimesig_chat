import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/udp_chat_service.dart';
import '../../models/peer.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final Peer peer;
  final UdpChatService udp;
  final String myName;

  const ChatScreen({
    super.key,
    required this.peer,
    required this.udp,
    required this.myName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSendButton = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _showSendButton = _controller.text.trim().isNotEmpty);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ChatProvider>();
      await provider.markChatRead(widget.peer.name);
      final msgs = provider.getMessages(widget.peer.name);
      for (final msg in msgs) {
        if (!msg.mine) {
          widget.udp.sendMessage(
              ip: widget.peer.ip, data: {'type': 'READ', 'id': msg.id});
        }
      }
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().closeChat();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      }
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() => _showSendButton = false);

    final provider = context.read<ChatProvider>();
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();

    final msg = ChatMessage(
      id: msgId,
      sender: widget.myName,
      receiver: widget.peer.name,
      message: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      mine: true,
    );

    await provider.addMessage(widget.peer.name, msg);

    widget.udp.sendMessage(ip: widget.peer.ip, data: {
      'type': 'MESSAGE',
      'id': msgId,
      'sender': widget.myName,
      'message': text,
      'timestamp': msg.timestamp,
    });

    _scrollToBottom(animated: true);
  }

  String _formatTime(int ts) {
    final t = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateHeader(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return 'Today';
    } else if (now.difference(dt).inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
    }
  }

  String _monthName(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }

  bool _isNewDay(List<ChatMessage> msgs, int index) {
    if (index == 0) return true;
    final curr = DateTime.fromMillisecondsSinceEpoch(msgs[index].timestamp);
    final prev = DateTime.fromMillisecondsSinceEpoch(msgs[index - 1].timestamp);
    return curr.day != prev.day ||
        curr.month != prev.month ||
        curr.year != prev.year;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final accent = themeProvider.primaryColor;
    final fontSize = themeProvider.chatFontSize;
    final showTimestamps = themeProvider.showTimestamps;

    final msgs = context.watch<ChatProvider>().getMessages(widget.peer.name);

    // Auto scroll on new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        final current = _scrollController.offset;
        if (max - current < 200) {
          _scrollController.jumpTo(max);
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFEAEFF4),
      appBar: _buildAppBar(isDark, accent),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: msgs.isEmpty
                ? _buildEmptyChat(isDark, accent)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    itemCount: msgs.length,
                    itemBuilder: (context, index) {
                      final msg = msgs[index];
                      final showDate = _isNewDay(msgs, index);

                      return Column(
                        children: [
                          if (showDate) _DateDivider(
                            label: _formatDateHeader(msg.timestamp),
                            isDark: isDark,
                          ),
                          _ChatBubble(
                            msg: msg,
                            isDark: isDark,
                            accent: accent,
                            fontSize: fontSize,
                            showTimestamp: showTimestamps,
                            formatTime: _formatTime,
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Input area
          _buildInputBar(isDark, accent),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color accent) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.textPrimary(isDark),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    widget.peer.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (widget.peer.online)
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurface
                            : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.peer.name,
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                widget.peer.online ? 'online · ${widget.peer.ip}' : 'offline',
                style: TextStyle(
                  color: widget.peer.online
                      ? AppColors.accentGreen
                      : AppColors.textMuted(isDark),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: AppColors.textSecondary(isDark),
          ),
          color: isDark ? AppColors.darkCard : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (value) async {
            final provider = context.read<ChatProvider>();
            if (value == 'clear') {
              final confirmed = await _confirmDialog(
                  context, 'Clear chat', 'All messages will be deleted.');
              if (confirmed == true) await provider.clearChat(widget.peer.name);
            } else if (value == 'delete') {
              final confirmed = await _confirmDialog(
                  context, 'Delete conversation',
                  'This conversation will be removed.');
              if (confirmed == true) {
                await provider.deleteChat(widget.peer.name);
                if (mounted) Navigator.pop(context);
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.cleaning_services_outlined,
                      size: 18,
                      color: AppColors.textSecondary(isDark)),
                  const SizedBox(width: 10),
                  Text('Clear chat',
                      style:
                          TextStyle(color: AppColors.textPrimary(isDark))),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  const SizedBox(width: 10),
                  const Text('Delete conversation',
                      style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<bool?> _confirmDialog(
      BuildContext context, String title, String body) {
    final isDark = context.read<ThemeProvider>().isDark;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w700)),
        content: Text(body,
            style: TextStyle(color: AppColors.textSecondary(isDark))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppColors.textSecondary(isDark))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(bool isDark, Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.waving_hand_rounded,
                color: accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            'Say hello to ${widget.peer.name}!',
            style: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Messages are sent over your local network',
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, Color accent) {
    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message ${widget.peer.name}...',
                      hintStyle:
                          TextStyle(color: AppColors.textMuted(isDark)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                width: _showSendButton ? 48 : 48,
                height: 48,
                child: GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _showSendButton
                            ? [accent, accent.withOpacity(0.7)]
                            : [
                                AppColors.textMuted(isDark),
                                AppColors.textMuted(isDark),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final String label;
  final bool isDark;

  const _DateDivider({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: AppColors.darkBorder.withOpacity(0.5), thickness: 0.5)),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.darkCard.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary(isDark),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Divider(
                  color: AppColors.darkBorder.withOpacity(0.5), thickness: 0.5)),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isDark;
  final Color accent;
  final double fontSize;
  final bool showTimestamp;
  final String Function(int) formatTime;

  const _ChatBubble({
    required this.msg,
    required this.isDark,
    required this.accent,
    required this.fontSize,
    required this.showTimestamp,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: msg.mine ? 60 : 0,
          right: msg.mine ? 0 : 60,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.mine
              ? accent.withOpacity(isDark ? 0.22 : 0.15)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.mine ? 18 : 4),
            bottomRight: Radius.circular(msg.mine ? 4 : 18),
          ),
          border: Border.all(
            color: msg.mine
                ? accent.withOpacity(0.2)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                msg.message,
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: fontSize,
                  height: 1.4,
                ),
              ),
            ),
            if (showTimestamp) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatTime(msg.timestamp),
                    style: TextStyle(
                      color: AppColors.textMuted(isDark),
                      fontSize: 10,
                    ),
                  ),
                  if (msg.mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.read
                          ? Icons.done_all_rounded
                          : msg.delivered
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                      size: 14,
                      color: msg.read
                          ? accent
                          : AppColors.textMuted(isDark),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/udp_chat_service.dart';

import '../../models/peer.dart';
import '../../models/chat_message.dart';

import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';

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
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    context
        .read<ChatProvider>()
        .openChat(widget.peer.name);

    WidgetsBinding.instance
        .addPostFrameCallback((_) async {
      final provider =
          context.read<ChatProvider>();

      await provider.markChatRead(
        widget.peer.name,
      );

      final msgs =
          provider.getMessages(widget.peer.name);

      for (final msg in msgs) {
        if (!msg.mine) {
          widget.udp.sendMessage(
            ip: widget.peer.ip,
            data: {
              "type": "READ",
              "id": msg.id,
            },
          );
        }
      }
    });
  }

  @override
  void dispose() {
    context
        .read<ChatProvider>()
        .closeChat();

    controller.dispose();

    super.dispose();
  }

  void sendMessage() async {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    controller.clear();

    final provider =
        context.read<ChatProvider>();

    final msgId =
        DateTime.now()
            .millisecondsSinceEpoch
            .toString();

    final msg = ChatMessage(
      id: msgId,

      sender: widget.myName,
      receiver: widget.peer.name,

      message: text,

      timestamp:
          DateTime.now().millisecondsSinceEpoch,

      mine: true,
    );

    await provider.addMessage(
      widget.peer.name,
      msg,
    );

    widget.udp.sendMessage(
      ip: widget.peer.ip,
      data: {
        "type": "MESSAGE",
        "id": msgId,
        "sender": widget.myName,
        "message": text,
        "timestamp": msg.timestamp,
      },
    );
  }

  String formatTime(int ts) {
    final time =
        DateTime.fromMillisecondsSinceEpoch(ts);

    final hh =
        time.hour.toString().padLeft(2, '0');

    final mm =
        time.minute.toString().padLeft(2, '0');

    return "$hh:$mm";
  }

  Widget buildBubble({
    required ChatMessage msg,
    required bool isDark,
    required Color accent,
  }) {
    return Align(
      alignment: msg.mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 3,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),

        constraints: const BoxConstraints(
          maxWidth: 320,
        ),

        decoration: BoxDecoration(
          color: msg.mine
              ? (isDark
                  ? accent.withOpacity(0.25)
                  : const Color(0xFFDCF8C5))
              : (isDark
                  ? const Color(0xFF202C33)
                  : Colors.white),

          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(
              msg.mine ? 18 : 4,
            ),
            bottomRight: Radius.circular(
              msg.mine ? 4 : 18,
            ),
          ),

          boxShadow: const [
            BoxShadow(
              blurRadius: 2,
              color: Colors.black12,
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                msg.message,
                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTime(msg.timestamp),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : Colors.black54,
                    fontSize: 11,
                  ),
                ),

                if (msg.mine)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      left: 4,
                    ),

                    child: Icon(
                      msg.read
                          ? Icons.done_all
                          : msg.delivered
                              ? Icons.done_all
                              : Icons.done,

                      size: 17,

                      color: msg.read
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgs = context
        .watch<ChatProvider>()
        .getMessages(widget.peer.name);

    final themeProvider =
        context.watch<ThemeProvider>();

    final isDark = themeProvider.isDark;

    final accent =
        themeProvider.primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B141A)
          : const Color(0xFFEDEDED),

      appBar: AppBar(
        elevation: 0.5,

        backgroundColor:
            isDark ? Colors.black : Colors.white,

        foregroundColor:
            isDark ? Colors.white : Colors.black,

        titleSpacing: 0,

        title: Row(
          children: [
            CircleAvatar(
              radius: 20,

              backgroundColor: accent,

              child: Text(
                widget.peer.name[0]
                    .toUpperCase(),

                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peer.name,

                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  widget.peer.online
                      ? 'online'
                      : 'offline',

                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white70
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final provider =
                  context.read<ChatProvider>();

              if (value == 'clear') {
                await provider.clearChat(
                  widget.peer.name,
                );
              }

              if (value == 'delete') {
                await provider.deleteChat(
                  widget.peer.name,
                );

                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },

            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear Chat'),
              ),

              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Chat'),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: 10,
                bottom: 10,
              ),

              itemCount: msgs.length,

              itemBuilder: (context, index) {
                final msg = msgs[index];

                return buildBubble(
                  msg: msg,
                  isDark: isDark,
                  accent: accent,
                );
              },
            ),
          ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8),

              color: isDark
                  ? const Color(0xFF111B21)
                  : const Color(0xFFF7F7F7),

              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(
                                0xFF202C33)
                            : Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          28,
                        ),
                      ),

                      child: TextField(
                        controller: controller,

                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : Colors.black87,
                        ),

                        decoration:
                            const InputDecoration(
                          hintText: 'Message',

                          border:
                              InputBorder.none,

                          contentPadding:
                              EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: sendMessage,

                    child: Container(
                      width: 50,
                      height: 50,

                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
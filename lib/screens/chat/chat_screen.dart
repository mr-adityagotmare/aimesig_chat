import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../core/network/file_transfer_service.dart';
import '../../core/network/udp_chat_service.dart';
import '../../models/chat_message.dart';
import '../../models/peer.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/call_provider.dart'; // NEW
import '../../widgets/active_call_banner.dart';
import '../call/active_call_screen.dart'; // NEW
import '../../providers/video_call_provider.dart';
import '../call/active_video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final Peer peer;
  final UdpChatService udp;
  final FileTransferService fileTransfer;
  final String myName;

  const ChatScreen({
    super.key,
    required this.peer,
    required this.udp,
    required this.fileTransfer,
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
    _controller.addListener(
        () => setState(() => _showSendButton = _controller.text.trim().isNotEmpty));

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
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // ── Send text ────────────────────────────────────────────────────────────────

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

  // ── Send file ────────────────────────────────────────────────────────────────

  Future<void> _pickAndSendFile() async {
    if (!widget.peer.online) {
      _showSnack('Peer is offline');
      return;
    }

    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    if (picked.path == null) return;

    HapticFeedback.mediumImpact();

    final provider = context.read<ChatProvider>();
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final filePath = picked.path!;
    final fileName = picked.name;
    final fileSize = picked.size;
    final isImg = _isImageName(fileName);

    // Add a placeholder message immediately
    final msg = ChatMessage(
      id: msgId,
      sender: widget.myName,
      receiver: widget.peer.name,
      message: fileName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      mine: true,
      type: isImg ? MessageType.image : MessageType.file,
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      transferProgress: 0.0,
    );

    await provider.addMessage(widget.peer.name, msg);
    _scrollToBottom(animated: true);

    // Wire up send progress
    widget.fileTransfer.sendFile(
      peerIp: widget.peer.ip,
      filePath: filePath,
      onProgress: (id, sent, total, state) {
        final progress = total > 0 ? sent / total : 0.0;
        if (state == SendState.done) {
          provider.markDelivered(msgId);
          provider.updateTransferProgress(msgId, 1.0);
        } else if (state == SendState.failed) {
          provider.markTransferFailed(msgId);
        } else {
          provider.updateTransferProgress(msgId, progress);
        }
      },
    );
  }

  // ── Retry failed send ────────────────────────────────────────────────────────

  void _retryFileSend(ChatMessage msg) {
    if (!widget.peer.online) {
      _showSnack('Peer is offline — cannot retry yet');
      return;
    }
    if (msg.filePath == null || !File(msg.filePath!).existsSync()) {
      _showSnack('Original file no longer exists');
      return;
    }

    final provider = context.read<ChatProvider>();

    // Reset failure flag and progress so the bubble switches back to "Sending"
    provider.resetTransferFailed(msg.id);

    widget.fileTransfer.sendFile(
      peerIp: widget.peer.ip,
      filePath: msg.filePath!,
      onProgress: (id, sent, total, state) {
        final progress = total > 0 ? sent / total : 0.0;
        if (state == SendState.done) {
          provider.markDelivered(msg.id);
          provider.updateTransferProgress(msg.id, 1.0);
        } else if (state == SendState.failed) {
          provider.markTransferFailed(msg.id);
        } else {
          provider.updateTransferProgress(msg.id, progress);
        }
      },
    );
  }

  bool _isImageName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

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
    }
    return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final accent = themeProvider.primaryColor;
    final fontSize = themeProvider.chatFontSize;
    final showTimestamps = themeProvider.showTimestamps;

    final msgs = context.watch<ChatProvider>().getMessages(widget.peer.name);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        if (max - _scrollController.offset < 200) {
          _scrollController.jumpTo(max);
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFEAEFF4),
      appBar: _buildAppBar(isDark, accent),
      body: Column(
        children: [
          // In-call banner — tap to return to active call
          const ActiveCallBanner(),
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
                      return Column(
                        children: [
                          if (_isNewDay(msgs, index))
                            _DateDivider(
                              label: _formatDateHeader(msg.timestamp),
                              isDark: isDark,
                            ),
                          if (msg.isFile)
                            _FileBubble(
                              msg: msg,
                              isDark: isDark,
                              accent: accent,
                              showTimestamp: showTimestamps,
                              formatTime: _formatTime,
                              onRetry: msg.transferFailed && msg.mine
                                  ? () => _retryFileSend(msg)
                                  : null,
                            )
                          else
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
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.textPrimary(isDark)),
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
                        fontSize: 16),
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
                        color: isDark ? AppColors.darkSurface : Colors.white,
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
              Text(widget.peer.name,
                  style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3)),
              Text(
                widget.peer.online
                    ? 'online · ${widget.peer.ip}'
                    : 'offline',
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
        // NEW: Voice call button
        if (widget.peer.online)
          IconButton(
            icon: Icon(Icons.call_rounded,
                color: AppColors.textSecondary(isDark), size: 22),
            tooltip: 'Voice call',
            onPressed: () async {
              final cp = context.read<CallProvider>();
              if (cp.hasActiveCall) return; // already in a call
              await cp.startIndividualCall(
                peerIp: widget.peer.ip,
                peerName: widget.peer.name,
                peerDeviceId: widget.peer.deviceId,
              );
              if (mounted) {
                Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (_) => const ActiveCallScreen(),
                ));
              }
            },
          ),
          // Video call button — add BEFORE the existing voice call button
        if (widget.peer.online)
          IconButton(
            icon: Icon(Icons.videocam_rounded,
                color: AppColors.textSecondary(isDark), size: 24),
            tooltip: 'Video call',
            onPressed: () async {
              final vcp = context.read<VideoCallProvider>();
              if (vcp.hasActiveCall) return;
              await vcp.service?.initRenderers();
              await vcp.startIndividualCall(
                peerIp: widget.peer.ip,
                peerName: widget.peer.name,
                peerDeviceId: widget.peer.deviceId,
              );
              if (mounted) {
                Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (_) => const ActiveVideoCallScreen(),
                ));
              }
            },
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: AppColors.textSecondary(isDark)),
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
              final confirmed = await _confirmDialog(context,
                  'Delete conversation', 'This conversation will be removed.');
              if (confirmed == true) {
                await provider.deleteChat(widget.peer.name);
                if (mounted) Navigator.pop(context);
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'clear',
              child: Row(children: [
                Icon(Icons.cleaning_services_outlined,
                    size: 18, color: AppColors.textSecondary(isDark)),
                const SizedBox(width: 10),
                Text('Clear chat',
                    style: TextStyle(color: AppColors.textPrimary(isDark))),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.red),
                const SizedBox(width: 10),
                const Text('Delete conversation',
                    style: TextStyle(color: Colors.red)),
              ]),
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
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                style: TextStyle(color: AppColors.textSecondary(isDark))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Confirm', style: TextStyle(color: Colors.red)),
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
            child:
                Icon(Icons.waving_hand_rounded, color: accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text('Say hello to ${widget.peer.name}!',
              style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Messages are sent over your local network',
              style: TextStyle(
                  color: AppColors.textSecondary(isDark), fontSize: 13)),
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
              // Attach button
              GestureDetector(
                onTap: _pickAndSendFile,
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Icon(Icons.attach_file_rounded,
                      size: 20,
                      color: widget.peer.online
                          ? accent
                          : AppColors.textMuted(isDark)),
                ),
              ),

              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkCard : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        color: AppColors.textPrimary(isDark), fontSize: 15),
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

              // Send button
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 48,
                  height: 48,
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
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── File Bubble ───────────────────────────────────────────────────────────────

class _FileBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isDark;
  final Color accent;
  final bool showTimestamp;
  final String Function(int) formatTime;
  final VoidCallback? onRetry;

  const _FileBubble({
    required this.msg,
    required this.isDark,
    required this.accent,
    required this.showTimestamp,
    required this.formatTime,
    this.onRetry,
  });

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Derive a human-readable status label + colour from message state.
  _StatusInfo _status(bool hasFile, bool inProgress) {
    if (msg.transferFailed) {
      return _StatusInfo(
        label: msg.mine ? 'Failed · tap to retry' : 'Transfer failed',
        color: Colors.red,
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red,
      );
    }
    if (hasFile) {
      return _StatusInfo(
        label: _formatSize(msg.fileSize),
        color: null, // use textMuted
        icon: msg.isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
        iconColor: null, // use accent
      );
    }
    if (inProgress) {
      final pct = (msg.transferProgress * 100).toStringAsFixed(0);
      final label = msg.mine
          ? (msg.transferProgress == 0 ? 'Waiting…' : 'Sending $pct%')
          : 'Receiving $pct%';
      return _StatusInfo(
        label: label,
        color: null,
        icon: Icons.hourglass_top_rounded,
        iconColor: null,
      );
    }
    // Stuck at 0 before offer accepted
    return _StatusInfo(
      label: msg.mine ? 'Offering…' : 'Incoming…',
      color: null,
      icon: Icons.upload_rounded,
      iconColor: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImg = msg.isImage;
    final hasFile = msg.filePath != null && File(msg.filePath!).existsSync();
    final inProgress = !msg.transferFailed &&
        msg.transferProgress < 1.0 &&
        !hasFile;

    final status = _status(hasFile, inProgress);

    return Align(
      alignment: msg.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (hasFile) {
            OpenFilex.open(msg.filePath!);
          } else if (msg.transferFailed && msg.mine) {
            onRetry?.call();
          }
        },
        child: Container(
          margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: msg.mine ? 60 : 0,
            right: msg.mine ? 0 : 60,
          ),
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
              color: msg.transferFailed
                  ? Colors.red.withOpacity(0.4)
                  : msg.mine
                      ? accent.withOpacity(0.2)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image preview
              if (isImg && hasFile)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17)),
                  child: Image.file(
                    File(msg.filePath!),
                    width: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: msg.transferFailed
                                ? Colors.red.withOpacity(0.12)
                                : accent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            status.icon,
                            color: status.iconColor ?? accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Name + status
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.fileName ?? msg.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary(isDark),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                status.label,
                                style: TextStyle(
                                  color: status.color ??
                                      AppColors.textMuted(isDark),
                                  fontSize: 11,
                                  fontWeight: msg.transferFailed
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Right-side action icon
                        if (hasFile)
                          Icon(Icons.open_in_new_rounded,
                              size: 16, color: AppColors.textMuted(isDark))
                        else if (msg.transferFailed && msg.mine)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded,
                                    size: 12, color: Colors.red),
                                SizedBox(width: 3),
                                Text('Retry',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        else if (inProgress && !msg.mine)
                          // Receiver sees a download spinner
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          ),
                      ],
                    ),

                    // Progress bar (sender and receiver while transferring)
                    if (inProgress && msg.transferProgress > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: msg.transferProgress,
                          backgroundColor: accent.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(accent),
                          minHeight: 4,
                        ),
                      ),
                    ],

                    // Timestamp + tick
                    if (showTimestamp) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatTime(msg.timestamp),
                            style: TextStyle(
                                color: AppColors.textMuted(isDark),
                                fontSize: 10),
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
            ],
          ),
        ),
      ),
    );
  }
}

// Simple data class for bubble status display
class _StatusInfo {
  final String label;
  final Color? color;
  final IconData icon;
  final Color? iconColor;
  const _StatusInfo({
    required this.label,
    required this.color,
    required this.icon,
    required this.iconColor,
  });
}

// ── Text Bubble ───────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    height: 1.4),
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
                        color: AppColors.textMuted(isDark), fontSize: 10),
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
                      color: msg.read ? accent : AppColors.textMuted(isDark),
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

// ── Date divider ──────────────────────────────────────────────────────────────

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
                  color: AppColors.darkBorder.withOpacity(0.5),
                  thickness: 0.5)),
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
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Divider(
                  color: AppColors.darkBorder.withOpacity(0.5),
                  thickness: 0.5)),
        ],
      ),
    );
  }
}
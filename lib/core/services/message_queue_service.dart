import 'dart:async';

import '../../models/chat_message.dart';
import '../../models/peer.dart';
import '../../providers/chat_provider.dart';
import '../../providers/peer_provider.dart';
import '../network/udp_chat_service.dart';

/// Watches for peers coming back online and retries any messages that were
/// sent while they were offline (i.e. mine == true && delivered == false).
class MessageQueueService {
  final ChatProvider _chatProvider;
  final PeerProvider _peerProvider;
  final UdpChatService _udp;
  final String myName;

  Timer? _retryTimer;

  // Tracks which peer IPs we already attempted in the current cycle so we
  // don't spam the same peer multiple times per tick.
  final Set<String> _retriedThisCycle = {};

  MessageQueueService({
    required ChatProvider chatProvider,
    required PeerProvider peerProvider,
    required UdpChatService udp,
    required this.myName,
  })  : _chatProvider = chatProvider,
        _peerProvider = peerProvider,
        _udp = udp;

  /// Start the retry loop. Call this right after startServices() in main.
  void start() {
    _retryTimer?.cancel();
    // Check every 3 seconds – fast enough to feel instant, slow enough not
    // to flood the network.
    _retryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _retriedThisCycle.clear();
      _retryUndelivered();
    });
  }

  void stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _retryUndelivered() {
    final onlinePeers = _peerProvider.peers.where((p) => p.online).toList();
    if (onlinePeers.isEmpty) return;

    for (final peer in onlinePeers) {
      if (_retriedThisCycle.contains(peer.ip)) continue;

      final pending = _getPendingMessages(peer.name);
      if (pending.isEmpty) continue;

      _retriedThisCycle.add(peer.ip);

      for (final msg in pending) {
        _sendMessage(peer, msg);
      }
    }
  }

  /// Returns messages to this peer that we sent but never got a DELIVERED ack.
  List<ChatMessage> _getPendingMessages(String peerName) {
    return _chatProvider
        .getMessages(peerName)
        .where((m) => m.mine && !m.delivered)
        .toList();
  }

  void _sendMessage(Peer peer, ChatMessage msg) {
    _udp.sendMessage(ip: peer.ip, data: {
      'type': 'MESSAGE',
      'id': msg.id,
      'sender': myName,
      'message': msg.message,
      'timestamp': msg.timestamp,
    });
  }
}
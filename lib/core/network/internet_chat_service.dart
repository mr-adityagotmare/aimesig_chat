import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../models/group.dart';
import '../../providers/peer_provider.dart';

/// Drop-in internet replacement for [UdpChatService].
///
/// All callers that talk to UdpChatService use the same interface here so
/// no chat / call / group logic needs to change.
class InternetChatService {
  static const String _serverUrl = 'https://aimapp-server.onrender.com';

  IO.Socket? _socket;

  /// Injected so [broadcastToGroup] can resolve deviceIds → peerIds.
  PeerProvider? peerProvider;

  /// Called whenever a message arrives.
  /// The `ip` parameter is the sender's deviceId when in internet mode.
  Function(String senderDeviceId, Map<String, dynamic> data)? onMessage;

  /// Our own deviceId and display name – set before calling [start].
  String myDeviceId = '';
  String myName = '';

  bool _connected = false;
  bool get isConnected => _connected;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(99999)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      print('INTERNET CHAT CONNECTED');
      // Register this device on the server so others can discover us.
      _socket!.emit('register', {
        'deviceId': myDeviceId,
        'name': myName,
      });
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      print('INTERNET CHAT DISCONNECTED');
    });

    _socket!.on('message', (raw) {
      try {
        final data = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : Map<String, dynamic>.from(raw as Map);
        final sender = data['_senderId'] as String? ?? '';
        print('INTERNET MESSAGE <= $data');
        onMessage?.call(sender, data);
      } catch (e) {
        print('INTERNET MESSAGE ERROR => $e');
      }
    });

    _socket!.connect();
  }

  // ── sending ────────────────────────────────────────────────────────────────

  /// [ip] here is the RECIPIENT's deviceId (we keep the same param name so
  /// callers compiled against UdpChatService work without changes).
  void sendMessage({
    required String ip, // = recipient deviceId in internet mode
    required Map<String, dynamic> data,
  }) {
    if (_socket == null || ip.isEmpty) return;
    final payload = Map<String, dynamic>.from(data);
    payload['_senderId'] = myDeviceId;
    print('INTERNET SEND => $payload to $ip');
    _socket!.emit('send_message', {
      'to': ip,
      'data': payload,
    });
  }

  /// Broadcast a group message to all online group members.
  void broadcastToGroup({
    required Group group,
    required String payload,
  }) {
    if (_socket == null) return;
    final provider = peerProvider;
    if (provider == null) return;

    final data = jsonDecode(payload) as Map<String, dynamic>;

    for (final peer in provider.peers) {
      if (group.memberDeviceIds.contains(peer.deviceId)) {
        sendMessage(ip: peer.deviceId, data: data);
      }
    }
  }

  // ── discovery ──────────────────────────────────────────────────────────────

  /// Subscribe to peer-presence events from the server.
  void listenForPeers(Function(Map<String, dynamic>) onPeerFound) {
    _socket?.on('peer_online', (raw) {
      try {
        final data = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : Map<String, dynamic>.from(raw as Map);
        if (data['deviceId'] == myDeviceId) return;
        onPeerFound({
          'deviceId': data['deviceId'],
          'name': data['name'],
          // use deviceId as "ip" so all IP-keyed logic still works
          'ip': data['deviceId'],
          'port': 0,
          'online': true,
        });
        print('INTERNET PEER FOUND => ${data['name']}');
      } catch (e) {
        print('INTERNET PEER EVENT ERROR => $e');
      }
    });

    _socket?.on('peer_offline', (raw) {
      try {
        final data = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : Map<String, dynamic>.from(raw as Map);
        onPeerFound({
          'deviceId': data['deviceId'],
          'name': data['name'] ?? '',
          'ip': data['deviceId'],
          'port': 0,
          'online': false,
        });
      } catch (e) {
        print('INTERNET PEER OFFLINE ERROR => $e');
      }
    });

    // Also ask the server for currently online peers
    _socket?.emit('get_online_peers', {});
    _socket?.on('online_peers', (raw) {
      try {
        final List peers = raw is String ? jsonDecode(raw) : raw;
        for (final p in peers) {
          final peer = Map<String, dynamic>.from(p as Map);
          if (peer['deviceId'] == myDeviceId) continue;
          onPeerFound({
            'deviceId': peer['deviceId'],
            'name': peer['name'],
            'ip': peer['deviceId'],
            'port': 0,
            'online': true,
          });
        }
      } catch (e) {
        print('INTERNET ONLINE PEERS ERROR => $e');
      }
    });
  }

  void stop() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }
}

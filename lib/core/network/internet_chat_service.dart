import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../models/group.dart';
import '../../providers/peer_provider.dart';

/// Internet relay service — v2
///
/// Key improvements over v1:
///  • Peer listeners are always registered BEFORE connect() so no events are missed.
///  • Client sends a heartbeat every 20s so the server never times us out and
///    PeerProvider.lastSeen is refreshed for all known peers.
///  • listenForPeers() can be called before or after start(); the callback is
///    stored and applied on the next connect event.
///  • Exponential back-off reconnection (handled by socket.io).
class InternetChatService {
  static const String _serverUrl = 'https://aimapp-server.onrender.com';
  static const Duration _heartbeatInterval = Duration(seconds: 20);

  IO.Socket? _socket;
  Timer? _heartbeatTimer;

  PeerProvider? peerProvider;

  Function(String senderDeviceId, Map<String, dynamic> data)? onMessage;
  Function(Map<String, dynamic>)? _onPeerFound;

  String myDeviceId = '';
  String myName = '';

  bool _connected = false;
  bool get isConnected => _connected;

  // ── lifecycle ────────────────────────────────────────────────────────────────

  Future<void> start() async {
    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()   // we call connect() ourselves below
          .enableReconnection()
          .setReconnectionAttempts(99999)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .build(),
    );

    // ── Register all event handlers BEFORE calling connect() ─────────────────
    // This guarantees we never miss an event due to a fast connection.

    _socket!.onConnect((_) {
      _connected = true;
      print('[ICS] connected');

      // (Re-)register with the server.
      _socket!.emit('register', {'deviceId': myDeviceId, 'name': myName});

      // Ask for the full list of currently online peers.
      _socket!.emit('get_online_peers', {});

      // Start heartbeat.
      _startHeartbeat();
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      print('[ICS] disconnected');
    });

    // ── Peer presence ─────────────────────────────────────────────────────────

    _socket!.on('peer_online', (raw) {
      try {
        final data = _toMap(raw);
        final dId = data['deviceId'] as String?;
        if (dId == null || dId == myDeviceId) return;
        _onPeerFound?.call({
          'deviceId': dId,
          'name': data['name'] ?? '',
          'ip': dId,
          'port': 0,
          'online': true,
        });
        print('[ICS] peer_online => $dId');
      } catch (e) {
        print('[ICS] peer_online error => $e');
      }
    });

    _socket!.on('peer_offline', (raw) {
      try {
        final data = _toMap(raw);
        final dId = data['deviceId'] as String?;
        if (dId == null) return;
        _onPeerFound?.call({
          'deviceId': dId,
          'name': data['name'] ?? '',
          'ip': dId,
          'port': 0,
          'online': false,
        });
        print('[ICS] peer_offline => $dId');
      } catch (e) {
        print('[ICS] peer_offline error => $e');
      }
    });

    _socket!.on('online_peers', (raw) {
      try {
        final List list = raw is String ? jsonDecode(raw) : (raw as List);
        for (final p in list) {
          final peer = Map<String, dynamic>.from(p as Map);
          final dId = peer['deviceId'] as String?;
          if (dId == null || dId == myDeviceId) continue;
          _onPeerFound?.call({
            'deviceId': dId,
            'name': peer['name'] ?? '',
            'ip': dId,
            'port': 0,
            'online': true,
          });
        }
        print('[ICS] online_peers => ${list.length} peers');
      } catch (e) {
        print('[ICS] online_peers error => $e');
      }
    });

    // ── Messages ──────────────────────────────────────────────────────────────

    _socket!.on('message', (raw) {
      try {
        final data = _toMap(raw);
        final sender = data['_senderId'] as String? ?? '';
        print('[ICS] message <= type=${data['type']} from=$sender');
        onMessage?.call(sender, data);
      } catch (e) {
        print('[ICS] message error => $e');
      }
    });

    // ── Heartbeat ack (optional — server echoes back) ─────────────────────────
    _socket!.on('heartbeat_ack', (_) {
      // Refresh lastSeen for all known online peers via the provider.
      // This keeps PeerProvider from pruning them.
      _refreshAllPeers();
    });

    // Connect now that all handlers are in place.
    _socket!.connect();
  }

  // ── Heartbeat ────────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_connected) {
        _socket!.emit('heartbeat', {'deviceId': myDeviceId});
        // Also ask for the fresh peer list every heartbeat so newly connected
        // peers show up even if their peer_online event was missed.
        _socket!.emit('get_online_peers', {});
        print('[ICS] heartbeat sent');
      }
    });
  }

  /// Tell PeerProvider to refresh lastSeen for all currently online peers so
  /// the cleanup timer doesn't evict them.
  void _refreshAllPeers() {
    final provider = peerProvider;
    if (provider == null) return;
    for (final peer in provider.peers) {
      if (peer.online) {
        provider.refreshLastSeen(peer.deviceId);
      }
    }
  }

  // ── Sending ───────────────────────────────────────────────────────────────────

  void sendMessage({
    required String ip, // = recipient deviceId in internet mode
    required Map<String, dynamic> data,
  }) {
    if (_socket == null || ip.isEmpty) return;
    final payload = Map<String, dynamic>.from(data);
    payload['_senderId'] = myDeviceId;
    print('[ICS] send => type=${data['type']} to=$ip');
    _socket!.emit('send_message', {'to': ip, 'data': payload});
  }

  void broadcastToGroup({required Group group, required String payload}) {
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

  // ── Discovery ─────────────────────────────────────────────────────────────────

  /// Call at any point — before or after [start].
  void listenForPeers(Function(Map<String, dynamic>) onPeerFound) {
    _onPeerFound = onPeerFound;
    // If already connected, ask for peers immediately.
    if (_connected) {
      _socket?.emit('get_online_peers', {});
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────────

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _onPeerFound = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
    return Map<String, dynamic>.from(raw as Map);
  }
}

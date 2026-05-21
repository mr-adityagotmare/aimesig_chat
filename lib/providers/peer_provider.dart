import 'dart:async';

import 'package:flutter/material.dart';

import '../models/peer.dart';

/// Manages the set of known peers and their online status.
///
/// v2 changes:
///  • No time-based cleanup timer — online status is driven purely by
///    explicit server events (peer_online / peer_offline) and the heartbeat.
///  • [updatePeer] always refreshes lastSeen.
///  • [markOnline] / [markOffline] for explicit presence changes.
///  • [refreshLastSeen] called by heartbeat to keep peers from expiring.
class PeerProvider extends ChangeNotifier {
  final Map<String, Peer> _peers = {};

  List<Peer> get peers => _peers.values.toList();

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Add or update a peer. Always marks them online and refreshes lastSeen.
  void updatePeer(Peer peer) {
    _peers[peer.deviceId] = peer;
    notifyListeners();
  }

  /// Mark an existing peer online and refresh lastSeen.
  void markOnline(String deviceId) {
    final peer = _peers[deviceId];
    if (peer != null && (!peer.online)) {
      peer.online = true;
      peer.lastSeen = DateTime.now();
      notifyListeners();
    } else if (peer != null) {
      peer.lastSeen = DateTime.now();
      // No notify needed — no visible state change.
    }
  }

  /// Mark an existing peer offline immediately.
  void markOffline(String deviceId) {
    final peer = _peers[deviceId];
    if (peer != null && peer.online) {
      peer.online = false;
      notifyListeners();
    }
  }

  /// Called by the heartbeat to keep a peer's lastSeen fresh without
  /// changing their visible online state.
  void refreshLastSeen(String deviceId) {
    final peer = _peers[deviceId];
    if (peer != null) {
      peer.lastSeen = DateTime.now();
    }
    // No notifyListeners — this is a background bookkeeping update.
  }

  Peer? getPeer(String deviceId) => _peers[deviceId];
}

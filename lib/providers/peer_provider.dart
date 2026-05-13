import 'dart:async';

import 'package:flutter/material.dart';

import '../models/peer.dart';

class PeerProvider extends ChangeNotifier {
  final Map<String, Peer> _peers = {};

  List<Peer> get peers => _peers.values.toList();

  PeerProvider() {
    Timer.periodic(const Duration(seconds: 5), (_) {
      _cleanupOfflinePeers();
    });
  }

  void updatePeer(Peer peer) {
    _peers[peer.deviceId] = peer;

    notifyListeners();
  }

  void _cleanupOfflinePeers() {
    final now = DateTime.now();

    for (final peer in _peers.values) {
      final diff = now.difference(peer.lastSeen).inSeconds;

      peer.online = diff <= 6;
    }

    notifyListeners();
  }
}
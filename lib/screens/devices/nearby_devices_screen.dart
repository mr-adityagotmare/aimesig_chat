import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/udp_chat_service.dart';

import '../../models/peer.dart';

import '../../providers/peer_provider.dart';

import '../../widgets/device_tile.dart';

import '../chat/chat_screen.dart';

class NearbyDevicesScreen extends StatelessWidget {
  final UdpChatService udp;

  final String myName;

  const NearbyDevicesScreen({
    super.key,
    required this.udp,
    required this.myName,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PeerProvider>(
      builder: (context, provider, _) {
        final peers = provider.peers;

        if (peers.isEmpty) {
          return const Center(
            child: Text(
              "Searching nearby devices...",
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: peers.length,
          itemBuilder: (context, index) {
            final Peer peer = peers[index];

            return DeviceTile(
              peer: peer,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      peer: peer,
                      udp: udp,
                      myName: myName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
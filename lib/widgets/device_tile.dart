import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/peer.dart';

import '../providers/chat_provider.dart';

import 'online_indicator.dart';

class DeviceTile extends StatelessWidget {
  final Peer peer;

  final VoidCallback onTap;

  const DeviceTile({
    super.key,
    required this.peer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF202C33),

      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      child: ListTile(
        onTap: onTap,

        leading: CircleAvatar(
          backgroundColor:
              const Color(0xFF075E54),

          child: Text(
            peer.name.isNotEmpty
                ? peer.name[0].toUpperCase()
                : "?",
          ),
        ),

        title: Text(
          peer.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Text(
          peer.ip,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),

        trailing: Consumer<ChatProvider>(
          builder: (
            context,
            chatProvider,
            _,
          ) {
            final unread =
                chatProvider.unreadCount(
              peer.name,
            );

            return Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                OnlineIndicator(
                  online: peer.online,
                ),

                if (unread > 0)
                  Container(
                    margin:
                        const EdgeInsets.only(
                      top: 6,
                    ),

                    padding:
                        const EdgeInsets.all(
                      6,
                    ),

                    decoration:
                        const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),

                    child: Text(
                      unread.toString(),
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
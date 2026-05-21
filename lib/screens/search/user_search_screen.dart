import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart' as ap;
import '../../providers/peer_provider.dart';
import '../../models/peer.dart';
import '../../theme/app_theme.dart';

/// Screen to search for users by @username and open a direct message.
class UserSearchScreen extends StatefulWidget {
  /// Called when a user is selected and we want to open a chat with them.
  final Function(Peer peer) onStartChat;

  const UserSearchScreen({super.key, required this.onStartChat});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final auth = context.read<ap.AuthProvider>();
    final peerProvider = context.read<PeerProvider>();
    final results = await auth.searchUsersByUsername(q);

    // FIX: Firestore's `online` field is only updated on login/logout, so it
    // goes stale quickly. Cross-reference with the live socket-based
    // PeerProvider to show accurate real-time online status.
    final livePeers = peerProvider.peers;
    final enriched = results.map((u) {
      final uid = u['uid'] as String?;
      final livePeer = livePeers
          .where((p) => p.deviceId == uid)
          .firstOrNull;
      if (livePeer != null) {
        return {...u, 'online': livePeer.online};
      }
      return u;
    }).toList();

    if (mounted) setState(() { _results = enriched; _searching = false; });
  }

  void _startChat(Map<String, dynamic> userDoc) {
    final peer = Peer(
      deviceId: userDoc['uid'] as String,
      name: userDoc['displayName'] as String? ?? userDoc['username'] as String,
      ip: userDoc['uid'] as String, // in internet mode, uid == ip key
      port: 0,
      online: userDoc['online'] as bool? ?? false,
      lastSeen: DateTime.now(),
    );

    // Register peer in PeerProvider so chat resolves correctly
    context.read<PeerProvider>().updatePeer(peer);

    Navigator.pop(context);
    widget.onStartChat(peer);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = true;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary(isDark)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Find People',
            style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary(isDark)),
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Search by @username…',
              hintStyle: TextStyle(color: AppColors.textMuted(isDark)),
              prefixIcon: Icon(Icons.search_rounded,
                  color: AppColors.textMuted(isDark)),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentGreen)),
                    )
                  : _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: AppColors.textMuted(isDark), size: 18),
                          onPressed: () {
                            _ctrl.clear();
                            _search('');
                          },
                        )
                      : null,
              filled: true,
              fillColor: AppColors.darkCard,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: AppColors.darkBorder, width: 1)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: AppColors.accentGreen, width: 1.5)),
            ),
          ),
        ),

        // Results
        Expanded(
          child: _results.isEmpty && !_searching
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_search_rounded,
                          size: 60,
                          color: AppColors.textMuted(isDark).withOpacity(0.4)),
                      const SizedBox(height: 14),
                      Text(
                        _ctrl.text.isEmpty
                            ? 'Type a username to search'
                            : 'No users found for "@${_ctrl.text.trim()}"',
                        style: TextStyle(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => Divider(
                      color: AppColors.darkBorder.withOpacity(0.4),
                      height: 1),
                  itemBuilder: (context, i) {
                    final u = _results[i];
                    final online = u['online'] as bool? ?? false;
                    final displayName =
                        u['displayName'] as String? ?? u['username'] as String;
                    final username = u['username'] as String;

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppColors.accentGreen.withOpacity(0.2),
                            backgroundImage: (u['photoUrl'] as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? NetworkImage(u['photoUrl']!)
                                : null,
                            child: (u['photoUrl'] as String?)?.isEmpty ?? true
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppColors.accentGreen,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18),
                                  )
                                : null,
                          ),
                          if (online)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.darkBg, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(displayName,
                          style: TextStyle(
                              color: AppColors.textPrimary(isDark),
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      subtitle: Text('@$username',
                          style: TextStyle(
                              color: AppColors.textSecondary(isDark),
                              fontSize: 13)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.accentGreen.withOpacity(0.4),
                              width: 1),
                        ),
                        child: const Text('Message',
                            style: TextStyle(
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      onTap: () => _startChat(u),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
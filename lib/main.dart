import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/lan_discovery_service.dart';
import 'core/network/udp_chat_service.dart';

import 'models/peer.dart';
import 'models/chat_message.dart';

import 'providers/peer_provider.dart';
import 'providers/chat_provider.dart';

import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'providers/theme_provider.dart';

void main() {
  runApp(const AimesigChatApp());
}

class AimesigChatApp extends StatelessWidget {
  const AimesigChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PeerProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => ChatProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],

      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,

            title: 'Aimesig Chat',

            theme: themeProvider.theme,

            home: const MainPage(),
          );
        },
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  LanDiscoveryService? discovery;

  late UdpChatService udp;

  String username = "Unknown";

  bool ready = false;

  @override
  void initState() {
    super.initState();

    init();
  }

  Future<void> init() async {

    await context
    .read<ThemeProvider>()
    .loadTheme();
    final prefs = await SharedPreferences.getInstance();

    username = prefs.getString("username") ??
        "Device_${DateTime.now().millisecondsSinceEpoch % 1000}";

    final chatProvider =
        context.read<ChatProvider>();

    await chatProvider.loadMessages();

    await startServices();

    setState(() {
      ready = true;
    });
  }

  Future<void> startServices() async {
    final peerProvider =
        context.read<PeerProvider>();

    final chatProvider =
        context.read<ChatProvider>();

    discovery?.stop();

    udp = UdpChatService();

    await udp.start();

udp.onMessage = (ip, data) async {
  final type = data["type"];

  if (type == "MESSAGE") {
    final sender = data["sender"];

    final message = data["message"];

    final msgId = data["id"];

    await chatProvider.addMessage(
      sender,
      ChatMessage(
        id: msgId,

        sender: sender,
        receiver: username,

        message: message,

        timestamp: data["timestamp"],

        mine: false,

        delivered: true,
        read: false,
      ),
    );

    // DELIVERED ACK
    udp.sendMessage(
      ip: ip,
      data: {
        "type": "DELIVERED",
        "id": msgId,
      },
    );

    // READ ACK IMMEDIATELY
    // if currently viewing chat
    if (chatProvider.currentOpenChat ==
        sender) {
      await chatProvider.markRead(msgId);

      udp.sendMessage(
        ip: ip,
        data: {
          "type": "READ",
          "id": msgId,
        },
      );
    }
  }

  else if (type == "DELIVERED") {
    await chatProvider.markDelivered(
      data["id"],
    );
  }

  else if (type == "READ") {
    await chatProvider.markRead(
      data["id"],
    );
  }
};

    discovery = LanDiscoveryService(
      deviceId: username,
      username: username,
    );

    discovery!.onPeerFound = (peerData) {
      final peer = Peer(
        deviceId: peerData["deviceId"],
        name: peerData["name"],
        ip: peerData["ip"],
        port: peerData["port"],
        online: true,
        lastSeen: DateTime.now(),
      );

      peerProvider.updatePeer(peer);
    };

    await discovery!.start();
  }

  Future<void> changeName(String newName) async {
    setState(() {
      username = newName;
    });

    await startServices();
  }

  @override
  void dispose() {
    discovery?.stop();

    udp.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF111B21),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return HomeScreen(
      udp: udp,
      username: username,
      onProfileTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              onNameChanged: changeName,
            ),
          ),
        );
      },
    );
  }
}
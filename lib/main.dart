import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/lan_discovery_service.dart';
import 'core/network/udp_chat_service.dart';
import 'models/peer.dart';
import 'models/chat_message.dart';
import 'providers/peer_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'utils/device_id.dart';
import 'core/services/message_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const AimesigChatApp());
}

class AimesigChatApp extends StatelessWidget {
  const AimesigChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PeerProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Aimesig',
            theme: themeProvider.theme,
            home: const AppRoot(),
          );
        },
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  LanDiscoveryService? discovery;
  late UdpChatService udp;
  String username = '';
  String deviceId = '';   // ← stable, never changes with network/restart
  MessageQueueService? _messageQueue;
  bool ready = false;
  bool isFirstTime = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await context.read<ThemeProvider>().loadTheme();
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? '';

    if (username.isEmpty) {
      setState(() {
        isFirstTime = true;
        ready = true;
      });
      return;
    }

    // Load (or lazily create) the stable device ID.
    deviceId = await DeviceId.generate(username);

    await context.read<ChatProvider>().loadMessages();
    await startServices();
    setState(() => ready = true);
  }

  Future<void> startServices() async {
    final peerProvider = context.read<PeerProvider>();
    final chatProvider = context.read<ChatProvider>();

    discovery?.stop();
    udp = UdpChatService();
    await udp.start();

    udp.onMessage = (ip, data) async {
      final type = data['type'];

      if (type == 'MESSAGE') {
        final sender = data['sender'];
        final message = data['message'];
        final msgId = data['id'];

        await chatProvider.addMessage(
          sender,
          ChatMessage(
            id: msgId,
            sender: sender,
            receiver: username,
            message: message,
            timestamp: data['timestamp'],
            mine: false,
            delivered: true,
            read: false,
          ),
        );

        udp.sendMessage(ip: ip, data: {'type': 'DELIVERED', 'id': msgId});

        if (chatProvider.currentOpenChat == sender) {
          await chatProvider.markRead(msgId);
          udp.sendMessage(ip: ip, data: {'type': 'READ', 'id': msgId});
        }
      } else if (type == 'DELIVERED') {
        await chatProvider.markDelivered(data['id']);
      } else if (type == 'READ') {
        await chatProvider.markRead(data['id']);
      }
    };

    discovery = LanDiscoveryService(deviceId: deviceId, username: username);
    discovery!.onPeerFound = (peerData) {
      peerProvider.updatePeer(Peer(
        deviceId: peerData['deviceId'],
        name: peerData['name'],
        ip: peerData['ip'],
        port: peerData['port'],
        online: true,
        lastSeen: DateTime.now(),
      ));
    };

    await discovery!.start();

    // Start retry loop — resends undelivered messages whenever a peer comes back online.
    _messageQueue?.stop();
    _messageQueue = MessageQueueService(
      chatProvider: chatProvider,
      peerProvider: peerProvider,
      udp: udp,
      myName: username,
    );
    _messageQueue!.start();
  }

  Future<void> onNameSet(String name) async {
    deviceId = await DeviceId.generate(name);
    setState(() {
      username = name;
      isFirstTime = false;
    });
    await context.read<ChatProvider>().loadMessages();
    await startServices();
    setState(() => ready = true);
  }

  Future<void> changeName(String newName) async {
    deviceId = await DeviceId.generate(newName);
    setState(() => username = newName);
    await startServices();
  }

  @override
  void dispose() {
    discovery?.stop();
    _messageQueue?.stop();
    udp.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    if (!ready) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.wifi_rounded,
                  color: AppColors.accentGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Aimesig',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Starting up...',
                style: TextStyle(
                  color: AppColors.textSecondary(true),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accentGreen,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isFirstTime) {
      return OnboardingScreen(onDone: onNameSet);
    }

    return HomeScreen(
      udp: udp,
      username: username,
      onNameChanged: changeName,
    );
  }
}
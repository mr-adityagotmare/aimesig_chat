import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_helper.dart';
import 'core/network/lan_discovery_service.dart';
import 'core/network/udp_chat_service.dart';
import 'core/services/message_queue_service.dart';
import 'models/peer.dart';
import 'models/chat_message.dart';
import 'providers/peer_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'utils/device_id.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must be called before any DB access on Linux/Windows.
  DatabaseHelper.initFfiIfNeeded();

  // Orientation lock is mobile-only — crashes on Linux/Windows.
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

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
  UdpChatService? udp;
  String username = '';
  String deviceId = '';
  MessageQueueService? _messageQueue;
  bool ready = false;
  bool isFirstTime = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
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

      deviceId = await DeviceId.generate(username);
      await context.read<ChatProvider>().loadMessages();
      await startServices();
      setState(() => ready = true);
    } catch (e, stack) {
      print('INIT ERROR => $e\n$stack');
      setState(() {
        _initError = e.toString();
        ready = true;
      });
    }
  }

Future<void> startServices() async {
  final peerProvider = context.read<PeerProvider>();
  final chatProvider = context.read<ChatProvider>();

  discovery?.stop();
  final service = UdpChatService();  // local variable — non-null
  udp = service;                     // assign field too
  await service.start();             // use local, not field

  service.onMessage = (ip, data) async {
    final type = data['type'];

    if (type == 'MESSAGE') {
      final sender  = data['sender'];
      final message = data['message'];
      final msgId   = data['id'];

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

      service.sendMessage(ip: ip, data: {'type': 'DELIVERED', 'id': msgId});

      if (chatProvider.currentOpenChat == sender) {
        await chatProvider.markRead(msgId);
        service.sendMessage(ip: ip, data: {'type': 'READ', 'id': msgId});
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

  _messageQueue?.stop();
  _messageQueue = MessageQueueService(
    chatProvider: chatProvider,
    peerProvider: peerProvider,
    udp: service,   // pass local, not field
    myName: username,
  );
  _messageQueue!.start();
}

  Future<void> onNameSet(String name) async {
    try {
      deviceId = await DeviceId.generate(name);
      // ❌ Don't flip isFirstTime here — build() can run while startServices()
      // is still awaiting, hitting the udp! null check.
      await context.read<ChatProvider>().loadMessages();
      await startServices();
      // ✅ Only now is udp guaranteed to be non-null
      setState(() {
        username = name;
        isFirstTime = false;
        ready = true;
      });
    } catch (e) {
      print('onNameSet ERROR => $e');
    }
  }

  Future<void> changeName(String newName) async {
    try {
      deviceId = await DeviceId.generate(newName);
      setState(() => username = newName);
      await startServices();
    } catch (e) {
      print('changeName ERROR => $e');
    }
  }

  @override
  void dispose() {
    discovery?.stop();
    _messageQueue?.stop();
    udp?.stop();   // was: udp.stop()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(
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

    if (_initError != null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Failed to start',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(_initError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    setState(() { ready = false; _initError = null; });
                    init();
                  },
                  child: const Text('Retry',
                      style: TextStyle(color: AppColors.accentGreen)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isFirstTime) {
      return OnboardingScreen(onDone: onNameSet);
    }

    return HomeScreen(
      udp: udp!,       // was: udp
      username: username,
      onNameChanged: changeName,
    );
  }
}
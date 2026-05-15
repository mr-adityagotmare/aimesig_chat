import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_helper.dart';
import 'core/network/lan_discovery_service.dart';
import 'core/network/udp_chat_service.dart';
import 'core/network/file_transfer_service.dart';
import 'core/network/voice_call_service.dart'; // NEW
import 'core/services/message_queue_service.dart';
import 'models/chat_message.dart';
import 'models/group.dart';
import 'models/peer.dart';
import 'providers/peer_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/group_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/call_provider.dart'; // NEW
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/call/incoming_call_overlay.dart'; // NEW
import 'theme/app_theme.dart';
import 'utils/device_id.dart';
import 'core/network/video_call_service.dart';
import 'providers/video_call_provider.dart';
import 'screens/call/incoming_video_call_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseHelper.initFfiIfNeeded();

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
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()), 
        ChangeNotifierProvider(create: (_) => VideoCallProvider()),
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
  FileTransferService? fileTransfer;
  VoiceCallService? _voiceCall; 
  VideoCallService? _videoCall;
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
      await context.read<GroupProvider>().loadGroups();
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
    final groupProvider = context.read<GroupProvider>();
    final callProvider = context.read<CallProvider>(); // NEW

    discovery?.stop();
    fileTransfer?.dispose();
    _voiceCall?.dispose(); // NEW

    final service = UdpChatService();
    udp = service;
    await service.start();

    // Wire peerProvider into udp so broadcastToGroup can resolve IPs
    service.peerProvider = peerProvider;

    final ft = FileTransferService(service);
    fileTransfer = ft;

    // ── NEW: Voice call service ──────────────────────────────────────────
    final vc = VoiceCallService(
      udp: service,
      myDeviceId: deviceId,
      myName: username,
    );
    _voiceCall = vc;
    callProvider.init(vc);

    // Show incoming call overlay when a call arrives
    vc.onIncomingCall = (session) {
      if (mounted) {
        showIncomingCallSheet(context);
      }
    };
    // ────────────────────────────────────────────────────────────────────

        // ── Video call service ──────────────────────────────────────────────────
    _videoCall = VideoCallService(
      udp: udp!,
      myDeviceId: deviceId,
      myName: username,
    );

    final videoCallProvider = context.read<VideoCallProvider>();
    videoCallProvider.init(_videoCall!);

    _videoCall!.onIncomingCall = (session) {
      if (mounted) {
        showIncomingVideoCallSheet(context);
      }
    };

    // Wire up incoming file progress → ChatProvider
    ft.onReceiveProgress = (id, fileName, received, total, state, {savedPath}) {
      final progress = total > 0 ? received / total : 0.0;
      switch (state) {
        case RecvState.receiving:
          chatProvider.updateTransferProgress(id, progress);
          break;
        case RecvState.complete:
          if (savedPath != null) {
            chatProvider.updateFilePath(id, savedPath);
          }
          break;
        case RecvState.failed:
          chatProvider.markTransferFailed(id);
          break;
        default:
          break;
      }
    };

    // Ask user before accepting file (auto-accept for now)
    ft.onIncomingOffer = (id, peerIp, fileName, fileSize) async {
      final peer = peerProvider.peers
          .where((p) => p.ip == peerIp)
          .firstOrNull;
      final senderName = peer?.name ?? peerIp;

      final isImg = _isImageName(fileName);
      await chatProvider.addMessage(
        senderName,
        ChatMessage(
          id: id,
          sender: senderName,
          receiver: username,
          message: fileName,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          mine: false,
          type: isImg ? MessageType.image : MessageType.file,
          fileName: fileName,
          fileSize: fileSize,
          transferProgress: 0.0,
        ),
      );
      return true;
    };

    service.onMessage = (ip, data) async {
      final type = data['type'] as String?;

      // Route file-transfer packets to FileTransferService
      if (type != null && type.startsWith('FILE_')) {
        ft.handleMessage(ip, data);
        return;
      }

      // NEW: Route call-signalling packets to VoiceCallService
      if (type != null && type.startsWith('CALL_')) {
        await vc.handleSignal(ip, data);
        return;
      }
        // --- NEW: video call routing ---
      if (type != null && type.startsWith('VIDEO_CALL_')) {
        await _videoCall?.handleSignal(ip, data);
        return;
      }

      // ── Group invite ───────────────────────────────────────────────────────
      if (type == 'GROUP_INVITE') {
        final groupId = data['groupId'] as String;
        final groupName = data['groupName'] as String;
        final creatorDeviceId = data['creatorDeviceId'] as String;
        final memberDeviceIds = (data['memberDeviceIds'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();
        final memberNames = (data['memberNames'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();

        if (!memberDeviceIds.contains(deviceId)) return;
        if (groupProvider.getGroup(groupId) != null) return;

        final group = Group(
          id: groupId,
          name: groupName,
          creatorDeviceId: creatorDeviceId,
          memberDeviceIds: memberDeviceIds,
          memberNames: memberNames,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
              data['timestamp'] as int),
        );
        await groupProvider.addGroup(group);
        print('GROUP INVITE RECEIVED => $groupName');
        return;
      }

      // ── Group message ──────────────────────────────────────────────────────
      if (type == 'GROUP_MESSAGE') {
        final groupId = data['groupId'] as String;
        final sender = data['sender'] as String;
        final msgId = data['id'] as String;
        final message = data['message'] as String;
        final ts = data['timestamp'] as int;

        final group = groupProvider.getGroup(groupId);
        if (group == null) return;

        await groupProvider.addGroupMessage(
          groupId,
          ChatMessage(
            id: msgId,
            sender: sender,
            receiver: groupId,
            message: message,
            timestamp: ts,
            mine: false,
            delivered: true,
            read: groupProvider.currentOpenGroup == groupId,
          ),
        );
        return;
      }

      // ── 1-to-1 message ─────────────────────────────────────────────────────
      if (type == 'MESSAGE') {
        final sender  = data['sender'] as String;
        final message = data['message'] as String;
        final msgId   = data['id'] as String;

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
      udp: service,
      myName: username,
    );
    _messageQueue!.start();
  }

  bool _isImageName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  Future<void> onNameSet(String name) async {
    try {
      deviceId = await DeviceId.generate(name);
      username = name;
      await context.read<ChatProvider>().loadMessages();
      await context.read<GroupProvider>().loadGroups();
      await startServices();
      setState(() {
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
      username = newName;
      await startServices();
      setState(() {});
    } catch (e) {
      print('changeName ERROR => $e');
    }
  }

  @override
  void dispose() {
    discovery?.stop();
    _messageQueue?.stop();
    udp?.stop();
    fileTransfer?.dispose();
    _voiceCall?.dispose(); // NEW
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
                child: const Icon(Icons.wifi_rounded,
                    color: AppColors.accentGreen, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Aimesig',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text('Starting up...',
                  style: TextStyle(
                      color: AppColors.textSecondary(true), fontSize: 14)),
              const SizedBox(height: 32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.accentGreen),
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
                    setState(() {
                      ready = false;
                      _initError = null;
                    });
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
      udp: udp!,
      fileTransfer: fileTransfer!,
      username: username,
      deviceId: deviceId,
      onNameChanged: changeName,
    );
  }
}
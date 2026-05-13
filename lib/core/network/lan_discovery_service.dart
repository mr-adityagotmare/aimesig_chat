import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LanDiscoveryService {
  RawDatagramSocket? _socket;

  final int discoveryPort = 8888;

  Timer? _broadcastTimer;

  final String deviceId;
  final String username;
  final int tcpPort;

  Function(Map<String, dynamic>)? onPeerFound;

  LanDiscoveryService({
    required this.deviceId,
    required this.username,
    this.tcpPort = 4040,
  });

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!.broadcastEnabled = true;

    print("UDP DISCOVERY STARTED");

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket!.receive();

        if (dg == null) return;

        try {
          final msg = utf8.decode(dg.data);

          print("UDP RECEIVED => $msg");

          final data = jsonDecode(msg);

          if (data["deviceId"] == deviceId) {
            return;
          }

          print("REMOTE DEVICE FOUND => ${data["name"]}");

          onPeerFound?.call({
            "deviceId": data["deviceId"],
            "name": data["name"],
            "ip": dg.address.address,
            "port": data["port"],
            "online": true,
          });
        } catch (e) {
          print("DISCOVERY ERROR => $e");
        }
      }
    });

    _startBroadcasting();
  }

  void _startBroadcasting() {
    _broadcastTimer?.cancel();

    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _sendBroadcast();
      },
    );

    _sendBroadcast();
  }

  void _sendBroadcast() {
    if (_socket == null) return;

    final packet = {
      "type": "DISCOVERY",
      "deviceId": deviceId,
      "name": username,
      "port": tcpPort,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    };

    final encoded = utf8.encode(jsonEncode(packet));

    try {
      _socket!.send(
        encoded,
        InternetAddress("255.255.255.255"),
        discoveryPort,
      );

      print("BROADCAST SENT");
    } catch (e) {
      print("BROADCAST ERROR => $e");
    }
  }

  void stop() {
    _broadcastTimer?.cancel();
    _socket?.close();
  }
}
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

  // Cached broadcast addresses refreshed each cycle so we adapt when
  // the device switches networks.
  List<String> _broadcastAddresses = [];

  LanDiscoveryService({
    required this.deviceId,
    required this.username,
    this.tcpPort = 4040,
  });

  Future<void> start() async {
    // reusePort is NOT supported on Windows and causes a crash — omitted.
    // reuseAddress works on Android, iOS, Linux, macOS, and Windows.
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );

    _socket!.broadcastEnabled = true;

    print('UDP DISCOVERY STARTED on port $discoveryPort');

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket!.receive();
        if (dg == null) return;

        try {
          final msg = utf8.decode(dg.data);
          print('UDP RECEIVED => $msg');

          final data = jsonDecode(msg) as Map<String, dynamic>;

          if (data['deviceId'] == deviceId) return; // own broadcast

          print('REMOTE DEVICE FOUND => ${data["name"]} @ ${dg.address.address}');

          onPeerFound?.call({
            'deviceId': data['deviceId'],
            'name': data['name'],
            'ip': dg.address.address,
            'port': data['port'],
            'online': true,
          });
        } catch (e) {
          print('DISCOVERY ERROR => $e');
        }
      }
    });

    await _refreshBroadcastAddresses();
    _startBroadcasting();
  }

  void _startBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _refreshBroadcastAddresses();
      _sendBroadcast();
    });
    _sendBroadcast();
  }

  /// Enumerates active IPv4 interfaces and derives /24 broadcast addresses.
  /// Falls back to 255.255.255.255 which works on Linux/macOS/Android/iOS
  /// but is often blocked on Windows — hence we prefer interface-specific ones.
  Future<void> _refreshBroadcastAddresses() async {
    final addresses = <String>{};

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.address.startsWith('169.254')) continue; // skip link-local
          final bc = _subnetBroadcast(addr.rawAddress);
          if (bc != null) addresses.add(bc);
        }
      }
    } catch (e) {
      print('INTERFACE LIST ERROR => $e');
    }

    addresses.add('255.255.255.255'); // universal fallback
    _broadcastAddresses = addresses.toList();
    print('BROADCAST TARGETS => $_broadcastAddresses');
  }

  void _sendBroadcast() {
    if (_socket == null) return;

    final encoded = utf8.encode(jsonEncode({
      'type': 'DISCOVERY',
      'deviceId': deviceId,
      'name': username,
      'port': tcpPort,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));

    for (final addr in _broadcastAddresses) {
      try {
        _socket!.send(encoded, InternetAddress(addr), discoveryPort);
        print('BROADCAST SENT => $addr');
      } catch (e) {
        print('BROADCAST ERROR ($addr) => $e');
      }
    }
  }

  /// Derives /24 subnet broadcast from raw IPv4 bytes.
  /// e.g. [192, 168, 1, 42] → "192.168.1.255"
  String? _subnetBroadcast(List<int> raw) {
    if (raw.length != 4) return null;
    return '${raw[0]}.${raw[1]}.${raw[2]}.255';
  }

  void stop() {
    _broadcastTimer?.cancel();
    _socket?.close();
    _socket = null;
  }
}
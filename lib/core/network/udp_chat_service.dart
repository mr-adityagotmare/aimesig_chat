import 'dart:convert';
import 'dart:io';

class UdpChatService {
  RawDatagramSocket? _socket;

  final int messagePort = 4040;

  Function(String ip, Map<String, dynamic> data)? onMessage;

  Future<void> start() async {
    // reusePort omitted — not supported on Windows.
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      messagePort,
      reuseAddress: true,
    );

    _socket!.broadcastEnabled = true;

    print('UDP CHAT STARTED on port $messagePort');

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket!.receive();
        if (dg == null) return;

        try {
          final msg = utf8.decode(dg.data);
          final data = jsonDecode(msg) as Map<String, dynamic>;
          print('UDP MESSAGE => $msg');
          onMessage?.call(dg.address.address, data);
        } catch (e) {
          print('UDP MESSAGE ERROR => $e');
        }
      }
    });
  }

  void sendMessage({
    required String ip,
    required Map<String, dynamic> data,
  }) {
    if (_socket == null) return;
    if (ip.isEmpty) return; // peer is offline — message queue will retry

    try {
      final encoded = utf8.encode(jsonEncode(data));
      _socket!.send(encoded, InternetAddress(ip), messagePort);
      print('UDP SENT => $data');
    } catch (e) {
      print('UDP SEND ERROR => $e');
    }
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}
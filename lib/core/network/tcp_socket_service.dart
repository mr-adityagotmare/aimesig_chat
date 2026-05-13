import 'dart:convert';
import 'dart:io';

class TcpSocketService {
  ServerSocket? _server;

  Function(String ip, String message)? onMessage;

  Future<void> startServer() async {
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      4040,
      shared: true,
    );

    print("TCP SERVER STARTED");

    _server!.listen((client) {
      print("CLIENT CONNECTED => ${client.remoteAddress.address}");

      client.listen((data) {
        final msg = utf8.decode(data);

        print("MESSAGE RECEIVED => $msg");

        onMessage?.call(
          client.remoteAddress.address,
          msg,
        );
      });
    });
  }

  Future<void> sendMessage({
    required String ip,
    required String message,
  }) async {
    try {
      final socket = await Socket.connect(
        ip,
        4040,
        timeout: const Duration(seconds: 5),
      );

      socket.write(message);

      await socket.flush();

      await socket.close();

      print("MESSAGE SENT");
    } catch (e) {
      print("SEND ERROR => $e");
    }
  }

  void stop() async {
    await _server?.close();
  }
}
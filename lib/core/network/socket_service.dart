```dart id="5jlwm5"
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;

  void connect() {
    socket = IO.io(
      "https://aimapp-server.onrender.com",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print("Connected to server");
    });

    socket.onDisconnect((_) {
      print("Disconnected");
    });

    socket.on("receive_message", (data) {
      print("Message received: $data");
    });
  }

  void sendMessage(String message) {
    socket.emit("send_message", {
      "message": message,
    });
  }
}
```

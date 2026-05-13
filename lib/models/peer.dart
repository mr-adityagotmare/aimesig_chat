class Peer {
  final String deviceId;
  final String name;
  final String ip;
  final int port;

  bool online;
  DateTime lastSeen;

  Peer({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.port,
    this.online = true,
    required this.lastSeen,
  });
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'udp_chat_service.dart';

/// Size of each data chunk in bytes (8 KB fits easily in a UDP datagram).
const int _kChunkSize = 8192;

/// How long to wait for an ACK before retrying a chunk.
const Duration _kAckTimeout = Duration(seconds: 2);

/// Maximum times a single chunk is retried before giving up.
const int _kMaxRetries = 5;

// ─── Packet type constants ────────────────────────────────────────────────────
const String kFileOffer    = 'FILE_OFFER';
const String kFileAccept   = 'FILE_ACCEPT';
const String kFileDecline  = 'FILE_DECLINE';
const String kFileChunk    = 'FILE_CHUNK';
const String kFileAck      = 'FILE_ACK';
const String kFileNack     = 'FILE_NACK';
const String kFileDone     = 'FILE_DONE';
const String kFileComplete = 'FILE_COMPLETE';
const String kFileError    = 'FILE_ERROR';

// ─── Transfer state enums ─────────────────────────────────────────────────────
enum SendState { offering, transferring, done, failed }
enum RecvState { offered, receiving, assembling, complete, failed }

// ─── Progress callbacks ───────────────────────────────────────────────────────
typedef OnSendProgress = void Function(
    String transferId, int sent, int total, SendState state);
typedef OnReceiveProgress = void Function(
    String transferId, String fileName, int received, int total, RecvState state,
    {String? savedPath});

// ─── Outgoing transfer ────────────────────────────────────────────────────────
class _OutgoingTransfer {
  final String id;
  final String peerIp;
  final String fileName;
  final Uint8List bytes;
  final int totalChunks;

  SendState state = SendState.offering;
  int nextChunk = 0;
  final Map<int, int> retries = {}; // chunkIndex → retry count
  final Set<int> acked = {};
  Timer? _ackTimer;
  final OnSendProgress? onProgress;

  _OutgoingTransfer({
    required this.id,
    required this.peerIp,
    required this.fileName,
    required this.bytes,
    required this.onProgress,
  }) : totalChunks = (bytes.length / _kChunkSize).ceil();

  Uint8List chunkData(int index) {
    final start = index * _kChunkSize;
    final end = min(start + _kChunkSize, bytes.length);
    return bytes.sublist(start, end);
  }

  void cancelTimer() => _ackTimer?.cancel();

  void dispose() {
    _ackTimer?.cancel();
  }
}

// ─── Incoming transfer ────────────────────────────────────────────────────────
class _IncomingTransfer {
  final String id;
  final String peerIp;
  final String fileName;
  final int fileSize;
  final int totalChunks;

  RecvState state = RecvState.offered;
  final Map<int, Uint8List> chunks = {};
  final OnReceiveProgress? onProgress;

  _IncomingTransfer({
    required this.id,
    required this.peerIp,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.onProgress,
  });

  int get receivedCount => chunks.length;

  List<int> missingChunks() {
    final missing = <int>[];
    for (int i = 0; i < totalChunks; i++) {
      if (!chunks.containsKey(i)) missing.add(i);
    }
    return missing;
  }

  bool get isComplete => chunks.length == totalChunks;
}

// ─── FileTransferService ──────────────────────────────────────────────────────
class FileTransferService {
  final UdpChatService _udp;

  final Map<String, _OutgoingTransfer> _sending = {};
  final Map<String, _IncomingTransfer> _receiving = {};

  /// Called when an incoming transfer offer arrives.
  /// Return true from your handler to accept, false to decline.
  Future<bool> Function(String transferId, String peerIp, String fileName,
      int fileSize)? onIncomingOffer;

  FileTransferService(this._udp);

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Send a file to [peerIp]. Returns the transfer ID.
  Future<String> sendFile({
    required String peerIp,
    required String filePath,
    OnSendProgress? onProgress,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final fileName = filePath.split(Platform.pathSeparator).last;
    final id = _generateId();

    final transfer = _OutgoingTransfer(
      id: id,
      peerIp: peerIp,
      fileName: fileName,
      bytes: bytes,
      onProgress: onProgress,
    );

    _sending[id] = transfer;

    // Handshake step 1: offer the file
    _udp.sendMessage(ip: peerIp, data: {
      'type': kFileOffer,
      'id': id,
      'fileName': fileName,
      'fileSize': bytes.length,
      'totalChunks': transfer.totalChunks,
    });

    transfer.onProgress?.call(id, 0, transfer.totalChunks, SendState.offering);

    // Wait for accept / decline (handled in handleMessage)
    return id;
  }

  /// Cancel an outgoing transfer.
  void cancelSend(String transferId) {
    final t = _sending.remove(transferId);
    t?.dispose();
  }

  /// Handle an incoming UDP message. Call this from UdpChatService.onMessage.
  void handleMessage(String peerIp, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case kFileOffer:
        _handleOffer(peerIp, data);
        break;
      case kFileAccept:
        _handleAccept(peerIp, data);
        break;
      case kFileDecline:
        _handleDecline(data);
        break;
      case kFileChunk:
        _handleChunk(peerIp, data);
        break;
      case kFileAck:
        _handleAck(data);
        break;
      case kFileNack:
        _handleNack(data);
        break;
      case kFileDone:
        _handleDone(peerIp, data);
        break;
      case kFileComplete:
        _handleComplete(data);
        break;
      case kFileError:
        _handleError(data);
        break;
    }
  }

  // ── Sender side ─────────────────────────────────────────────────────────────

  void _handleAccept(String peerIp, Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final t = id != null ? _sending[id] : null;
    if (t == null) return;

    t.state = SendState.transferring;
    _sendNextChunk(t);
  }

  void _handleDecline(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final t = id != null ? _sending.remove(id) : null;
    t?.dispose();
    t?.onProgress?.call(id!, 0, t.totalChunks, SendState.failed);
  }

  void _handleAck(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final chunkIndex = data['chunk'] as int?;
    if (id == null || chunkIndex == null) return;

    final t = _sending[id];
    if (t == null) return;

    t.acked.add(chunkIndex);
    t.cancelTimer();
    t.retries.remove(chunkIndex);

    t.onProgress?.call(id, t.acked.length, t.totalChunks, SendState.transferring);

    // Send next chunk in sequence
    _sendNextChunk(t);
  }

  void _handleNack(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final missing = (data['missing'] as List?)?.cast<int>();
    if (id == null || missing == null) return;

    final t = _sending[id];
    if (t == null) return;

    // Resend all requested missing chunks
    for (final chunkIndex in missing) {
      _sendChunk(t, chunkIndex);
    }
  }

  void _handleComplete(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final t = id != null ? _sending.remove(id) : null;
    if (t == null) return;

    t.dispose();
    t.onProgress?.call(id!, t.totalChunks, t.totalChunks, SendState.done);
  }

  void _sendNextChunk(_OutgoingTransfer t) {
    if (t.state != SendState.transferring) return;

    // Find next unacked chunk
    while (t.nextChunk < t.totalChunks && t.acked.contains(t.nextChunk)) {
      t.nextChunk++;
    }

    if (t.nextChunk >= t.totalChunks) {
      // All chunks sent — send DONE signal
      _udp.sendMessage(ip: t.peerIp, data: {
        'type': kFileDone,
        'id': t.id,
        'totalChunks': t.totalChunks,
      });
      return;
    }

    _sendChunk(t, t.nextChunk);
    t.nextChunk++;
  }

  void _sendChunk(_OutgoingTransfer t, int chunkIndex) {
    final retryCount = t.retries[chunkIndex] ?? 0;
    if (retryCount >= _kMaxRetries) {
      // Give up on this transfer
      _sending.remove(t.id);
      t.dispose();
      t.onProgress?.call(t.id, t.acked.length, t.totalChunks, SendState.failed);
      _udp.sendMessage(ip: t.peerIp, data: {'type': kFileError, 'id': t.id});
      return;
    }

    t.retries[chunkIndex] = retryCount + 1;

    final chunkBytes = t.chunkData(chunkIndex);
    _udp.sendMessage(ip: t.peerIp, data: {
      'type': kFileChunk,
      'id': t.id,
      'chunk': chunkIndex,
      'total': t.totalChunks,
      'data': base64Encode(chunkBytes),
    });

    // Start retry timer — if no ACK arrives, resend
    t.cancelTimer();
    t._ackTimer = Timer(_kAckTimeout, () {
      if (_sending.containsKey(t.id) && !t.acked.contains(chunkIndex)) {
        _sendChunk(t, chunkIndex);
      }
    });
  }

  // ── Receiver side ───────────────────────────────────────────────────────────

  void _handleOffer(String peerIp, Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    final fileName = data['fileName'] as String?;
    final fileSize = data['fileSize'] as int?;
    final totalChunks = data['totalChunks'] as int?;

    if (id == null || fileName == null || fileSize == null || totalChunks == null) return;

    final accept = await (onIncomingOffer?.call(id, peerIp, fileName, fileSize) ??
        Future.value(true));

    if (!accept) {
      _udp.sendMessage(ip: peerIp, data: {'type': kFileDecline, 'id': id});
      return;
    }

    _receiving[id] = _IncomingTransfer(
      id: id,
      peerIp: peerIp,
      fileName: fileName,
      fileSize: fileSize,
      totalChunks: totalChunks,
      onProgress: null, // set via onReceiveProgress callback below
    );

    _udp.sendMessage(ip: peerIp, data: {'type': kFileAccept, 'id': id});
  }

  void _handleChunk(String peerIp, Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final chunkIndex = data['chunk'] as int?;
    final encoded = data['data'] as String?;
    if (id == null || chunkIndex == null || encoded == null) return;

    final t = _receiving[id];
    if (t == null) return;

    if (!t.chunks.containsKey(chunkIndex)) {
      t.chunks[chunkIndex] = base64Decode(encoded);
      onReceiveProgress?.call(
        id, t.fileName, t.receivedCount, t.totalChunks, RecvState.receiving,
      );
    }

    // ACK the chunk
    _udp.sendMessage(ip: peerIp, data: {
      'type': kFileAck,
      'id': id,
      'chunk': chunkIndex,
    });
  }

  void _handleDone(String peerIp, Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null) return;

    final t = _receiving[id];
    if (t == null) return;

    final missing = t.missingChunks();
    if (missing.isNotEmpty) {
      // Request retransmission of missing chunks
      _udp.sendMessage(ip: peerIp, data: {
        'type': kFileNack,
        'id': id,
        'missing': missing,
      });
      return;
    }

    // All chunks received — assemble the file
    await _assembleFile(t);
  }

  void _handleError(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final t = id != null ? _receiving.remove(id) : null;
    if (t == null) return;

    onReceiveProgress?.call(
      id!, t.fileName, t.receivedCount, t.totalChunks, RecvState.failed,
    );
  }

  Future<void> _assembleFile(_IncomingTransfer t) async {
    t.state = RecvState.assembling;

    try {
      // Build byte array from ordered chunks
      final builder = BytesBuilder();
      for (int i = 0; i < t.totalChunks; i++) {
        final chunk = t.chunks[i];
        if (chunk == null) {
          throw Exception('Missing chunk $i during assembly');
        }
        builder.add(chunk);
      }

      final bytes = builder.toBytes();

      // Save to downloads directory
      final dir = await _downloadsDir();
      final file = await _uniqueFile(dir, t.fileName);
      await file.writeAsBytes(bytes);

      t.state = RecvState.complete;
      _receiving.remove(t.id);

      // Notify sender
      _udp.sendMessage(ip: t.peerIp, data: {
        'type': kFileComplete,
        'id': t.id,
      });

      onReceiveProgress?.call(
        t.id, t.fileName, t.totalChunks, t.totalChunks, RecvState.complete,
        savedPath: file.path,
      );
    } catch (e) {
      t.state = RecvState.failed;
      _receiving.remove(t.id);
      _udp.sendMessage(ip: t.peerIp, data: {'type': kFileError, 'id': t.id});
      onReceiveProgress?.call(
        t.id, t.fileName, t.receivedCount, t.totalChunks, RecvState.failed,
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Callback set by the UI layer to receive progress updates.
  OnReceiveProgress? onReceiveProgress;

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

  Future<Directory> _downloadsDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/AimesigFiles');
      await dir.create(recursive: true);
      return dir;
    } else {
      // Desktop: save next to app data
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/AimesigFiles');
      await dir.create(recursive: true);
      return dir;
    }
  }

  /// Ensures we don't overwrite an existing file.
  Future<File> _uniqueFile(Directory dir, String fileName) async {
    var file = File('${dir.path}/$fileName');
    if (!await file.exists()) return file;

    final dot = fileName.lastIndexOf('.');
    final name = dot >= 0 ? fileName.substring(0, dot) : fileName;
    final ext  = dot >= 0 ? fileName.substring(dot) : '';
    int counter = 1;
    while (await file.exists()) {
      file = File('${dir.path}/${name}_$counter$ext');
      counter++;
    }
    return file;
  }

  void dispose() {
    for (final t in _sending.values) {
      t.dispose();
    }
    _sending.clear();
    _receiving.clear();
  }
}
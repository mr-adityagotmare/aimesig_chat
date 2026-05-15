import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'udp_chat_service.dart';

enum VideoCallState { idle, calling, ringing, connected, ended }

enum VideoCallType { individual, group }

class VideoCallSession {
  final String callId;
  final VideoCallType type;
  final String initiatorDeviceId;
  final String initiatorName;

  // Individual
  final String? peerIp;
  final String? peerName;

  // Group
  final String? groupId;
  final String? groupName;
  final List<String> memberIps;

  VideoCallState state;
  Duration elapsed;

  VideoCallSession({
    required this.callId,
    required this.type,
    required this.initiatorDeviceId,
    required this.initiatorName,
    this.peerIp,
    this.peerName,
    this.groupId,
    this.groupName,
    this.memberIps = const [],
    this.state = VideoCallState.idle,
    this.elapsed = Duration.zero,
  });

  String get displayName =>
      type == VideoCallType.individual ? (peerName ?? '') : (groupName ?? '');
}

/// Manages WebRTC video+audio peer connections over LAN (UDP signalling).
/// Supports both 1-to-1 and group (mesh) video calls.
class VideoCallService {
  final UdpChatService udp;
  final String myDeviceId;
  final String myName;

  VideoCallService({
    required this.udp,
    required this.myDeviceId,
    required this.myName,
  });

  // -- State --

  VideoCallSession? _session;
  VideoCallSession? get activeSession => _session;

  final _stateController = StreamController<VideoCallSession?>.broadcast();
  Stream<VideoCallSession?> get onSessionChanged => _stateController.stream;

  Function(VideoCallSession)? onIncomingCall;

  // -- Renderers --

  final localRenderer = RTCVideoRenderer();

  /// 1-to-1 remote renderer (backward compat).
  final remoteRenderer = RTCVideoRenderer();

  /// Group call: one renderer per peer IP. Exposed so the UI can build a grid.
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  bool _renderersInitialised = false;

  Future<void> initRenderers() async {
    if (_renderersInitialised) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersInitialised = true;
  }

  Future<RTCVideoRenderer> _initRendererForPeer(String ip) async {
    if (remoteRenderers.containsKey(ip)) return remoteRenderers[ip]!;
    final r = RTCVideoRenderer();
    await r.initialize();
    remoteRenderers[ip] = r;
    return r;
  }

  // -- WebRTC internals --

  final Map<String, RTCPeerConnection> _pcs = {};
  MediaStream? _localStream;
  Timer? _durationTimer;

  bool _videoEnabled = true;
  bool _muted = false;

  bool get isVideoEnabled => _videoEnabled;
  bool get isMuted => _muted;

  // -- Start calls --

  Future<void> startIndividualCall({
    required String peerIp,
    required String peerName,
    required String peerDeviceId,
  }) async {
    if (_session != null) return;

    final callId = '${myDeviceId}_${DateTime.now().millisecondsSinceEpoch}';
    _session = VideoCallSession(
      callId: callId,
      type: VideoCallType.individual,
      initiatorDeviceId: myDeviceId,
      initiatorName: myName,
      peerIp: peerIp,
      peerName: peerName,
      state: VideoCallState.calling,
    );
    _notify();

    udp.sendMessage(ip: peerIp, data: {
      'type': 'VIDEO_CALL_INVITE',
      'callId': callId,
      'callType': 'individual',
      'callerDeviceId': myDeviceId,
      'callerName': myName,
    });
  }

  Future<void> startGroupCall({
    required String groupId,
    required String groupName,
    required List<String> memberIps,
  }) async {
    if (_session != null) return;

    final callId = '${myDeviceId}_${DateTime.now().millisecondsSinceEpoch}';
    _session = VideoCallSession(
      callId: callId,
      type: VideoCallType.group,
      initiatorDeviceId: myDeviceId,
      initiatorName: myName,
      groupId: groupId,
      groupName: groupName,
      memberIps: List.unmodifiable(memberIps),
      state: VideoCallState.calling,
    );
    _notify();

    for (final ip in memberIps) {
      udp.sendMessage(ip: ip, data: {
        'type': 'VIDEO_CALL_INVITE',
        'callId': callId,
        'callType': 'group',
        'groupId': groupId,
        'groupName': groupName,
        'callerDeviceId': myDeviceId,
        'callerName': myName,
      });
    }
  }

  // -- Accept / Decline / End --

  Future<void> acceptCall() async {
    final session = _session;
    if (session == null) return;

    session.state = VideoCallState.connected;
    _notify();

    final ips = session.type == VideoCallType.individual
        ? [session.peerIp!]
        : session.memberIps;

    for (final ip in ips) {
      udp.sendMessage(ip: ip, data: {
        'type': 'VIDEO_CALL_ACCEPT',
        'callId': session.callId,
        'accepterDeviceId': myDeviceId,
        'accepterName': myName,
      });
    }

    await _initLocalStream();
    for (final ip in ips) {
      await _createPeerConnection(ip, polite: true, callId: session.callId);
    }

    _startDurationTimer();
  }

  void declineCall() {
    final session = _session;
    if (session == null) return;

    final ips = session.type == VideoCallType.individual
        ? [session.peerIp!]
        : session.memberIps;

    for (final ip in ips) {
      udp.sendMessage(ip: ip, data: {
        'type': 'VIDEO_CALL_DECLINE',
        'callId': session.callId,
        'declinerDeviceId': myDeviceId,
      });
    }

    _teardown();
  }

  void endCall() {
    final session = _session;
    if (session == null) return;

    final ips = session.type == VideoCallType.individual
        ? [session.peerIp!]
        : session.memberIps;

    for (final ip in ips) {
      udp.sendMessage(ip: ip, data: {
        'type': 'VIDEO_CALL_END',
        'callId': session.callId,
        'enderDeviceId': myDeviceId,
      });
    }

    _teardown();
  }

  // -- Toggle controls --

  void toggleMute() {
    _muted = !_muted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_muted);
    _notify();
  }

  void toggleVideo() {
    _videoEnabled = !_videoEnabled;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = _videoEnabled);
    _notify();
  }

  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  // -- Incoming signal handler --

  Future<void> handleSignal(String fromIp, Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'VIDEO_CALL_INVITE':
        await _handleInvite(fromIp, data);
        break;
      case 'VIDEO_CALL_ACCEPT':
        await _handleAccept(fromIp, data);
        break;
      case 'VIDEO_CALL_DECLINE':
      case 'VIDEO_CALL_END':
        _handleDeclineOrEnd(fromIp, data);
        break;
      case 'VIDEO_CALL_OFFER':
        await _handleOffer(fromIp, data);
        break;
      case 'VIDEO_CALL_ANSWER':
        await _handleAnswer(fromIp, data);
        break;
      case 'VIDEO_CALL_ICE':
        await _handleIce(fromIp, data);
        break;
    }
  }

  // -- Private signal handlers --

  Future<void> _handleInvite(String fromIp, Map<String, dynamic> data) async {
    if (_session != null) {
      udp.sendMessage(ip: fromIp, data: {
        'type': 'VIDEO_CALL_DECLINE',
        'callId': data['callId'],
        'declinerDeviceId': myDeviceId,
        'reason': 'busy',
      });
      return;
    }

    final callType =
        data['callType'] == 'group' ? VideoCallType.group : VideoCallType.individual;

    _session = VideoCallSession(
      callId: data['callId'] as String,
      type: callType,
      initiatorDeviceId: data['callerDeviceId'] as String,
      initiatorName: data['callerName'] as String,
      peerIp: callType == VideoCallType.individual ? fromIp : null,
      peerName: callType == VideoCallType.individual
          ? (data['callerName'] as String)
          : null,
      groupId: data['groupId'] as String?,
      groupName: data['groupName'] as String?,
      memberIps: callType == VideoCallType.group ? [fromIp] : [],
      state: VideoCallState.ringing,
    );
    _notify();
    onIncomingCall?.call(_session!);
  }

  Future<void> _handleAccept(String fromIp, Map<String, dynamic> data) async {
    final session = _session;
    if (session == null || session.callId != data['callId']) return;

    session.state = VideoCallState.connected;
    _notify();

    await _initLocalStream();

    if (session.type == VideoCallType.group) {
      // Create a peer connection only for the peer that just accepted.
      await _createPeerConnection(fromIp, polite: false, callId: session.callId);
    } else {
      await _createPeerConnection(session.peerIp!, polite: false, callId: session.callId);
    }

    _startDurationTimer();
  }

  void _handleDeclineOrEnd(String fromIp, Map<String, dynamic> data) {
    final session = _session;
    if (session == null || session.callId != data['callId']) return;

    if (session.type == VideoCallType.group && _pcs.length > 1) {
      // Only remove this peer from the group call.
      _pcs[fromIp]?.close();
      _pcs.remove(fromIp);
      remoteRenderers[fromIp]?.srcObject = null;
      remoteRenderers[fromIp]?.dispose();
      remoteRenderers.remove(fromIp);
      _notify();
    } else {
      _teardown();
    }
  }

  Future<void> _handleOffer(String fromIp, Map<String, dynamic> data) async {
    final session = _session;
    if (session == null) return;

    var pc = _pcs[fromIp];
    if (pc == null) {
      await _initLocalStream();
      pc = await _createPeerConnection(fromIp,
          polite: true, callId: session.callId);
    }

    final sdp = RTCSessionDescription(
        data['sdp'] as String, data['sdpType'] as String);
    await pc.setRemoteDescription(sdp);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    udp.sendMessage(ip: fromIp, data: {
      'type': 'VIDEO_CALL_ANSWER',
      'callId': session.callId,
      'sdp': answer.sdp,
      'sdpType': answer.type,
    });
  }

  Future<void> _handleAnswer(String fromIp, Map<String, dynamic> data) async {
    final pc = _pcs[fromIp];
    if (pc == null) return;
    final sdp = RTCSessionDescription(
        data['sdp'] as String, data['sdpType'] as String);
    await pc.setRemoteDescription(sdp);
  }

  Future<void> _handleIce(String fromIp, Map<String, dynamic> data) async {
    final pc = _pcs[fromIp];
    if (pc == null) return;
    final candidate = RTCIceCandidate(
      data['candidate'] as String,
      data['sdpMid'] as String,
      data['sdpMLineIndex'] as int,
    );
    await pc.addCandidate(candidate);
  }

  // -- WebRTC helpers --

  Future<void> _initLocalStream() async {
    if (_localStream != null) return;
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
    });
    localRenderer.srcObject = _localStream;
  }

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  Future<RTCPeerConnection> _createPeerConnection(
    String peerIp, {
    required bool polite,
    required String callId,
  }) async {
    final pc = await createPeerConnection(_iceServers);
    _pcs[peerIp] = pc;

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      udp.sendMessage(ip: peerIp, data: {
        'type': 'VIDEO_CALL_ICE',
        'callId': callId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onAddStream = (stream) async {
      final session = _session;
      if (session != null && session.type == VideoCallType.group) {
        final r = await _initRendererForPeer(peerIp);
        r.srcObject = stream;
      } else {
        remoteRenderer.srcObject = stream;
      }
      _notify();
    };

    if (!polite) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      udp.sendMessage(ip: peerIp, data: {
        'type': 'VIDEO_CALL_OFFER',
        'callId': callId,
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
    }

    return pc;
  }

  // -- Duration timer --

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _session?.elapsed += const Duration(seconds: 1);
      _notify();
    });
  }

  // -- Teardown --

  Future<void> _teardown() async {
    _durationTimer?.cancel();
    _durationTimer = null;

    for (final pc in _pcs.values) {
      await pc.close();
    }
    _pcs.clear();

    await _localStream?.dispose();
    _localStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    for (final r in remoteRenderers.values) {
      r.srcObject = null;
      await r.dispose();
    }
    remoteRenderers.clear();

    _muted = false;
    _videoEnabled = true;
    _session = null;
    _notify();
  }

  void _notify() => _stateController.add(_session);

  void dispose() {
    _teardown();
    _stateController.close();
    if (_renderersInitialised) {
      localRenderer.dispose();
      remoteRenderer.dispose();
    }
  }
}

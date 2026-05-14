import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'udp_chat_service.dart';

enum CallState { idle, calling, ringing, connected, ended }

enum CallType { individual, group }

class VoiceCallSession {
  final String callId;
  final CallType type;
  final String initiatorDeviceId;
  final String initiatorName;
  // For individual calls
  final String? peerIp;
  final String? peerName;
  // For group calls
  final String? groupId;
  final String? groupName;
  final List<String> memberIps;

  CallState state;
  Duration elapsed;

  VoiceCallSession({
    required this.callId,
    required this.type,
    required this.initiatorDeviceId,
    required this.initiatorName,
    this.peerIp,
    this.peerName,
    this.groupId,
    this.groupName,
    this.memberIps = const [],
    this.state = CallState.idle,
    this.elapsed = Duration.zero,
  });

  String get displayName =>
      type == CallType.individual ? (peerName ?? '') : (groupName ?? '');
}

class VoiceCallService {
  final UdpChatService udp;
  final String myDeviceId;
  final String myName;

  VoiceCallService({
    required this.udp,
    required this.myDeviceId,
    required this.myName,
  });

  // ── State ────────────────────────────────────────────────────────────────

  VoiceCallSession? _session;
  VoiceCallSession? get activeSession => _session;

  final _stateController = StreamController<VoiceCallSession?>.broadcast();
  Stream<VoiceCallSession?> get onSessionChanged => _stateController.stream;

  // Callbacks for incoming call UI
  Function(VoiceCallSession)? onIncomingCall;

  // ── WebRTC per-peer connections (map of peerIp -> objects) ──────────────

  final Map<String, RTCPeerConnection> _pcs = {};
  MediaStream? _localStream;
  Timer? _durationTimer;

  // ── Initiating calls ────────────────────────────────────────────────────

  /// Start a 1-to-1 voice call with [peerIp].
  Future<void> startIndividualCall({
    required String peerIp,
    required String peerName,
    required String peerDeviceId,
  }) async {
    if (_session != null) return;

    final callId = '${myDeviceId}_${DateTime.now().millisecondsSinceEpoch}';
    _session = VoiceCallSession(
      callId: callId,
      type: CallType.individual,
      initiatorDeviceId: myDeviceId,
      initiatorName: myName,
      peerIp: peerIp,
      peerName: peerName,
      state: CallState.calling,
    );
    _notify();

    // Signal the callee
    udp.sendMessage(ip: peerIp, data: {
      'type': 'CALL_INVITE',
      'callId': callId,
      'callType': 'individual',
      'callerDeviceId': myDeviceId,
      'callerName': myName,
    });

    await _initLocalStream();
    // Caller is impolite: creates the offer immediately after adding tracks
    await _createPeerConnection(peerIp, polite: false, callId: callId);
  }

  /// Start a group voice call for [memberIps] (excluding self).
  Future<void> startGroupCall({
    required String groupId,
    required String groupName,
    required List<String> memberIps,
  }) async {
    if (_session != null) return;

    final callId = '${myDeviceId}_${DateTime.now().millisecondsSinceEpoch}';
    _session = VoiceCallSession(
      callId: callId,
      type: CallType.group,
      initiatorDeviceId: myDeviceId,
      initiatorName: myName,
      groupId: groupId,
      groupName: groupName,
      memberIps: List.unmodifiable(memberIps),
      state: CallState.calling,
    );
    _notify();

    // Invite every member
    for (final ip in memberIps) {
      udp.sendMessage(ip: ip, data: {
        'type': 'CALL_INVITE',
        'callId': callId,
        'callType': 'group',
        'groupId': groupId,
        'groupName': groupName,
        'callerDeviceId': myDeviceId,
        'callerName': myName,
      });
    }

    await _initLocalStream();
    for (final ip in memberIps) {
      await _createPeerConnection(ip, polite: false, callId: callId);
    }
  }

  // ── Answering / declining ───────────────────────────────────────────────

  Future<void> acceptCall() async {
    final session = _session;
    if (session == null) return;

    session.state = CallState.connected;
    _notify();

    // Acknowledge caller(s)
    final ips = session.type == CallType.individual
        ? [session.peerIp!]
        : session.memberIps;

    for (final ip in ips) {
      udp.sendMessage(ip: ip, data: {
        'type': 'CALL_ACCEPT',
        'callId': session.callId,
        'accepterDeviceId': myDeviceId,
        'accepterName': myName,
      });
    }

    await _initLocalStream();
    // Callee is polite: waits for CALL_OFFER, does not create offer here
    for (final ip in ips) {
      await _createPeerConnection(ip, polite: true, callId: session.callId);
    }

    _startDurationTimer();
  }

  void declineCall() {
    final session = _session;
    if (session == null) return;

    final ips = session.type == CallType.individual
        ? [session.peerIp!]
        : session.memberIps;

    for (final ip in ips) {
      udp.sendMessage(ip: ip, data: {
        'type': 'CALL_DECLINE',
        'callId': session.callId,
        'declinerDeviceId': myDeviceId,
      });
    }

    _teardown();
  }

  void endCall() {
    final session = _session;
    if (session == null) return;

    final ips = session.type == CallType.individual
        ? [session.peerIp!]
        : session.memberIps;

    for (final ip in ips) {
      udp.sendMessage(ip: ip, data: {
        'type': 'CALL_END',
        'callId': session.callId,
        'enderDeviceId': myDeviceId,
      });
    }

    _teardown();
  }

  // ── Mute ────────────────────────────────────────────────────────────────

  bool _muted = false;
  bool get isMuted => _muted;

  void toggleMute() {
    _muted = !_muted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_muted);
    _notify();
  }

  // ── Speaker ─────────────────────────────────────────────────────────────

  bool _speakerOn = false;
  bool get isSpeakerOn => _speakerOn;

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await Helper.setSpeakerphoneOn(_speakerOn);
    _notify();
  }

  // ── Handling incoming UDP signals ────────────────────────────────────────

  /// Call this from your existing udp.onMessage handler.
  Future<void> handleSignal(String fromIp, Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'CALL_INVITE':
        await _handleInvite(fromIp, data);
        break;
      case 'CALL_ACCEPT':
        await _handleAccept(fromIp, data);
        break;
      case 'CALL_DECLINE':
        _handleDeclineOrEnd(data);
        break;
      case 'CALL_END':
        _handleDeclineOrEnd(data);
        break;
      case 'CALL_OFFER':
        await _handleOffer(fromIp, data);
        break;
      case 'CALL_ANSWER':
        await _handleAnswer(fromIp, data);
        break;
      case 'CALL_ICE':
        await _handleIce(fromIp, data);
        break;
    }
  }

  // ── Signal handlers ──────────────────────────────────────────────────────

  Future<void> _handleInvite(String fromIp, Map<String, dynamic> data) async {
    if (_session != null) {
      // Busy — auto-decline
      udp.sendMessage(ip: fromIp, data: {
        'type': 'CALL_DECLINE',
        'callId': data['callId'],
        'declinerDeviceId': myDeviceId,
        'reason': 'busy',
      });
      return;
    }

    final callType =
        data['callType'] == 'group' ? CallType.group : CallType.individual;

    _session = VoiceCallSession(
      callId: data['callId'] as String,
      type: callType,
      initiatorDeviceId: data['callerDeviceId'] as String,
      initiatorName: data['callerName'] as String,
      peerIp: callType == CallType.individual ? fromIp : null,
      peerName: callType == CallType.individual
          ? (data['callerName'] as String)
          : null,
      groupId: data['groupId'] as String?,
      groupName: data['groupName'] as String?,
      memberIps: callType == CallType.group ? [fromIp] : [],
      state: CallState.ringing,
    );
    _notify();
    onIncomingCall?.call(_session!);
  }

  Future<void> _handleAccept(String fromIp, Map<String, dynamic> data) async {
    final session = _session;
    if (session == null) return;
    if (session.callId != data['callId']) return;

    session.state = CallState.connected;
    _notify();
    _startDurationTimer();
  }

  void _handleDeclineOrEnd(Map<String, dynamic> data) {
    final session = _session;
    if (session == null) return;
    if (session.callId != data['callId']) return;
    _teardown();
  }

  Future<void> _handleOffer(String fromIp, Map<String, dynamic> data) async {
    final session = _session;
    if (session == null) return;

    // Ensure a PC exists for this peer (callee side)
    var pc = _pcs[fromIp];
    if (pc == null) {
      await _initLocalStream();
      pc = await _createPeerConnection(fromIp,
          polite: true, callId: session.callId);
    }

    final sdp = RTCSessionDescription(
      data['sdp'] as String,
      data['sdpType'] as String,
    );
    await pc.setRemoteDescription(sdp);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    udp.sendMessage(ip: fromIp, data: {
      'type': 'CALL_ANSWER',
      'callId': session.callId,
      'sdp': answer.sdp,
      'sdpType': answer.type,
    });
  }

  Future<void> _handleAnswer(String fromIp, Map<String, dynamic> data) async {
    final pc = _pcs[fromIp];
    if (pc == null) return;

    final sdp = RTCSessionDescription(
      data['sdp'] as String,
      data['sdpType'] as String,
    );
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

  // ── WebRTC helpers ────────────────────────────────────────────────────────

  Future<void> _initLocalStream() async {
    _localStream ??= await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
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

    // Add local audio tracks to the connection
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // Forward ICE candidates to the remote peer via UDP
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      udp.sendMessage(ip: peerIp, data: {
        'type': 'CALL_ICE',
        'callId': callId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // flutter_webrtc plays incoming audio automatically on onAddStream
    pc.onAddStream = (stream) {};

    // NOTE: onNegotiationNeeded does NOT exist in webrtc_interface 1.5.x.
    // Instead we drive negotiation explicitly:
    //   - polite=false (caller/initiator): create offer immediately here.
    //   - polite=true  (callee/accepter):  wait for CALL_OFFER signal,
    //     handled in _handleOffer().
    if (!polite) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      udp.sendMessage(ip: peerIp, data: {
        'type': 'CALL_OFFER',
        'callId': callId,
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
    }

    return pc;
  }

  // ── Duration timer ────────────────────────────────────────────────────────

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _session?.elapsed += const Duration(seconds: 1);
      _notify();
    });
  }

  // ── Teardown ──────────────────────────────────────────────────────────────

  Future<void> _teardown() async {
    _durationTimer?.cancel();
    _durationTimer = null;

    for (final pc in _pcs.values) {
      await pc.close();
    }
    _pcs.clear();

    await _localStream?.dispose();
    _localStream = null;

    _muted = false;
    _speakerOn = false;
    _session = null;
    _notify();
  }

  void _notify() {
    _stateController.add(_session);
  }

  void dispose() {
    _teardown();
    _stateController.close();
  }
}
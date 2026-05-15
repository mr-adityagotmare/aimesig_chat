import 'package:flutter/material.dart';

import '../core/network/video_call_service.dart';

export '../core/network/video_call_service.dart'
    show VideoCallState, VideoCallType, VideoCallSession;

class VideoCallProvider extends ChangeNotifier {
  VideoCallService? _service;

  VideoCallService? get service => _service;
  VideoCallSession? get session => _service?.activeSession;

  bool get hasActiveCall => session != null;
  bool get isMuted => _service?.isMuted ?? false;
  bool get isVideoEnabled => _service?.isVideoEnabled ?? true;

  /// Wire up once from main.dart after services are ready.
  void init(VideoCallService svc) {
    _service = svc;
    svc.onSessionChanged.listen((_) => notifyListeners());
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> startIndividualCall({
    required String peerIp,
    required String peerName,
    required String peerDeviceId,
  }) async {
    await _service?.startIndividualCall(
      peerIp: peerIp,
      peerName: peerName,
      peerDeviceId: peerDeviceId,
    );
    notifyListeners();
  }

  Future<void> startGroupCall({
    required String groupId,
    required String groupName,
    required List<String> memberIps,
  }) async {
    await _service?.startGroupCall(
      groupId: groupId,
      groupName: groupName,
      memberIps: memberIps,
    );
    notifyListeners();
  }

  Future<void> acceptCall() async {
    await _service?.acceptCall();
    notifyListeners();
  }

  void declineCall() {
    _service?.declineCall();
    notifyListeners();
  }

  void endCall() {
    _service?.endCall();
    notifyListeners();
  }

  void toggleMute() {
    _service?.toggleMute();
    notifyListeners();
  }

  void toggleVideo() {
    _service?.toggleVideo();
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _service?.switchCamera();
  }
}
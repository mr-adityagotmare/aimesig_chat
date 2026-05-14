import 'package:flutter/material.dart';

import '../core/network/voice_call_service.dart';

export '../core/network/voice_call_service.dart'
    show CallState, CallType, VoiceCallSession;

class CallProvider extends ChangeNotifier {
  VoiceCallService? _service;

  VoiceCallService? get service => _service;
  VoiceCallSession? get session => _service?.activeSession;

  bool get hasActiveCall => session != null;
  bool get isMuted => _service?.isMuted ?? false;
  bool get isSpeakerOn => _service?.isSpeakerOn ?? false;

  /// Wire up the service (called once from main after services are ready).
  void init(VoiceCallService svc) {
    _service = svc;
    svc.onSessionChanged.listen((_) => notifyListeners());
  }

  // ── Delegate actions ────────────────────────────────────────────────────

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

  Future<void> toggleSpeaker() async {
    await _service?.toggleSpeaker();
    notifyListeners();
  }
}
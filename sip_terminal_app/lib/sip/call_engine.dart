enum SipRegState { none, progressing, registered, failed, unregistered }

enum SipCallDir { outgoing, incoming }

enum SipCallKind { init, ring, accepted, ended, busy, failed }

sealed class SipEvent {
  const SipEvent();
}

class RegStateChanged extends SipEvent {
  const RegStateChanged(this.state);
  final SipRegState state;
}

class CallEvent extends SipEvent {
  const CallEvent({
    required this.dir,
    required this.kind,
    this.number,
    this.call,
  });
  final SipCallDir dir;
  final SipCallKind kind;
  final String? number;
  final dynamic call;
}

abstract interface class CallEngine {
  Stream<SipEvent> get events;

  Future<void> start(
    ({String extension, String password}) account,
    String wsUrl,
    String domain, {
    bool trustBadCert = true,
  });

  Future<void> stop();

  Future<void> dial(String number);

  Future<void> answer();

  Future<void> hangup();

  Future<void> setMuted(bool muted);
}

final RegExp _sipNumberPattern = RegExp(r'sip:(\d+)@');
final RegExp _digitsPattern = RegExp(r'^\d+$');

/// 从 remote identity 提取分机号：优先 `sip:(\d+)@`，兼容纯数字 user part。
String? sipNumberFromIdentity(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final m = _sipNumberPattern.firstMatch(raw);
  if (m != null) return m.group(1);
  return _digitsPattern.hasMatch(raw) ? raw : null;
}

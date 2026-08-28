import 'dart:async';

import 'package:sip_ua/sip_ua.dart';

import 'call_engine.dart';

/// sip_ua 1.1.0 真实实现。核对过的 API：
/// - 公开门面是 SIPUAHelper（内部 UA 未导出）：start(UaSettings)/stop/register
/// - helper.call(target, {voiceOnly}) 返回 `Future<bool>`；要求已连接
/// - CallStateEnum 无 RINGING/BUSY/CANCELED：ring=PROGRESS，busy=FAILED(486/600/'Busy')
/// - Call.answer(Map options)/hangup([options])/mute([audio,video])/unmute([audio,video])
/// - UaSettings 无 sessionTimersExpire 字段，呼叫选项默认已带 sessionTimersExpires:120
class UaCallEngine with SipUaHelperListener implements CallEngine {
  final _events = StreamController<SipEvent>.broadcast();
  SIPUAHelper? _ua;
  Call? _active;
  String? _domain;

  @override
  Stream<SipEvent> get events => _events.stream;

  SIPUAHelper? get rawUa => _ua;

  @override
  Future<void> start(
    ({String extension, String password}) account,
    String wsUrl,
    String domain, {
    bool trustBadCert = true,
  }) async {
    _domain = domain;
    final settings = UaSettings()
      ..webSocketUrl = wsUrl
      ..uri = 'sip:${account.extension}@$domain'
      ..authorizationUser = account.extension
      ..password = account.password
      ..displayName = account.extension
      ..userAgent = 'SIP Terminal/1.0'
      ..transportType = TransportType.WS
      ..sessionTimers = true
      ..iceTransportPolicy = IceTransportPolicy.ALL
      ..register = true;
    settings.webSocketSettings.allowBadCertificate = trustBadCert;
    final ua = SIPUAHelper();
    ua.addSipUaHelperListener(this);
    await ua.start(settings);
    ua.register();
    _ua = ua;
  }

  @override
  Future<void> stop() async {
    _ua?.stop();
    _ua = null;
    _active = null;
  }

  @override
  Future<void> dial(String number) async {
    try {
      final ua = _ua;
      final domain = _domain;
      if (ua == null || domain == null) return;
      await ua.call('sip:$number@$domain', voiceOnly: true);
    } catch (e) {
      _events.add(const CallEvent(
        dir: SipCallDir.outgoing,
        kind: SipCallKind.failed,
      ));
    }
  }

  @override
  Future<void> answer() async {
    _active?.answer(<String, dynamic>{
      'mediaConstraints': <String, dynamic>{'audio': true, 'video': false},
    });
  }

  @override
  Future<void> hangup() async {
    _active?.hangup();
  }

  @override
  Future<void> setMuted(bool muted) async {
    final call = _active;
    if (call == null) return;
    if (muted) {
      call.mute(true, false);
    } else {
      call.unmute(true, false);
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void registrationStateChanged(RegistrationState state) {
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        _events.add(RegStateChanged(SipRegState.registered));
      case RegistrationStateEnum.REGISTRATION_FAILED:
        _events.add(RegStateChanged(SipRegState.failed));
      case RegistrationStateEnum.UNREGISTERED:
        _events.add(RegStateChanged(SipRegState.unregistered));
      case RegistrationStateEnum.NONE:
        _events.add(RegStateChanged(SipRegState.none));
      case null:
        break;
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    final dir = call.direction == Direction.incoming
        ? SipCallDir.incoming
        : SipCallDir.outgoing;
    final number = sipNumberFromIdentity(call.remote_identity);
    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        _active = call;
        _events.add(
          CallEvent(
            dir: dir,
            kind: SipCallKind.init,
            number: number,
            call: call,
          ),
        );
      case CallStateEnum.PROGRESS:
        _events.add(
          CallEvent(
            dir: dir,
            kind: SipCallKind.ring,
            number: number,
            call: call,
          ),
        );
      case CallStateEnum.ACCEPTED:
        _events.add(
          CallEvent(
            dir: dir,
            kind: SipCallKind.accepted,
            number: number,
            call: call,
          ),
        );
      case CallStateEnum.ENDED:
        _active = null;
        _events.add(
          CallEvent(dir: dir, kind: SipCallKind.ended, number: number),
        );
      case CallStateEnum.FAILED:
        _active = null;
        final cause = state.cause;
        final busy =
            cause != null &&
            (cause.status_code == 486 ||
                cause.status_code == 600 ||
                cause.cause == 'Busy');
        _events.add(
          CallEvent(
            dir: dir,
            kind: busy ? SipCallKind.busy : SipCallKind.failed,
            number: number,
          ),
        );
      default:
        break;
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}
}

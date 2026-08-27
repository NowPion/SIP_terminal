import 'dart:async';

import 'call_engine.dart';

enum SipUiPhase { idle, outgoing, incoming, active, ended }

enum SipDisposition { answered, busy, noAnswer, missed, failed }

extension SipDispositionWire on SipDisposition {
  String get wire => switch (this) {
    SipDisposition.answered => 'answered',
    SipDisposition.busy => 'busy',
    SipDisposition.noAnswer => 'no_answer',
    SipDisposition.missed => 'missed',
    SipDisposition.failed => 'failed',
  };
}

class SipUiState {
  const SipUiState({
    required this.phase,
    this.number,
    this.startedAt,
    this.muted = false,
    this.message,
  });

  const SipUiState.idle() : this(phase: SipUiPhase.idle);

  const SipUiState.outgoing(String number)
    : this(phase: SipUiPhase.outgoing, number: number);

  const SipUiState.incoming(String number)
    : this(phase: SipUiPhase.incoming, number: number);

  const SipUiState.active(
    String number,
    DateTime startedAt, {
    bool muted = false,
  }) : this(
         phase: SipUiPhase.active,
         number: number,
         startedAt: startedAt,
         muted: muted,
       );

  const SipUiState.ended(String message)
    : this(phase: SipUiPhase.ended, message: message);

  final SipUiPhase phase;
  final String? number;
  final DateTime? startedAt;
  final bool muted;
  final String? message;

  SipUiState copyWith({
    String? number,
    DateTime? startedAt,
    bool? muted,
    String? message,
  }) => SipUiState(
    phase: phase,
    number: number ?? this.number,
    startedAt: startedAt ?? this.startedAt,
    muted: muted ?? this.muted,
    message: message ?? this.message,
  );

  @override
  bool operator ==(Object other) =>
      other is SipUiState &&
      other.phase == phase &&
      other.number == number &&
      other.startedAt == startedAt &&
      other.muted == muted &&
      other.message == message;

  @override
  int get hashCode => Object.hash(phase, number, startedAt, muted, message);

  @override
  String toString() =>
      'SipUiState(${phase.name}, number=$number, startedAt=$startedAt, '
      'muted=$muted, message=$message)';
}

class SipServiceState {
  const SipServiceState({
    this.reg = SipRegState.none,
    this.call = const SipUiState.idle(),
  });

  final SipRegState reg;
  final SipUiState call;

  SipServiceState copyWith({SipRegState? reg, SipUiState? call}) =>
      SipServiceState(reg: reg ?? this.reg, call: call ?? this.call);

  @override
  bool operator ==(Object other) =>
      other is SipServiceState && other.reg == reg && other.call == call;

  @override
  int get hashCode => Object.hash(reg, call);

  @override
  String toString() => 'SipServiceState(reg=${reg.name}, call=$call)';
}

class SipCallLog {
  SipCallLog({
    required this.direction,
    required this.remoteNumber,
    required this.startedAt,
    required this.durationSec,
    required this.disposition,
  });

  final String direction; // 'in' | 'out'
  final String remoteNumber;
  final DateTime startedAt;
  final int durationSec;
  final String disposition; // answered|busy|no_answer|missed|failed

  @override
  String toString() =>
      'SipCallLog($direction $remoteNumber $disposition ${durationSec}s)';
}

/// 引擎无关的通话状态机：把 SipEvent 流折叠成 SipServiceState，
/// 并在通话终态时产出 SipCallLog（history 写库由 onCallFinished 订阅方负责）。
class SipService {
  SipService(
    this._engine, {
    required this._onCallFinished,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _sub = _engine.events.listen(_onEvent);
  }

  final CallEngine _engine;
  final void Function(SipCallLog) _onCallFinished;
  final DateTime Function() _now;

  StreamSubscription<SipEvent>? _sub;
  final _stateCtrl = StreamController<SipServiceState>.broadcast();
  SipServiceState _state = const SipServiceState();

  SipCallDir? _dir;
  String? _number;
  DateTime? _initAt;
  DateTime? _acceptedAt;
  bool _accepted = false;
  bool _finished = false;

  SipServiceState get state => _state;
  Stream<SipServiceState> get stateStream => _stateCtrl.stream;
  Stream<SipUiState> get uiState => stateStream.map((s) => s.call);
  SipRegState get regState => _state.reg;

  Future<void> dial(String number) => _engine.dial(number);

  Future<void> answer() => _engine.answer();

  Future<void> hangup() => _engine.hangup();

  Future<void> setMuted(bool muted) async {
    if (_state.call.phase == SipUiPhase.active) {
      _set(_state.copyWith(call: _state.call.copyWith(muted: muted)));
    }
    await _engine.setMuted(muted);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _stateCtrl.close();
  }

  void _set(SipServiceState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void _onEvent(SipEvent event) {
    switch (event) {
      case RegStateChanged reg:
        _set(_state.copyWith(reg: reg.state));
      case CallEvent call:
        _onCallEvent(call);
    }
  }

  void _onCallEvent(CallEvent e) {
    switch (e.kind) {
      case SipCallKind.init:
        _dir = e.dir;
        _number = e.number ?? '';
        _initAt = _now();
        _acceptedAt = null;
        _accepted = false;
        _finished = false;
        _set(
          _state.copyWith(
            call: e.dir == SipCallDir.outgoing
                ? SipUiState.outgoing(_number!)
                : SipUiState.incoming(_number!),
          ),
        );
      case SipCallKind.ring:
        break;
      case SipCallKind.accepted:
        _accepted = true;
        final t = _now();
        _acceptedAt = t;
        _set(_state.copyWith(call: SipUiState.active(_number ?? '', t)));
      case SipCallKind.busy:
        _finalize(SipDisposition.busy, '对方忙');
      case SipCallKind.failed:
        if (_accepted) {
          _finalize(SipDisposition.answered, '通话结束');
        } else if (_dir == SipCallDir.incoming) {
          _finalize(SipDisposition.missed, '未接听');
        } else {
          _finalize(SipDisposition.failed, '呼叫失败');
        }
      case SipCallKind.ended:
        if (_accepted) {
          _finalize(SipDisposition.answered, '通话结束');
        } else if (_dir == SipCallDir.incoming) {
          _finalize(SipDisposition.missed, '未接听');
        } else {
          _finalize(SipDisposition.noAnswer, '无人接听');
        }
    }
  }

  void _finalize(SipDisposition disposition, String message) {
    if (_finished) return;
    _finished = true;
    final end = _now();
    final acceptedAt = _acceptedAt;
    final duration = acceptedAt == null
        ? 0
        : end.difference(acceptedAt).inSeconds;
    _onCallFinished(
      SipCallLog(
        direction: _dir == SipCallDir.incoming ? 'in' : 'out',
        remoteNumber: _number ?? '',
        startedAt: _initAt ?? end,
        durationSec: duration < 0 ? 0 : duration,
        disposition: disposition.wire,
      ),
    );
    _set(_state.copyWith(call: SipUiState.ended(message)));
  }
}

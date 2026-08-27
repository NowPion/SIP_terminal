import 'package:drift/drift.dart';

/// 本地通话记录缓存（服务端 call_records 的镜像 + 未上报队列）。
class LocalCalls extends Table {
  IntColumn get id => integer().autoIncrement()(); // 本地自增
  IntColumn get serverId => integer().nullable()(); // 服务端 id，同步后回填
  TextColumn get remoteNumber => text()();
  TextColumn get direction => text()(); // in|out|missed
  TextColumn get disposition => text()(); // answered|no_answer|busy|failed
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  BoolColumn get pushed => boolean().withDefault(const Constant(false))();
}

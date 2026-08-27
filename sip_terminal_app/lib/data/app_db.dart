import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'call_record.dart';

part 'app_db.g.dart';

@DriftDatabase(tables: [LocalCalls])
class AppDb extends _$AppDb {
  AppDb() : super(_open());

  /// 测试注入内存库
  AppDb.forTest(super.e);

  @override
  int get schemaVersion => 1;

  static LazyDatabase _open() => LazyDatabase(() async {
        final dir = await getApplicationDocumentsDirectory();
        return NativeDatabase.createInBackground(
            File('${dir.path}/sip_terminal.db'));
      });
}

final appDbProvider = Provider<AppDb>((ref) {
  final db = AppDb();
  ref.onDispose(db.close);
  return db;
});

import 'package:folego/core/db/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Banco SQLite em memória (sqflite_common_ffi), já migrado e com seeds.
Future<Database> openTestDb() {
  sqfliteFfiInit();
  return openWithFactory(databaseFactoryFfi, inMemoryDatabasePath);
}

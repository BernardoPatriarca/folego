// Abertura do banco SQLite (sqflite) com migrations.
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

const databaseFileName = 'folego.db';

/// Abre (ou cria) o banco do app no diretório padrão do Android.
Future<Database> openFolegoDatabase() async {
  final dir = await getDatabasesPath();
  return openWithFactory(databaseFactory, p.join(dir, databaseFileName));
}

/// Usado também nos testes, com `databaseFactoryFfi` e `inMemoryDatabasePath`.
Future<Database> openWithFactory(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => migrate(db, 0, version),
      onUpgrade: (db, oldV, newV) => migrate(db, oldV, newV),
      singleInstance: false,
    ),
  );
}

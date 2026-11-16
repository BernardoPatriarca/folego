// Backup completo em JSON e importação (substitui tudo).
//
// Formato: {app, formato, schema_version, exportado_em, tabelas: {nome: [linhas]}}.
// O PIN (cofre seguro) nunca entra no backup.
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/db/schema.dart';
import '../../domain/dates.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resumo exibido antes de confirmar a importação.
class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.counts,
  });

  final DateTime? exportedAt;
  final Map<String, int> counts;
}

class BackupService {
  BackupService(this.db);
  final Database db;

  static const appId = 'folego';
  static const format = 1;

  Future<Map<String, Object?>> exportData({DateTime? now}) async {
    final tables = <String, Object?>{};
    for (final t in tablesInOrder) {
      tables[t] = await db.query(t);
    }
    return {
      'app': appId,
      'formato': format,
      'schema_version': schemaVersion,
      'exportado_em': (now ?? DateTime.now()).toIso8601String(),
      'tabelas': tables,
    };
  }

  Future<String> exportJson({DateTime? now}) async =>
      const JsonEncoder.withIndent(' ').convert(await exportData(now: now));

  static String fileName(DateTime now) => 'folego-backup-${toIsoDate(now)}.json';

  /// Lê e valida o arquivo. Lança [BackupException] com mensagem amigável.
  BackupSummary validate(Map<String, Object?> data) {
    if (data['app'] != appId) {
      throw BackupException('Este arquivo não é um backup do Fôlego.');
    }
    final v = data['schema_version'];
    if (v is! int) throw BackupException('Backup sem versão de schema.');
    if (v > schemaVersion) {
      throw BackupException(
          'Backup feito numa versão mais nova do app (schema $v). '
          'Atualize o Fôlego antes de importar.');
    }
    if (v < 1) throw BackupException('Versão de schema inválida ($v).');
    final tables = data['tabelas'];
    if (tables is! Map) throw BackupException('Backup sem tabelas.');
    for (final t in tables.keys) {
      if (!tablesInOrder.contains(t)) {
        throw BackupException('Tabela desconhecida no backup: $t.');
      }
    }
    return BackupSummary(
      exportedAt: DateTime.tryParse('${data['exportado_em']}'),
      counts: {
        for (final t in tablesInOrder) t: (tables[t] as List?)?.length ?? 0,
      },
    );
  }

  Map<String, Object?> decode(String json) {
    try {
      final d = jsonDecode(json);
      if (d is! Map<String, Object?>) throw const FormatException();
      return d;
    } on FormatException {
      throw BackupException('Arquivo JSON inválido.');
    }
  }

  /// Substitui todos os dados pelo conteúdo do backup, numa transação só.
  Future<void> importData(Map<String, Object?> data) async {
    validate(data);
    final tables = (data['tabelas'] as Map).cast<String, Object?>();
    await db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final t in tablesInOrder.reversed) {
        await txn.delete(t);
      }
      await txn.delete('sqlite_sequence');
      for (final t in tablesInOrder) {
        final rows = (tables[t] as List?) ?? const [];
        for (final r in rows) {
          await txn.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });
  }
}

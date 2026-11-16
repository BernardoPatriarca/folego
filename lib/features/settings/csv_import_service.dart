// Grava no banco as avaliações lidas do CSV (depois da pré-visualização).
import 'package:sqflite/sqflite.dart';

import '../../domain/csv_import.dart';
import '../../domain/models.dart';
import '../body/body_repository.dart';
import '../catalog/catalog_repository.dart';

enum DuplicatePolicy { replace, skip }

class CsvImportReport {
  const CsvImportReport({
    required this.inserted,
    required this.replaced,
    required this.skipped,
    required this.createdTypes,
  });

  final int inserted;
  final int replaced;
  final int skipped;
  final int createdTypes;
}

class CsvImportService {
  CsvImportService(this.db, this.body, this.catalog);
  final Database db;
  final BodyRepository body;
  final CatalogRepository catalog;

  /// Datas do arquivo que já têm avaliação no banco.
  Future<Set<DateTime>> existingDates(List<CsvAssessmentRow> rows) async {
    final out = <DateTime>{};
    for (final r in rows) {
      if (await body.idOnDate(r.date) != null) out.add(r.date);
    }
    return out;
  }

  /// Importa [rows]. Colunas em [createTypes] viram tipos de medida novos
  /// (categoria "outro", unidade [newTypeUnit]); colunas desconhecidas que não
  /// estiverem nessa lista são ignoradas.
  Future<CsvImportReport> apply({
    required List<CsvAssessmentRow> rows,
    required Set<String> createTypes,
    required DuplicatePolicy policy,
    String newTypeUnit = 'cm',
  }) async {
    return db.transaction((txn) async {
      final typeRows = await txn.query('medida_tipo');
      final byName = {
        for (final t in typeRows)
          (t['nome'] as String).toLowerCase(): t['id'] as int
      };
      var created = 0;
      for (final name in createTypes) {
        if (byName.containsKey(name.toLowerCase())) continue;
        final id = await catalog.addMeasureType(
            MeasureType(
                name: name,
                unit: newTypeUnit,
                category: MeasureCategory.other),
            txn: txn);
        byName[name.toLowerCase()] = id;
        created++;
      }

      var inserted = 0, replaced = 0, skipped = 0;
      for (final r in rows) {
        final existing = await body.idOnDate(r.date, txn: txn);
        if (existing != null && policy == DuplicatePolicy.skip) {
          skipped++;
          continue;
        }
        final measures = <int, double>{};
        r.measures.forEach((name, value) {
          final id = byName[name.toLowerCase()];
          if (id != null) measures[id] = value;
        });
        await body.save(
          BodyAssessment(
            id: existing,
            date: r.date,
            origin: r.origin ?? 'importação CSV',
            values: r.values,
            measures: measures,
            note: r.note,
          ),
          txn: txn,
        );
        if (existing != null) {
          replaced++;
        } else {
          inserted++;
        }
      }
      return CsvImportReport(
        inserted: inserted,
        replaced: replaced,
        skipped: skipped,
        createdTypes: created,
      );
    });
  }
}

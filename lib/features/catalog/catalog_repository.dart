// Catálogo de exercícios e de tipos de medida.
//
// Itens com histórico não podem ser apagados, só desativados.
import 'package:sqflite/sqflite.dart';

import '../../core/db/mappers.dart';
import '../../domain/models.dart';

class CatalogException implements Exception {
  CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CatalogRepository {
  CatalogRepository(this.db);
  final Database db;

  // ---------- Exercícios ----------

  Future<List<Exercise>> exercises({bool onlyActive = false}) async {
    final rows = await db.query('exercicio',
        where: onlyActive ? 'ativo = 1' : null,
        orderBy: 'ordem, nome COLLATE NOCASE');
    return rows.map(exerciseFromRow).toList();
  }

  Future<Exercise?> exercise(int id) async {
    final rows = await db.query('exercicio', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : exerciseFromRow(rows.first);
  }

  Future<int> addExercise(Exercise e) async {
    await _checkExerciseName(e.name);
    final maxOrder = Sqflite.firstIntValue(
            await db.rawQuery('SELECT MAX(ordem) FROM exercicio')) ??
        0;
    return db.insert(
        'exercicio', exerciseToRow(e.copyWith(order: maxOrder + 1)));
  }

  Future<void> updateExercise(Exercise e) async {
    await _checkExerciseName(e.name, exceptId: e.id);
    final current = await exercise(e.id!);
    if (current != null &&
        current.unit != e.unit &&
        await exerciseHasHistory(e.id!)) {
      throw CatalogException(
          'Não dá para trocar a unidade de um exercício com histórico.');
    }
    await db.update('exercicio', exerciseToRow(e),
        where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> setExerciseActive(int id, bool active) => db.update(
      'exercicio', {'ativo': active ? 1 : 0},
      where: 'id = ?', whereArgs: [id]);

  /// Ativa só os exercícios em [ids] (onboarding).
  Future<void> setActiveExercises(Set<int> ids) async {
    await db.transaction((txn) async {
      await txn.update('exercicio', {'ativo': 0});
      for (final id in ids) {
        await txn.update('exercicio', {'ativo': 1},
            where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<bool> exerciseHasHistory(int id) async {
    final n = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT (SELECT COUNT(*) FROM meta WHERE exercicio_id = ?) + '
        '(SELECT COUNT(*) FROM recorde WHERE exercicio_id = ?)',
        [id, id]));
    return (n ?? 0) > 0;
  }

  Future<void> deleteExercise(int id) async {
    if (await exerciseHasHistory(id)) {
      throw CatalogException(
          'Este exercício tem histórico. Você pode só desativá-lo.');
    }
    await db.delete('exercicio', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _checkExerciseName(String name, {int? exceptId}) async {
    final n = name.trim();
    if (n.isEmpty) throw CatalogException('Informe o nome.');
    final rows = await db.query('exercicio',
        where: 'nome = ? COLLATE NOCASE${exceptId == null ? '' : ' AND id <> ?'}',
        whereArgs: [n, ?exceptId]);
    if (rows.isNotEmpty) {
      throw CatalogException('Já existe um exercício com esse nome.');
    }
  }

  // ---------- Tipos de medida ----------

  Future<List<MeasureType>> measureTypes({bool onlyActive = false}) async {
    final rows = await db.query('medida_tipo',
        where: onlyActive ? 'ativo = 1' : null,
        orderBy: 'ordem, nome COLLATE NOCASE');
    return rows.map(measureTypeFromRow).toList();
  }

  Future<int> addMeasureType(MeasureType t, {DatabaseExecutor? txn}) async {
    final ex = txn ?? db;
    await _checkMeasureName(t.name, ex: ex);
    final maxOrder = Sqflite.firstIntValue(
            await ex.rawQuery('SELECT MAX(ordem) FROM medida_tipo')) ??
        0;
    final row = measureTypeToRow(t)..['ordem'] = maxOrder + 1;
    return ex.insert('medida_tipo', row);
  }

  Future<void> updateMeasureType(MeasureType t) async {
    await _checkMeasureName(t.name, exceptId: t.id, ex: db);
    await db.update('medida_tipo', measureTypeToRow(t),
        where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> setMeasureTypeActive(int id, bool active) => db.update(
      'medida_tipo', {'ativo': active ? 1 : 0},
      where: 'id = ?', whereArgs: [id]);

  Future<bool> measureTypeHasHistory(int id) async {
    final n = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM medida WHERE medida_tipo_id = ?', [id]));
    final goals = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM meta_corporal WHERE metrica = ?',
        ['medida:$id']));
    return (n ?? 0) + (goals ?? 0) > 0;
  }

  Future<void> deleteMeasureType(int id) async {
    if (await measureTypeHasHistory(id)) {
      throw CatalogException(
          'Esta medida tem histórico. Você pode só desativá-la.');
    }
    await db.delete('medida_tipo', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _checkMeasureName(String name,
      {int? exceptId, required DatabaseExecutor ex}) async {
    final n = name.trim();
    if (n.isEmpty) throw CatalogException('Informe o nome.');
    final rows = await ex.query('medida_tipo',
        where: 'nome = ? COLLATE NOCASE${exceptId == null ? '' : ' AND id <> ?'}',
        whereArgs: [n, ?exceptId]);
    if (rows.isNotEmpty) {
      throw CatalogException('Já existe uma medida com esse nome.');
    }
  }
}

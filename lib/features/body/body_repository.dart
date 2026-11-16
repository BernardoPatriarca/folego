// Avaliações corporais, medidas e metas corporais.
import 'package:sqflite/sqflite.dart';

import '../../core/db/mappers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';

class BodyRepository {
  BodyRepository(this.db);
  final Database db;

  /// Todas as avaliações, da mais recente para a mais antiga.
  Future<List<BodyAssessment>> assessments() async {
    final rows =
        await db.query('avaliacao_corporal', orderBy: 'data DESC, id DESC');
    final measureRows = await db.query('medida');
    final byAssessment = <int, Map<int, double>>{};
    for (final m in measureRows) {
      byAssessment.putIfAbsent(m['avaliacao_id'] as int, () => {})[
          m['medida_tipo_id'] as int] = (m['valor'] as num).toDouble();
    }
    return rows
        .map((r) => assessmentFromRow(r, byAssessment[r['id']] ?? const {}))
        .toList();
  }

  Future<BodyAssessment?> assessment(int id) async {
    final rows = await db
        .query('avaliacao_corporal', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final ms = await db
        .query('medida', where: 'avaliacao_id = ?', whereArgs: [id]);
    return assessmentFromRow(rows.first, {
      for (final m in ms)
        m['medida_tipo_id'] as int: (m['valor'] as num).toDouble()
    });
  }

  /// Id de uma avaliação já existente na data (para o CSV).
  Future<int?> idOnDate(DateTime date, {DatabaseExecutor? txn}) async {
    final rows = await (txn ?? db).query('avaliacao_corporal',
        columns: ['id'],
        where: 'data = ?',
        whereArgs: [toIsoDate(date)],
        orderBy: 'id DESC',
        limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  /// Insere (sem id) ou atualiza (com id). Devolve o id.
  Future<int> save(BodyAssessment a, {DatabaseExecutor? txn}) async {
    Future<int> run(DatabaseExecutor ex) async {
      int id;
      if (a.id == null) {
        id = await ex.insert('avaliacao_corporal', assessmentToRow(a));
      } else {
        id = a.id!;
        await ex.update('avaliacao_corporal', assessmentToRow(a),
            where: 'id = ?', whereArgs: [id]);
        await ex.delete('medida', where: 'avaliacao_id = ?', whereArgs: [id]);
      }
      for (final e in a.measures.entries) {
        await ex.insert('medida',
            {'avaliacao_id': id, 'medida_tipo_id': e.key, 'valor': e.value});
      }
      return id;
    }

    if (txn != null) return run(txn);
    return db.transaction(run);
  }

  /// Apaga a avaliação (medidas vão junto) e devolve o que foi apagado.
  Future<BodyAssessment?> delete(int id) async {
    final a = await assessment(id);
    await db.delete('avaliacao_corporal', where: 'id = ?', whereArgs: [id]);
    return a;
  }

  /// Regrava uma avaliação apagada com o mesmo id (desfazer).
  Future<void> restore(BodyAssessment a) async {
    await db.transaction((txn) async {
      await txn.insert('avaliacao_corporal', {
        'id': a.id,
        ...assessmentToRow(a),
      });
      for (final e in a.measures.entries) {
        await txn.insert('medida',
            {'avaliacao_id': a.id, 'medida_tipo_id': e.key, 'valor': e.value});
      }
    });
  }

  // ---------- Metas corporais ----------

  Future<List<BodyGoal>> goals({bool onlyActive = false}) async {
    final rows = await db.query('meta_corporal',
        where: onlyActive ? 'ativa = 1' : null, orderBy: 'id');
    return rows.map(bodyGoalFromRow).toList();
  }

  Future<int> saveGoal(BodyGoal g) async {
    if (g.id == null) return db.insert('meta_corporal', bodyGoalToRow(g));
    await db.update('meta_corporal', bodyGoalToRow(g),
        where: 'id = ?', whereArgs: [g.id]);
    return g.id!;
  }

  Future<Map<String, Object?>?> deleteGoal(int id) async {
    final rows =
        await db.query('meta_corporal', where: 'id = ?', whereArgs: [id]);
    await db.delete('meta_corporal', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> restoreGoal(Map<String, Object?> row) =>
      db.insert('meta_corporal', row);
}

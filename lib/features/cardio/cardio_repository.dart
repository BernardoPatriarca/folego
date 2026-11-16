// Sessões de cardio (dados copiados do smartwatch).
import 'package:sqflite/sqflite.dart';

import '../../core/db/mappers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/weekly_statement.dart';
import '../today/workout_repository.dart';

class CardioRepository {
  CardioRepository(this.db, this.workouts);
  final Database db;
  final WorkoutRepository workouts;

  /// Grava a sessão no dia [date]. [session.dayId] é ignorado.
  Future<int> add(DateTime date, CardioSession session) {
    return db.transaction((txn) async {
      final dayId = await workouts.ensureDay(date, txn: txn);
      return txn.insert('cardio', cardioToRow(_withDay(session, dayId)));
    });
  }

  /// Atualiza a sessão (pode mudar de dia).
  Future<void> update(int id, DateTime date, CardioSession session) {
    return db.transaction((txn) async {
      final dayId = await workouts.ensureDay(date, txn: txn);
      await txn.update('cardio', cardioToRow(_withDay(session, dayId)),
          where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Apaga e devolve a linha apagada (para desfazer).
  Future<Map<String, Object?>?> delete(int id) async {
    final rows = await db.query('cardio', where: 'id = ?', whereArgs: [id]);
    await db.delete('cardio', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> restore(Map<String, Object?> row) => db.insert('cardio', row);

  Future<List<CardioView>> range(DateTime from, DateTime to) async {
    final rows = await db.rawQuery('''
SELECT c.*, d.data FROM cardio c JOIN treino_dia d ON d.id = c.treino_dia_id
WHERE d.data BETWEEN ? AND ? ORDER BY d.data, c.id''',
        [toIsoDate(from), toIsoDate(to)]);
    return rows
        .map((r) => CardioView(
            session: cardioFromRow(r),
            date: fromIsoDate(r['data'] as String)))
        .toList();
  }

  Future<List<CardioView>> forDate(DateTime date) => range(date, date);

  Future<List<CardioView>> all() =>
      range(DateTime(1900), DateTime(9999, 12, 31));

  Future<List<StatementCardio>> statementCardio(
      DateTime from, DateTime to) async {
    final list = await range(from, to);
    return list
        .map((c) => StatementCardio(
              date: c.date,
              minutes: c.session.durationMin,
              kcal: c.session.kcal,
              distanceKm: c.session.distanceKm,
            ))
        .toList();
  }

  CardioSession _withDay(CardioSession s, int dayId) => CardioSession(
        dayId: dayId,
        type: s.type,
        durationMin: s.durationMin,
        kcal: s.kcal,
        avgHr: s.avgHr,
        maxHr: s.maxHr,
        distanceKm: s.distanceKm,
        steps: s.steps,
        note: (s.note?.trim().isEmpty ?? true) ? null : s.note!.trim(),
      );
}

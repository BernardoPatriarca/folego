// Dias de treino, metas, lançamentos e recordes.
import 'package:sqflite/sqflite.dart';

import '../../core/db/mappers.dart';
import '../../domain/compliance.dart';
import '../../domain/dates.dart';
import '../../domain/golden_rule.dart';
import '../../domain/models.dart';
import '../../domain/weekly_statement.dart';

/// Resultado de um lançamento de força.
class LogResult {
  const LogResult({
    required this.goalId,
    required this.isRecord,
    this.previousBest,
  });

  final int goalId;
  final bool isRecord;
  final double? previousBest;
}

/// Recorde com o nome do exercício (para a linha do tempo).
class RecordView {
  const RecordView({required this.record, required this.exercise});
  final PersonalRecord record;
  final Exercise exercise;
}

class WorkoutRepository {
  WorkoutRepository(this.db);
  final Database db;

  // ---------- Dias ----------

  Future<WorkoutDay?> day(DateTime date, {DatabaseExecutor? txn}) async {
    final rows = await (txn ?? db).query('treino_dia',
        where: 'data = ?', whereArgs: [toIsoDate(date)]);
    return rows.isEmpty ? null : dayFromRow(rows.first);
  }

  /// Id do dia, criando a linha se ainda não existir.
  Future<int> ensureDay(DateTime date, {DatabaseExecutor? txn}) async {
    final ex = txn ?? db;
    final existing = await day(date, txn: ex);
    if (existing != null) return existing.id!;
    return ex.insert('treino_dia', {'data': toIsoDate(date)});
  }

  Future<void> setRest(DateTime date, bool rest) async {
    final id = await ensureDay(date);
    await db.update('treino_dia', {'descanso': rest ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Metas ----------

  Future<List<GoalView>> goalsForDate(DateTime date) async {
    final rows = await db.rawQuery('''
SELECT m.*, e.id AS e_id, e.nome AS e_nome, e.unidade AS e_unidade,
       e.grupo AS e_grupo, e.ativo AS e_ativo, e.ordem AS e_ordem
FROM meta m
JOIN treino_dia d ON d.id = m.treino_dia_id
JOIN exercicio e ON e.id = m.exercicio_id
WHERE d.data = ?
ORDER BY e.ordem, e.nome''', [toIsoDate(date)]);
    return rows
        .map((r) => GoalView(
              goal: goalFromRow(r),
              exercise: _exerciseFromPrefixed(r),
              date: dateOnly(date),
            ))
        .toList();
  }

  Future<Goal?> goal(int id) async {
    final rows = await db.query('meta', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : goalFromRow(rows.first);
  }

  /// Realizados do exercício em sessões antes de [before], da mais recente
  /// para a mais antiga (no máximo [limit]).
  Future<List<double>> recentDone(int exerciseId, DateTime before,
      {int limit = 50}) async {
    final rows = await db.rawQuery('''
SELECT m.realizado FROM meta m JOIN treino_dia d ON d.id = m.treino_dia_id
WHERE m.exercicio_id = ? AND m.realizado IS NOT NULL AND d.data < ?
ORDER BY d.data DESC LIMIT ?''', [exerciseId, toIsoDate(before), limit]);
    return rows.map((r) => (r['realizado'] as num).toDouble()).toList();
  }

  /// Meta sugerida pela regra de ouro para [exercise] em [date].
  Future<int?> suggestion(
      Exercise exercise, DateTime date, GoldenRuleConfig rule) async {
    final done = await recentDone(exercise.id!, date, limit: rule.window);
    return suggestedTarget(
        bestRecent(done, rule.window), rule.factor, exercise.unit);
  }

  Future<int> addGoal({
    required DateTime date,
    required int exerciseId,
    required double target,
    int? sets,
    bool bold = false,
  }) async {
    return db.transaction((txn) async {
      final dayId = await ensureDay(date, txn: txn);
      return txn.insert('meta', {
        'treino_dia_id': dayId,
        'exercicio_id': exerciseId,
        'alvo': target,
        'series': sets,
        'ousada': bold ? 1 : 0,
      });
    });
  }

  Future<void> updateGoalTarget(int goalId,
      {required double target, int? sets, required bool bold}) {
    return db.update(
        'meta', {'alvo': target, 'series': sets, 'ousada': bold ? 1 : 0},
        where: 'id = ?', whereArgs: [goalId]);
  }

  /// Apaga a meta e devolve as linhas apagadas (meta e recorde) para desfazer.
  Future<Map<String, Object?>> deleteGoal(int goalId) async {
    return db.transaction((txn) async {
      final goal = await txn.query('meta', where: 'id = ?', whereArgs: [goalId]);
      final recs =
          await txn.query('recorde', where: 'meta_id = ?', whereArgs: [goalId]);
      await txn.delete('recorde', where: 'meta_id = ?', whereArgs: [goalId]);
      await txn.delete('meta', where: 'id = ?', whereArgs: [goalId]);
      return {
        'meta': goal.isEmpty ? null : goal.first,
        'recordes': recs,
      };
    });
  }

  Future<void> restoreGoal(Map<String, Object?> snapshot) async {
    await db.transaction((txn) async {
      final goal = snapshot['meta'] as Map<String, Object?>?;
      if (goal != null) await txn.insert('meta', goal);
      for (final r in snapshot['recordes'] as List) {
        await txn.insert('recorde', Map<String, Object?>.from(r as Map));
      }
    });
  }

  /// Lança o realizado do exercício no dia.
  ///
  /// Sem meta planejada, cria uma com alvo = realizado (lançamento fora do
  /// plano). Recalcula o recorde ligado a esta meta.
  Future<LogResult> logDone({
    required DateTime date,
    required int exerciseId,
    required double done,
    int? effort,
  }) async {
    return db.transaction((txn) async {
      final dayId = await ensureDay(date, txn: txn);
      final existing = await txn.query('meta',
          where: 'treino_dia_id = ? AND exercicio_id = ?',
          whereArgs: [dayId, exerciseId]);
      int goalId;
      if (existing.isEmpty) {
        goalId = await txn.insert('meta', {
          'treino_dia_id': dayId,
          'exercicio_id': exerciseId,
          'alvo': done,
          'realizado': done,
          'esforco': effort,
        });
      } else {
        goalId = existing.first['id'] as int;
        await txn.update('meta', {'realizado': done, 'esforco': effort},
            where: 'id = ?', whereArgs: [goalId]);
      }

      final prev = await txn.rawQuery(
          'SELECT MAX(realizado) AS m FROM meta '
          'WHERE exercicio_id = ? AND id <> ? AND realizado IS NOT NULL',
          [exerciseId, goalId]);
      final previousBest = (prev.first['m'] as num?)?.toDouble();
      await txn.delete('recorde', where: 'meta_id = ?', whereArgs: [goalId]);
      final record = isNewRecord(previousBest, done);
      if (record) {
        await txn.insert('recorde', {
          'exercicio_id': exerciseId,
          'valor': done,
          'data': toIsoDate(date),
          'meta_id': goalId,
        });
      }
      return LogResult(
          goalId: goalId, isRecord: record, previousBest: previousBest);
    });
  }

  /// Desfaz o lançamento (mantém a meta planejada).
  Future<void> clearDone(int goalId) async {
    await db.transaction((txn) async {
      await txn.update('meta', {'realizado': null, 'esforco': null},
          where: 'id = ?', whereArgs: [goalId]);
      await txn.delete('recorde', where: 'meta_id = ?', whereArgs: [goalId]);
    });
  }

  /// Copia as metas de [from] para [to], recalculando o "ousada" pela regra
  /// de ouro do dia de destino. Devolve quantas metas foram copiadas.
  Future<int> copyPlan(
      DateTime from, DateTime to, GoldenRuleConfig rule) async {
    final source = await goalsForDate(from);
    if (source.isEmpty) return 0;
    final current = await goalsForDate(to);
    final already = current.map((g) => g.exercise.id).toSet();
    var copied = 0;
    for (final g in source) {
      if (already.contains(g.exercise.id) || !g.exercise.active) continue;
      final sug = await suggestion(g.exercise, to, rule);
      await addGoal(
        date: to,
        exerciseId: g.exercise.id!,
        target: g.goal.target,
        sets: g.goal.sets,
        bold: isBoldTarget(g.goal.target, sug),
      );
      copied++;
    }
    return copied;
  }

  // ---------- Consultas para Evolução, Extrato e Sequência ----------

  /// Dias ativos: meta lançada, cardio ou descanso planejado.
  Future<Set<DateTime>> activeDays() async {
    final rows = await db.rawQuery('''
SELECT d.data FROM treino_dia d
WHERE d.descanso = 1
   OR EXISTS (SELECT 1 FROM meta m WHERE m.treino_dia_id = d.id AND m.realizado IS NOT NULL)
   OR EXISTS (SELECT 1 FROM cardio c WHERE c.treino_dia_id = d.id)''');
    return rows.map((r) => fromIsoDate(r['data'] as String)).toSet();
  }

  Future<Set<DateTime>> restDays() async {
    final rows =
        await db.query('treino_dia', columns: ['data'], where: 'descanso = 1');
    return rows.map((r) => fromIsoDate(r['data'] as String)).toSet();
  }

  /// Série histórica (data, realizado) de um exercício, em ordem de data.
  Future<List<(DateTime, double)>> exerciseSeries(int exerciseId) async {
    final rows = await db.rawQuery('''
SELECT d.data, m.realizado FROM meta m JOIN treino_dia d ON d.id = m.treino_dia_id
WHERE m.exercicio_id = ? AND m.realizado IS NOT NULL ORDER BY d.data''',
        [exerciseId]);
    return rows
        .map((r) => (
              fromIsoDate(r['data'] as String),
              (r['realizado'] as num).toDouble()
            ))
        .toList();
  }

  Future<List<RecordView>> records() async {
    final rows = await db.rawQuery('''
SELECT r.*, e.id AS e_id, e.nome AS e_nome, e.unidade AS e_unidade,
       e.grupo AS e_grupo, e.ativo AS e_ativo, e.ordem AS e_ordem
FROM recorde r JOIN exercicio e ON e.id = r.exercicio_id
ORDER BY r.data DESC, r.id DESC''');
    return rows
        .map((r) => RecordView(
              record: PersonalRecord(
                id: r['id'] as int,
                exerciseId: r['exercicio_id'] as int,
                value: (r['valor'] as num).toDouble(),
                date: fromIsoDate(r['data'] as String),
                goalId: r['meta_id'] as int?,
              ),
              exercise: _exerciseFromPrefixed(r),
            ))
        .toList();
  }

  /// Metas (com exercício) entre [from] e [to], inclusive.
  Future<List<StatementGoal>> statementGoals(
      DateTime from, DateTime to) async {
    final rows = await db.rawQuery('''
SELECT d.data, m.alvo, m.realizado, e.id AS eid, e.nome, e.unidade
FROM meta m JOIN treino_dia d ON d.id = m.treino_dia_id
JOIN exercicio e ON e.id = m.exercicio_id
WHERE d.data BETWEEN ? AND ?''', [toIsoDate(from), toIsoDate(to)]);
    return rows
        .map((r) => StatementGoal(
              date: fromIsoDate(r['data'] as String),
              exerciseId: r['eid'] as int,
              exerciseName: r['nome'] as String,
              unit: ExerciseUnit.fromDb(r['unidade'] as String),
              target: (r['alvo'] as num).toDouble(),
              done: (r['realizado'] as num?)?.toDouble(),
            ))
        .toList();
  }

  /// Primeiro dia com qualquer dado de treino, cardio ou avaliação.
  Future<DateTime?> firstDataDay() async {
    final rows = await db.rawQuery('''
SELECT MIN(x) AS m FROM (
  SELECT MIN(d.data) AS x FROM treino_dia d
  WHERE d.descanso = 1 OR EXISTS (SELECT 1 FROM meta m WHERE m.treino_dia_id = d.id)
     OR EXISTS (SELECT 1 FROM cardio c WHERE c.treino_dia_id = d.id)
  UNION ALL SELECT MIN(data) FROM avaliacao_corporal)''');
    final v = rows.first['m'] as String?;
    return v == null ? null : fromIsoDate(v);
  }

  Exercise _exerciseFromPrefixed(Map<String, Object?> r) => exerciseFromRow({
        'id': r['e_id'],
        'nome': r['e_nome'],
        'unidade': r['e_unidade'],
        'grupo': r['e_grupo'],
        'ativo': r['e_ativo'],
        'ordem': r['e_ordem'],
      });
}

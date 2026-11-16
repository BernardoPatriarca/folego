// Extrato semanal (seção 6.5): o "extrato bancário" do treino.
import 'compliance.dart';
import 'dates.dart';
import 'models.dart';

/// Meta já com a data e a unidade, para o cálculo do extrato.
class StatementGoal {
  const StatementGoal({
    required this.date,
    required this.exerciseId,
    required this.exerciseName,
    required this.unit,
    required this.target,
    this.done,
  });

  final DateTime date;
  final int exerciseId;
  final String exerciseName;
  final ExerciseUnit unit;
  final double target;
  final double? done;
}

class StatementCardio {
  const StatementCardio({
    required this.date,
    required this.minutes,
    this.kcal,
    this.distanceKm,
  });

  final DateTime date;
  final double minutes;
  final double? kcal;
  final double? distanceKm;
}

class StatementRecord {
  const StatementRecord({
    required this.date,
    required this.exerciseName,
    required this.unit,
    required this.value,
  });

  final DateTime date;
  final String exerciseName;
  final ExerciseUnit unit;
  final double value;
}

class StatementBodyPoint {
  const StatementBodyPoint({
    required this.date,
    this.id = 0,
    this.weightKg,
    this.fatPct,
  });

  final DateTime date;
  final int id;
  final double? weightKg;
  final double? fatPct;
}

/// Linha por exercício do extrato.
class ExerciseLine {
  const ExerciseLine({
    required this.name,
    required this.unit,
    required this.planned,
    required this.done,
  });

  final String name;
  final ExerciseUnit unit;
  final double planned;
  final double done;
}

class WeeklyStatement {
  const WeeklyStatement({
    required this.start,
    required this.end,
    required this.plannedReps,
    required this.doneReps,
    required this.plannedSeconds,
    required this.doneSeconds,
    required this.compliance,
    required this.cardioMinutes,
    required this.cardioGoalMinutes,
    required this.kcal,
    required this.distanceKm,
    required this.records,
    required this.activeDays,
    required this.restDays,
    required this.exercises,
    this.weightChange,
    this.fatChange,
    this.lastWeight,
    this.lastFat,
  });

  final DateTime start;
  final DateTime end;

  /// Totais separados por unidade (não faz sentido somar reps com segundos).
  final double plannedReps;
  final double doneReps;
  final double plannedSeconds;
  final double doneSeconds;

  /// Média do cumprimento das metas lançadas na semana; `null` se nenhuma.
  final double? compliance;
  final double cardioMinutes;
  final int cardioGoalMinutes;
  final double kcal;
  final double distanceKm;
  final List<StatementRecord> records;
  final int activeDays;
  final int restDays;
  final List<ExerciseLine> exercises;

  /// Variação da última avaliação da semana contra a anterior a ela.
  final double? weightChange;
  final double? fatChange;
  final double? lastWeight;
  final double? lastFat;

  double get cardioProgress =>
      cardioGoalMinutes <= 0 ? 1 : cardioMinutes / cardioGoalMinutes;

  bool get isEmpty =>
      exercises.isEmpty &&
      cardioMinutes == 0 &&
      activeDays == 0 &&
      lastWeight == null &&
      lastFat == null;
}

/// Monta o extrato da semana que começa em [start] (7 dias).
///
/// As listas podem conter dados de fora da semana: são filtradas aqui.
/// [bodyPoints] precisa conter também avaliações anteriores à semana, para
/// calcular a variação corporal.
WeeklyStatement buildWeeklyStatement({
  required DateTime start,
  required List<StatementGoal> goals,
  required List<StatementCardio> cardio,
  required List<StatementRecord> records,
  required Set<DateTime> restDays,
  required List<StatementBodyPoint> bodyPoints,
  required int cardioGoalMinutes,
}) {
  final from = dateOnly(start);
  final to = addDays(from, 6);
  bool inWeek(DateTime d) {
    final x = dateOnly(d);
    return !x.isBefore(from) && !x.isAfter(to);
  }

  final weekGoals = goals.where((g) => inWeek(g.date)).toList();
  final weekCardio = cardio.where((c) => inWeek(c.date)).toList();
  final weekRest = restDays.where(inWeek).map(dateOnly).toSet();

  double plannedReps = 0, doneReps = 0, plannedSec = 0, doneSec = 0;
  final lines = <int, ExerciseLine>{};
  for (final g in weekGoals) {
    final done = g.done ?? 0;
    if (g.unit == ExerciseUnit.reps) {
      plannedReps += g.target;
      doneReps += done;
    } else {
      plannedSec += g.target;
      doneSec += done;
    }
    final prev = lines[g.exerciseId];
    lines[g.exerciseId] = ExerciseLine(
      name: g.exerciseName,
      unit: g.unit,
      planned: (prev?.planned ?? 0) + g.target,
      done: (prev?.done ?? 0) + done,
    );
  }

  final compliance = dayCompliance(
      weekGoals.map((g) => (done: g.done, target: g.target)));

  final active = <DateTime>{
    ...weekRest,
    for (final g in weekGoals)
      if (g.done != null) dateOnly(g.date),
    for (final c in weekCardio) dateOnly(c.date),
  };

  // Variação corporal: última avaliação da semana × última antes dela.
  final sortedBody = [...bodyPoints]..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final weekBody = sortedBody.where((p) => inWeek(p.date)).toList();
  double? weightChange, fatChange, lastWeight, lastFat;
  if (weekBody.isNotEmpty) {
    final last = weekBody.last;
    final before = sortedBody.sublist(0, sortedBody.indexOf(last));
    lastWeight = last.weightKg;
    lastFat = last.fatPct;
    final prevWeight = before.reversed
        .map((p) => p.weightKg)
        .firstWhere((v) => v != null, orElse: () => null);
    final prevFat = before.reversed
        .map((p) => p.fatPct)
        .firstWhere((v) => v != null, orElse: () => null);
    if (lastWeight != null && prevWeight != null) {
      weightChange = lastWeight - prevWeight;
    }
    if (lastFat != null && prevFat != null) fatChange = lastFat - prevFat;
  }

  final weekRecords = records.where((r) => inWeek(r.date)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return WeeklyStatement(
    start: from,
    end: to,
    plannedReps: plannedReps,
    doneReps: doneReps,
    plannedSeconds: plannedSec,
    doneSeconds: doneSec,
    compliance: compliance,
    cardioMinutes: weekCardio.fold(0.0, (s, c) => s + c.minutes),
    cardioGoalMinutes: cardioGoalMinutes,
    kcal: weekCardio.fold(0.0, (s, c) => s + (c.kcal ?? 0)),
    distanceKm: weekCardio.fold(0.0, (s, c) => s + (c.distanceKm ?? 0)),
    records: weekRecords,
    activeDays: active.length,
    restDays: weekRest.length,
    exercises: lines.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
    weightChange: weightChange,
    fatChange: fatChange,
    lastWeight: lastWeight,
    lastFat: lastFat,
  );
}

/// Semanas fechadas (já terminadas antes de [today]) desde [firstDataDay],
/// da mais recente para a mais antiga.
List<DateTime> closedWeeks({
  required DateTime? firstDataDay,
  required DateTime today,
  bool startsOnSunday = false,
}) {
  if (firstDataDay == null) return const [];
  final current = weekStart(today, startsOnSunday: startsOnSunday);
  var cursor = weekStart(firstDataDay, startsOnSunday: startsOnSunday);
  final weeks = <DateTime>[];
  while (cursor.isBefore(current)) {
    weeks.add(cursor);
    cursor = addDays(cursor, 7);
  }
  return weeks.reversed.toList();
}

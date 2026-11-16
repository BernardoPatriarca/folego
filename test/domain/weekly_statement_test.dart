import 'package:flutter_test/flutter_test.dart';
import 'package:folego/domain/models.dart';
import 'package:folego/domain/weekly_statement.dart';

void main() {
  final monday = DateTime(2026, 11, 9);

  StatementGoal g(int day, String name, ExerciseUnit u, double target,
          [double? done]) =>
      StatementGoal(
          date: DateTime(2026, 11, day),
          exerciseId: name.hashCode,
          exerciseName: name,
          unit: u,
          target: target,
          done: done);

  test('totais, cumprimento, cardio, dias e recordes da semana', () {
    final s = buildWeeklyStatement(
      start: monday,
      goals: [
        g(9, 'Flexão', ExerciseUnit.reps, 30, 30), // 100%
        g(10, 'Flexão', ExerciseUnit.reps, 30, 15), // 50%
        g(10, 'Prancha', ExerciseUnit.seconds, 60, 90), // 100% (passou)
        g(11, 'Agachamento', ExerciseUnit.reps, 40), // não lançada
        g(16, 'Flexão', ExerciseUnit.reps, 99, 99), // fora da semana
      ],
      cardio: [
        StatementCardio(
            date: DateTime(2026, 11, 12), minutes: 30, kcal: 300, distanceKm: 5),
        StatementCardio(date: DateTime(2026, 11, 14), minutes: 45),
        StatementCardio(date: DateTime(2026, 11, 8), minutes: 99), // fora
      ],
      records: [
        StatementRecord(
            date: DateTime(2026, 11, 10),
            exerciseName: 'Prancha',
            unit: ExerciseUnit.seconds,
            value: 90),
        StatementRecord(
            date: DateTime(2026, 11, 2),
            exerciseName: 'Flexão',
            unit: ExerciseUnit.reps,
            value: 40),
      ],
      restDays: {DateTime(2026, 11, 15), DateTime(2026, 11, 1)},
      bodyPoints: const [],
      cardioGoalMinutes: 150,
    );

    expect(s.end, DateTime(2026, 11, 15));
    expect(s.plannedReps, 100);
    expect(s.doneReps, 45);
    expect(s.plannedSeconds, 60);
    expect(s.doneSeconds, 90);
    expect(s.compliance, closeTo((1 + 0.5 + 1) / 3, 1e-9));
    expect(s.cardioMinutes, 75);
    expect(s.cardioProgress, closeTo(0.5, 1e-9));
    expect(s.kcal, 300);
    expect(s.distanceKm, 5);
    expect(s.records.map((r) => r.exerciseName), ['Prancha']);
    // Ativos: 9, 10 (metas), 12, 14 (cardio), 15 (descanso). O 11 não.
    expect(s.activeDays, 5);
    expect(s.restDays, 1);
    expect(s.exercises.map((e) => e.name),
        ['Agachamento', 'Flexão', 'Prancha']);
    final flexao = s.exercises.firstWhere((e) => e.name == 'Flexão');
    expect(flexao.planned, 60);
    expect(flexao.done, 45);
  });

  test('variação corporal: última da semana × última anterior', () {
    final s = buildWeeklyStatement(
      start: monday,
      goals: const [],
      cardio: const [],
      records: const [],
      restDays: const {},
      cardioGoalMinutes: 150,
      bodyPoints: [
        StatementBodyPoint(
            date: DateTime(2026, 10, 1), id: 1, weightKg: 82, fatPct: 22),
        StatementBodyPoint(date: DateTime(2026, 11, 2), id: 2, weightKg: 80),
        StatementBodyPoint(
            date: DateTime(2026, 11, 10), id: 3, weightKg: 79.5, fatPct: 21),
        StatementBodyPoint(
            date: DateTime(2026, 11, 13), id: 4, weightKg: 79.2, fatPct: 20.5),
        StatementBodyPoint(date: DateTime(2026, 11, 20), id: 5, weightKg: 70),
      ],
    );
    expect(s.lastWeight, 79.2);
    // Anterior à última da semana é a de 10/11 (79,5).
    expect(s.weightChange, closeTo(-0.3, 1e-9));
    expect(s.fatChange, closeTo(-0.5, 1e-9));
  });

  test('semana sem avaliação não tem variação corporal', () {
    final s = buildWeeklyStatement(
      start: monday,
      goals: const [],
      cardio: const [],
      records: const [],
      restDays: const {},
      cardioGoalMinutes: 150,
      bodyPoints: [
        StatementBodyPoint(date: DateTime(2026, 11, 2), weightKg: 80),
      ],
    );
    expect(s.weightChange, isNull);
    expect(s.compliance, isNull);
    expect(s.isEmpty, isTrue);
  });

  test('semanas fechadas', () {
    final weeks = closedWeeks(
        firstDataDay: DateTime(2026, 10, 28), today: DateTime(2026, 11, 18));
    // Semana atual (16/11) ainda está aberta.
    expect(weeks, [
      DateTime(2026, 11, 9),
      DateTime(2026, 11, 2),
      DateTime(2026, 10, 26),
    ]);
    expect(closedWeeks(firstDataDay: null, today: DateTime(2026, 11, 18)),
        isEmpty);
    final sunday = closedWeeks(
        firstDataDay: DateTime(2026, 11, 9),
        today: DateTime(2026, 11, 18),
        startsOnSunday: true);
    expect(sunday, [DateTime(2026, 11, 8)]);
  });
}

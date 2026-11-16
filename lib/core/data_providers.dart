// Providers de leitura usados por várias telas. Todos observam a revisão de
// dados, então qualquer escrita (bumpData) recarrega o que estiver na tela.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dates.dart';
import '../domain/golden_rule.dart';
import '../domain/models.dart';
import '../domain/streak.dart';
import '../features/today/workout_repository.dart';
import 'providers.dart';

/// "Hoje" sem hora. Recalcula a cada revisão (e ao voltar ao app).
final todayProvider = Provider<DateTime>((ref) {
  ref.watch(dataRevisionProvider);
  return dateOnly(ref.watch(clockProvider)());
});

final goldenRuleProvider = FutureProvider<GoldenRuleConfig>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(configRepositoryProvider).goldenRule();
});

final weekStartsOnSundayProvider = FutureProvider<bool>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(configRepositoryProvider).weekStartsOnSunday();
});

final cardioWeeklyGoalProvider = FutureProvider<int>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(configRepositoryProvider).cardioWeeklyGoal();
});

final profileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(configRepositoryProvider).profile();
});

final exercisesProvider = FutureProvider<List<Exercise>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(catalogRepositoryProvider).exercises();
});

final activeExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final all = await ref.watch(exercisesProvider.future);
  return all.where((e) => e.active).toList();
});

final measureTypesProvider = FutureProvider<List<MeasureType>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(catalogRepositoryProvider).measureTypes();
});

final dayProvider = FutureProvider.family<WorkoutDay?, DateTime>((ref, date) {
  ref.watch(dataRevisionProvider);
  return ref.watch(workoutRepositoryProvider).day(date);
});

final goalsForDateProvider =
    FutureProvider.family<List<GoalView>, DateTime>((ref, date) {
  ref.watch(dataRevisionProvider);
  return ref.watch(workoutRepositoryProvider).goalsForDate(date);
});

final cardioForDateProvider =
    FutureProvider.family<List<CardioView>, DateTime>((ref, date) {
  ref.watch(dataRevisionProvider);
  return ref.watch(cardioRepositoryProvider).forDate(date);
});

/// Meta sugerida pela regra de ouro para (exercício, dia).
final suggestionProvider =
    FutureProvider.family<int?, (int, DateTime)>((ref, key) async {
  ref.watch(dataRevisionProvider);
  final rule = await ref.watch(goldenRuleProvider.future);
  final repo = ref.watch(catalogRepositoryProvider);
  final exercise = await repo.exercise(key.$1);
  if (exercise == null) return null;
  return ref.watch(workoutRepositoryProvider).suggestion(exercise, key.$2, rule);
});

final streakProvider = FutureProvider<int>((ref) async {
  ref.watch(dataRevisionProvider);
  final days = await ref.watch(workoutRepositoryProvider).activeDays();
  return currentStreak(days, ref.watch(todayProvider));
});

final recordsProvider = FutureProvider<List<RecordView>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(workoutRepositoryProvider).records();
});

final assessmentsProvider = FutureProvider<List<BodyAssessment>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(bodyRepositoryProvider).assessments();
});

final bodyGoalsProvider = FutureProvider<List<BodyGoal>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(bodyRepositoryProvider).goals();
});

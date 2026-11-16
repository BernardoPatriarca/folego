// Extrato semanal: lista de semanas fechadas e detalhe de cada uma.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/dates.dart';
import '../../domain/weekly_statement.dart';

final closedWeeksProvider = FutureProvider<List<DateTime>>((ref) async {
  ref.watch(dataRevisionProvider);
  final first = await ref.watch(workoutRepositoryProvider).firstDataDay();
  final sunday = await ref.watch(weekStartsOnSundayProvider.future);
  return closedWeeks(
      firstDataDay: first,
      today: ref.watch(todayProvider),
      startsOnSunday: sunday);
});

final weeklyStatementProvider =
    FutureProvider.family<WeeklyStatement, DateTime>((ref, start) async {
  ref.watch(dataRevisionProvider);
  final end = addDays(start, 6);
  final workouts = ref.watch(workoutRepositoryProvider);
  final goals = await workouts.statementGoals(start, end);
  final cardio =
      await ref.watch(cardioRepositoryProvider).statementCardio(start, end);
  final records = (await ref.watch(recordsProvider.future))
      .map((r) => StatementRecord(
          date: r.record.date,
          exerciseName: r.exercise.name,
          unit: r.exercise.unit,
          value: r.record.value))
      .toList();
  final rest = await workouts.restDays();
  final assessments = await ref.watch(assessmentsProvider.future);
  final goal = await ref.watch(cardioWeeklyGoalProvider.future);
  return buildWeeklyStatement(
    start: start,
    goals: goals,
    cardio: cardio,
    records: records,
    restDays: rest,
    cardioGoalMinutes: goal,
    bodyPoints: [
      for (final a in assessments)
        StatementBodyPoint(
            date: a.date,
            id: a.id ?? 0,
            weightKg: a['peso_kg'],
            fatPct: a['gordura_pct']),
    ],
  );
});

class StatementListPage extends ConsumerWidget {
  const StatementListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = ref.watch(closedWeeksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('EXTRATO SEMANAL')),
      body: weeks.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Nenhuma semana fechada ainda. O extrato aparece '
                    'quando uma semana com lançamentos termina.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _WeekTile(start: list[i]),
              ),
      ),
    );
  }
}

class _WeekTile extends ConsumerWidget {
  const _WeekTile({required this.start});
  final DateTime start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(weeklyStatementProvider(start)).value;
    final end = addDays(start, 6);
    final title = '${fmtDateShort(start)} a ${fmtDate(end)}';
    return AppCard(
      onTap: () => context.push('/extrato/${toIsoDate(start)}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  s == null
                      ? '…'
                      : s.isEmpty
                          ? 'Semana sem lançamentos'
                          : [
                              '${s.activeDays} dias ativos',
                              fmtMinutes(s.cardioMinutes),
                              if (s.records.isNotEmpty)
                                '${s.records.length} ${s.records.length == 1 ? 'recorde' : 'recordes'}',
                            ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(s?.compliance == null ? '–' : fmtPct(s!.compliance),
              style: numberStyle(22, color: FolegoColors.lime)),
          const Icon(Icons.chevron_right, color: FolegoColors.textSecondary),
        ],
      ),
    );
  }
}

class StatementDetailPage extends ConsumerWidget {
  const StatementDetailPage({super.key, required this.start});
  final DateTime start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyStatementProvider(start));
    return Scaffold(
      appBar: AppBar(
          title: Text('SEMANA ${fmtDateShort(start)}–${fmtDateShort(addDays(start, 6))}')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Line('Cumprimento médio',
                s.compliance == null ? '–' : fmtPct(s.compliance),
                big: true),
            const SectionTitle('Treino'),
            AppCard(
              child: Column(children: [
                _Line('Dias ativos', '${s.activeDays} de 7'),
                _Line('Dias de descanso', '${s.restDays}'),
                if (s.plannedReps > 0 || s.doneReps > 0)
                  _Line('Repetições',
                      '${fmtNum(s.doneReps, decimals: 0)} / ${fmtNum(s.plannedReps, decimals: 0)}'),
                if (s.plannedSeconds > 0 || s.doneSeconds > 0)
                  _Line('Isometria (s)',
                      '${fmtNum(s.doneSeconds, decimals: 0)} / ${fmtNum(s.plannedSeconds, decimals: 0)}'),
              ]),
            ),
            if (s.exercises.isNotEmpty) ...[
              const SectionTitle('Por exercício · realizado / planejado'),
              AppCard(
                child: Column(children: [
                  for (final e in s.exercises)
                    _Line(e.name,
                        '${fmtNum(e.done, decimals: 0)} / ${fmtExercise(e.planned, e.unit)}'),
                ]),
              ),
            ],
            const SectionTitle('Cardio'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Line('Minutos',
                      '${fmtNum(s.cardioMinutes, decimals: 0)} / ${s.cardioGoalMinutes}'),
                  const SizedBox(height: 4),
                  ProgressBar(s.cardioProgress),
                  const SizedBox(height: 4),
                  Text(
                    s.cardioProgress >= 1
                        ? 'Meta semanal de cardio cumprida.'
                        : 'Faltaram ${fmtNum(s.cardioGoalMinutes - s.cardioMinutes, decimals: 0)} min para a meta.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (s.kcal > 0) _Line('Calorias', '${fmtNum(s.kcal, decimals: 0)} kcal'),
                  if (s.distanceKm > 0)
                    _Line('Distância', '${fmtNum(s.distanceKm, decimals: 2)} km'),
                ],
              ),
            ),
            const SectionTitle('Recordes da semana'),
            if (s.records.isEmpty)
              const Text('Nenhum recorde nesta semana.',
                  style: TextStyle(color: FolegoColors.textSecondary))
            else
              AppCard(
                child: Column(children: [
                  for (final r in s.records)
                    _Line('${r.exerciseName} · ${fmtDateShort(r.date)}',
                        fmtExercise(r.value, r.unit)),
                ]),
              ),
            const SectionTitle('Corpo'),
            if (s.lastWeight == null && s.lastFat == null)
              const Text('Nenhuma avaliação nesta semana.',
                  style: TextStyle(color: FolegoColors.textSecondary))
            else
              AppCard(
                child: Column(children: [
                  if (s.lastWeight != null)
                    _Line(
                        'Peso',
                        '${fmtNum(s.lastWeight)} kg'
                        '${s.weightChange == null ? '' : ' (${fmtSigned(s.weightChange!)})'}'),
                  if (s.lastFat != null)
                    _Line(
                        'Gordura',
                        '${fmtNum(s.lastFat)}%'
                        '${s.fatChange == null ? '' : ' (${fmtSigned(s.fatChange!)})'}'),
                ]),
              ),
            const SizedBox(height: 8),
            Text('Variação contra a avaliação anterior.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.big = false});
  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: big ? Theme.of(context).textTheme.titleMedium : null)),
            const SizedBox(width: 8),
            Text(value,
                style: numberStyle(big ? 32 : 16,
                    color: big ? FolegoColors.lime : FolegoColors.text)),
          ],
        ),
      ),
    );
  }
}

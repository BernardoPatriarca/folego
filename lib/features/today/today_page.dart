// Aba Hoje: plano do dia, progresso, sequência e cardio.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/compliance.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../cardio/cardio_card.dart';
import '../logging/log_request.dart';
import 'goal_sheet.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final goalsAsync = ref.watch(goalsForDateProvider(today));
    final day = ref.watch(dayProvider(today)).value;
    final streak = ref.watch(streakProvider).value ?? 0;
    final profile = ref.watch(profileProvider).value;
    final goals = goalsAsync.value ?? const <GoalView>[];
    final compliance = dayCompliance(
        goals.map((g) => (done: g.goal.done, target: g.goal.target)));
    final rest = day?.rest ?? false;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.bumpData(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList.list(children: [
                  Text(capitalize(fmtDateLong(today)),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: FolegoColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    profile == null
                        ? 'HOJE'
                        : 'BORA, ${profile.name.split(' ').first.toUpperCase()}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  _Header(streak: streak, compliance: compliance, goals: goals),
                  if (rest) ...[
                    const SizedBox(height: 12),
                    _RestBanner(onUndo: () async {
                      await ref
                          .read(workoutRepositoryProvider)
                          .setRest(today, false);
                      ref.bumpData();
                    }),
                  ],
                  SectionTitle('Metas do dia',
                      trailing: goals.isEmpty
                          ? null
                          : Text(
                              '${goals.where((g) => g.goal.isLogged).length}/${goals.length} lançadas',
                              style: Theme.of(context).textTheme.bodySmall)),
                ]),
              ),
              if (goalsAsync.isLoading && !goalsAsync.hasValue)
                const SliverToBoxAdapter(child: LoadingView())
              else if (goals.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.flag_outlined,
                    message: rest
                        ? 'Dia de descanso. Recuperar também é treino.'
                        : 'Nenhuma meta para hoje. Planeje agora: '
                            'o app sugere a meta pela regra de ouro.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: goals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _GoalTile(goals[i]),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverList.list(children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar exercício'),
                    onPressed: () => showGoalSheet(context, date: today),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_all_outlined, size: 18),
                          label: const Text('Copiar plano de ontem'),
                          onPressed: () => _copyYesterday(context, ref, today),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.bedtime_outlined, size: 18),
                          label: Text(rest ? 'Descansando' : 'Dia de descanso'),
                          onPressed: rest
                              ? null
                              : () async {
                                  await ref
                                      .read(workoutRepositoryProvider)
                                      .setRest(today, true);
                                  ref.bumpData();
                                  if (context.mounted) {
                                    showMessage(context,
                                        'Dia de descanso marcado. A sequência continua.',
                                        icon: Icons.bedtime);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                  const SectionTitle('Cardio do dia'),
                  CardioDayCard(date: today),
                  const SizedBox(height: 24),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyYesterday(
      BuildContext context, WidgetRef ref, DateTime today) async {
    final rule = await ref.read(goldenRuleProvider.future);
    final n = await ref
        .read(workoutRepositoryProvider)
        .copyPlan(addDays(today, -1), today, rule);
    ref.bumpData();
    if (!context.mounted) return;
    showMessage(
        context,
        n == 0
            ? 'Nada para copiar: ontem não teve plano (ou já está tudo aqui).'
            : n == 1
                ? '1 meta copiada de ontem.'
                : '$n metas copiadas de ontem.',
        icon: Icons.copy_all);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.streak,
    required this.compliance,
    required this.goals,
  });

  final int streak;
  final double? compliance;
  final List<GoalView> goals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: BigStat(
              label: 'Sequência',
              value: '$streak',
              unit: streak == 1 ? 'dia' : 'dias',
              semanticsLabel:
                  'Sequência atual, $streak ${streak == 1 ? 'dia' : 'dias'} ativos',
            ),
          ),
          Container(width: 1, height: 56, color: FolegoColors.border),
          const SizedBox(width: 16),
          Expanded(
            child: BigStat(
              label: 'Cumprimento',
              value: compliance == null ? '–' : fmtPct(compliance),
              color: FolegoColors.lime,
              semanticsLabel: compliance == null
                  ? 'Cumprimento do dia: nada lançado ainda'
                  : 'Cumprimento do dia, ${fmtPct(compliance)}',
              footer: compliance == null
                  ? Text(goals.isEmpty ? 'sem plano' : 'nada lançado',
                      style: Theme.of(context).textTheme.bodySmall)
                  : ProgressBar(compliance!, height: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.onUndo});
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.bedtime, color: FolegoColors.lime),
          const SizedBox(width: 12),
          const Expanded(child: Text('Dia de descanso planejado.')),
          TextButton(onPressed: onUndo, child: const Text('Desmarcar')),
        ],
      ),
    );
  }
}

class _GoalTile extends ConsumerWidget {
  const _GoalTile(this.view);
  final GoalView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = view.goal;
    final e = view.exercise;
    final done = g.done ?? 0;
    final c = goalCompliance(g.done, g.target) ?? 0;
    final t = Theme.of(context).textTheme;
    final label = '${e.name}: ${fmtNum(done, decimals: 0)} de '
        '${fmtExercise(g.target, e.unit)}'
        '${g.bold ? ', meta ousada' : ''}'
        '${g.isLogged ? ', lançado' : ', não lançado'}';

    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: AppCard(
        onTap: () {
          ref.read(logRequestProvider.notifier).request(
              LogRequest(exerciseId: e.id, date: view.date));
          context.go('/lancar');
        },
        onLongPress: () => _menu(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(e.name, style: t.titleMedium),
                          if (g.bold) const BoldTag(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: g.isLogged ? fmtNum(done, decimals: 0) : '–',
                            style: numberStyle(26,
                                color: c >= 1
                                    ? FolegoColors.lime
                                    : FolegoColors.text)),
                        TextSpan(
                            text: ' / ${fmtExercise(g.target, e.unit)}',
                            style: numberStyle(16,
                                color: FolegoColors.textSecondary,
                                weight: FontWeight.w400)),
                      ])),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Opções',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _menu(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProgressBar(c),
            const SizedBox(height: 6),
            Text(
              [
                if (g.sets != null) '${g.sets} séries',
                if (g.effort != null) 'esforço ${g.effort}/10',
                if (!g.isLogged) 'toque para lançar',
                if (c >= 1) 'meta cumprida',
              ].join(' · '),
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar meta'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            if (view.goal.isLogged)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Desfazer lançamento'),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remover do plano'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final repo = ref.read(workoutRepositoryProvider);
    switch (action) {
      case 'edit':
        await showGoalSheet(context, date: view.date, existing: view);
      case 'clear':
        final ok = await confirmDialog(context,
            title: 'Desfazer lançamento?',
            message: 'O realizado de ${view.exercise.name} volta a ficar em '
                'branco. A meta continua no plano.',
            confirmLabel: 'Desfazer');
        if (!ok) return;
        await repo.clearDone(view.goal.id!);
        ref.bumpData();
      case 'delete':
        final ok = await confirmDialog(context,
            title: 'Remover ${view.exercise.name}?',
            message: 'A meta e o lançamento deste dia serão apagados.');
        if (!ok) return;
        final snapshot = await repo.deleteGoal(view.goal.id!);
        ref.bumpData();
        if (context.mounted) {
          showUndoSnack(context, '${view.exercise.name} removido do plano.',
              () async {
            await repo.restoreGoal(snapshot);
            ref.bumpData();
          });
        }
    }
  }
}

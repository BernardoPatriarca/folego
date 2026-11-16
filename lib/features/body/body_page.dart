// Aba Corpo: resumo da última avaliação, metas corporais e histórico.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/body.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import 'metric_info.dart';

class BodyPage extends ConsumerWidget {
  const BodyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(assessmentsProvider);
    final profile = ref.watch(profileProvider).value;
    final types = ref.watch(measureTypesProvider).value ?? const [];
    final goals = (ref.watch(bodyGoalsProvider).value ?? const [])
        .where((g) => g.active)
        .toList();
    final list = async.value ?? const <BodyAssessment>[];
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CORPO'),
        actions: [
          if (list.length >= 2)
            IconButton(
              tooltip: 'Comparar avaliações',
              icon: const Icon(Icons.compare_arrows),
              onPressed: () => context.push('/comparar'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FolegoColors.lime,
        foregroundColor: FolegoColors.onLime,
        icon: const Icon(Icons.add),
        label: const Text('Nova avaliação'),
        onPressed: () => context.push('/avaliacao/nova'),
      ),
      body: SafeArea(
        child: async.isLoading && !async.hasValue
            ? const LoadingView()
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverList.list(children: [
                      if (profile != null) _ProfileLine(profile, today),
                      if (list.isEmpty)
                        EmptyState(
                          icon: Icons.accessibility_new,
                          message: 'Nenhuma avaliação ainda. '
                              'Que tal lançar a primeira?',
                          actionLabel: 'Importar histórico (CSV)',
                          onAction: () => context.push('/mais/backup'),
                        )
                      else ...[
                        _Summary(list: list, profile: profile, types: types),
                        const HealthDisclaimer(),
                      ],
                      SectionTitle('Metas corporais',
                          trailing: TextButton(
                            onPressed: () => context.push('/mais/metas-corporais'),
                            child: const Text('Gerenciar'),
                          )),
                      if (goals.isEmpty)
                        const Text(
                            'Sem metas. Ex.: peso 75 kg ou gordura 15%.',
                            style: TextStyle(color: FolegoColors.textSecondary))
                      else
                        for (final g in goals)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: BodyGoalCard(
                                goal: g,
                                assessments: list,
                                profile: profile,
                                types: types),
                          ),
                      if (list.isNotEmpty)
                        SectionTitle('Histórico (${list.length})'),
                    ]),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _HistoryTile(
                          a: list[i], all: list, profile: profile),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine(this.p, this.today);
  final Profile p;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final parts = [
      p.name,
      if (p.birthDate != null) '${ageOn(p.birthDate!, today)} anos',
      if (p.heightCm != null) '${fmtNum(p.heightCm, decimals: 0)} cm',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(parts.join(' · '),
          style: const TextStyle(color: FolegoColors.textSecondary)),
    );
  }
}

/// Resumo da avaliação mais recente com variação contra a anterior.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.list,
    required this.profile,
    required this.types,
  });

  final List<BodyAssessment> list;
  final Profile? profile;
  final List<MeasureType> types;

  @override
  Widget build(BuildContext context) {
    final last = list.first;
    final tiles = <Widget>[];
    for (final key in const [
      'peso_kg',
      'imc',
      'gordura_pct',
      'massa_muscular_pct',
      'residuos_pct',
      'massa_muscular_kg',
      'agua_pct',
      'gordura_visceral',
      'tmb_kcal',
      'massa_gorda_kg',
    ]) {
      final v = metricValue(last, key, profile);
      if (v == null) continue;
      final info = metricInfo(key, types);
      final prev = previousValue(list, last, key, profile);
      final delta = variation(v, prev);
      String? extra;
      if (key == 'imc') extra = bmiCategory(v).label;
      final semantics = StringBuffer(
          '${info.label}, ${fmtNum(v, decimals: info.decimals)} ${_spoken(info.unit)}');
      if (delta != null) {
        semantics.write(', ${delta < 0 ? 'menos' : 'mais'} '
            '${fmtNum(delta.abs(), decimals: info.decimals)} desde a última avaliação');
      }
      if (extra != null) semantics.write(', $extra');
      tiles.add(AppCard(
        padding: const EdgeInsets.all(14),
        child: BigStat(
          label: info.label,
          value: fmtNum(v, decimals: info.decimals),
          unit: info.unit,
          size: 26,
          semanticsLabel: semantics.toString(),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (extra != null)
                Text(extra,
                    style: const TextStyle(
                        fontSize: 12, color: FolegoColors.lime)),
              VariationText(
                  delta: delta,
                  unit: info.unit,
                  decimals: info.decimals,
                  suffix: ' vs anterior'),
            ],
          ),
        ),
      ));
    }

    // Relações de cintura, se houver as medidas.
    int? idOf(String name) =>
        types.where((t) => t.name == name).firstOrNull?.id;
    final waist = last.measures[idOf('Cintura')];
    final hip = last.measures[idOf('Quadril')];
    final whr = waistHipRatio(waist, hip);
    final wht = waistHeightRatio(waist, effectiveHeight(last, profile));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Última avaliação · ${fmtDate(last.date)}',
            trailing: TextButton(
                onPressed: () => context.push('/avaliacao/${last.id}'),
                child: const Text('Detalhes'))),
        if (tiles.isEmpty)
          const Text('A última avaliação só tem medidas.',
              style: TextStyle(color: FolegoColors.textSecondary))
        else
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 520 ? 3 : 2;
            final w = (c.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          }),
        if (whr != null || wht != null) ...[
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (whr != null)
                  Text('Relação cintura/quadril: ${fmtNum(whr, decimals: 2)}'),
                if (wht != null)
                  Text('Relação cintura/altura: ${fmtNum(wht, decimals: 2)}'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _spoken(String unit) => switch (unit) {
      'kg' => 'quilos',
      '%' => 'por cento',
      'cm' => 'centímetros',
      'kcal' => 'quilocalorias',
      _ => unit,
    };

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.a, required this.all, this.profile});
  final BodyAssessment a;
  final List<BodyAssessment> all;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final w = a['peso_kg'];
    final f = a['gordura_pct'];
    final parts = [
      if (w != null) '${fmtNum(w)} kg',
      if (f != null) '${fmtNum(f)}% gordura',
      if (a.measures.isNotEmpty) '${a.measures.length} medidas',
    ];
    final dw = variation(w, previousValue(all, a, 'peso_kg', profile));
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => context.push('/avaliacao/${a.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmtDate(a.date),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                    [
                      if (a.origin != null) capitalize(a.origin!),
                      ...parts,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          VariationText(delta: dw, unit: 'kg'),
          const Icon(Icons.chevron_right, color: FolegoColors.textSecondary),
        ],
      ),
    );
  }
}

/// Progresso de uma meta corporal: "78,0 → 75,0 kg · faltam 1,6 kg".
class BodyGoalCard extends StatelessWidget {
  const BodyGoalCard({
    super.key,
    required this.goal,
    required this.assessments,
    required this.profile,
    required this.types,
    this.trailing,
  });

  final BodyGoal goal;
  final List<BodyAssessment> assessments;
  final Profile? profile;
  final List<MeasureType> types;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final info = metricInfo(goal.metric, types);
    final first = firstValue(assessments, goal.metric, profile);
    double? current;
    for (final a in assessments) {
      current = metricValue(a, goal.metric, profile);
      if (current != null) break;
    }
    final u = info.unit.isEmpty ? '' : ' ${info.unit}';
    final d = info.decimals == 0 ? 0 : 1;
    String line;
    BodyGoalProgress? p;
    if (current == null || first == null) {
      line = 'Alvo ${fmtNum(goal.target, decimals: d, trim: false)}$u · '
          'sem avaliação com essa métrica';
    } else {
      p = bodyGoalProgress(
          start: first.value, current: current, target: goal.target);
      line = '${fmtNum(current, decimals: d, trim: false)} → '
          '${fmtNum(goal.target, decimals: d, trim: false)}$u · '
          '${p.reached ? 'meta atingida!' : 'faltam ${fmtNum(p.remaining, decimals: d, trim: false)}$u'}';
    }
    return AppCard(
      child: Semantics(
        label: 'Meta de ${info.label}: $line'
            '${goal.targetDate != null ? ', até ${fmtDate(goal.targetDate!)}' : ''}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(info.label,
                        style: Theme.of(context).textTheme.titleMedium)),
                if (goal.targetDate != null)
                  Text('até ${fmtDate(goal.targetDate!)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ?trailing,
              ],
            ),
            const SizedBox(height: 4),
            Text(line, style: const TextStyle(fontFeatures: tabular)),
            if (p != null) ...[
              const SizedBox(height: 8),
              ProgressBar(p.fraction),
            ],
          ],
        ),
      ),
    );
  }
}

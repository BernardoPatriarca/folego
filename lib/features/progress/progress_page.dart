// Aba Evolução: gráfico de qualquer métrica, cards do mês e linha do tempo
// de recordes (os "dividendos").
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/body.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../body/metric_info.dart';

/// Chave da métrica: `ex:<id>`, `cardio` ou `body:<métrica>`.
typedef MetricKey = String;

enum Period {
  w4('4 sem', 28),
  m3('3 meses', 91),
  m6('6 meses', 182),
  y1('1 ano', 365),
  all('Tudo', null);

  const Period(this.label, this.days);
  final String label;
  final int? days;
}

final progressSeriesProvider =
    FutureProvider.family<List<(DateTime, double)>, MetricKey>((ref, key) async {
  ref.watch(dataRevisionProvider);
  if (key.startsWith('ex:')) {
    return ref
        .watch(workoutRepositoryProvider)
        .exerciseSeries(int.parse(key.substring(3)));
  }
  if (key == 'cardio') {
    final sunday = await ref.watch(weekStartsOnSundayProvider.future);
    final all = await ref.watch(cardioRepositoryProvider).all();
    if (all.isEmpty) return const [];
    final byWeek = <DateTime, double>{};
    for (final c in all) {
      final w = weekStart(c.date, startsOnSunday: sunday);
      byWeek[w] = (byWeek[w] ?? 0) + c.session.durationMin;
    }
    // Semanas sem cardio entram como zero, até a semana atual.
    final out = <(DateTime, double)>[];
    var cursor = byWeek.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = weekStart(ref.watch(todayProvider), startsOnSunday: sunday);
    while (!cursor.isAfter(last)) {
      out.add((cursor, byWeek[cursor] ?? 0));
      cursor = addDays(cursor, 7);
    }
    return out;
  }
  final metric = key.substring(5);
  final list = await ref.watch(assessmentsProvider.future);
  final profile = await ref.watch(profileProvider.future);
  return [
    for (final a in list.reversed)
      if (metricValue(a, metric, profile) case final v?) (a.date, v),
  ];
});

/// Volume (reps e segundos) e recordes do mês atual e do anterior.
final monthCardsProvider = FutureProvider<
    ({
      double reps,
      double prevReps,
      double secs,
      double prevSecs,
      int records
    })>((ref) async {
  ref.watch(dataRevisionProvider);
  final today = ref.watch(todayProvider);
  final repo = ref.watch(workoutRepositoryProvider);
  final start = monthStart(today);
  final prevStart = DateTime(start.year, start.month - 1);
  final end = DateTime(start.year, start.month + 1, 0);
  final cur = await repo.statementGoals(start, end);
  final prev = await repo.statementGoals(prevStart, addDays(start, -1));
  double sum(List list, ExerciseUnit u) => list
      .where((g) => g.unit == u)
      .fold(0.0, (s, g) => s + (g.done ?? 0));
  final records = (await ref.watch(recordsProvider.future))
      .where((r) => !r.record.date.isBefore(start))
      .length;
  return (
    reps: sum(cur, ExerciseUnit.reps),
    prevReps: sum(prev, ExerciseUnit.reps),
    secs: sum(cur, ExerciseUnit.seconds),
    prevSecs: sum(prev, ExerciseUnit.seconds),
    records: records,
  );
});

class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  MetricKey? _metric;
  Period _period = Period.m3;

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).value ?? const [];
    final types = ref.watch(measureTypesProvider).value ?? const [];
    final options = <(MetricKey, String, String)>[
      for (final e in exercises.where((e) => e.active))
        ('ex:${e.id}', e.name, e.unit.short),
      ('cardio', 'Cardio (min/semana)', 'min'),
      for (final m in chartableMetrics(
          types.where((t) => t.active).toList()))
        ('body:${m.key}', m.label, m.unit),
    ];
    _metric ??= options.isEmpty ? null : options.first.$1;
    final selected = options.where((o) => o.$1 == _metric).firstOrNull ??
        (options.isEmpty ? null : options.first);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EVOLUÇÃO'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Extrato'),
            onPressed: () => context.push('/extrato'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (selected != null) ...[
              DropdownButtonFormField<MetricKey>(
                initialValue: selected.$1,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Métrica'),
                items: [
                  for (final o in options)
                    DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                ],
                onChanged: (v) => setState(() => _metric = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in Period.values)
                    ChoiceChip(
                      label: Text(p.label),
                      showCheckmark: false,
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _ChartCard(
                metric: selected.$1,
                label: selected.$2,
                unit: selected.$3,
                period: _period,
              ),
            ],
            const SectionTitle('Este mês'),
            const _MonthCards(),
            const SectionTitle('Recordes · os dividendos'),
            const _RecordsTimeline(),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends ConsumerWidget {
  const _ChartCard({
    required this.metric,
    required this.label,
    required this.unit,
    required this.period,
  });

  final MetricKey metric;
  final String label;
  final String unit;
  final Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(progressSeriesProvider(metric));
    final today = ref.watch(todayProvider);
    final all = async.value;
    if (all == null) {
      return const AppCard(child: SizedBox(height: 220, child: LoadingView()));
    }
    final from = period.days == null ? null : addDays(today, -period.days!);
    final data = [
      for (final p in all)
        if (from == null || !p.$1.isBefore(from)) p,
    ];
    if (data.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.show_chart,
          message: all.isEmpty
              ? 'Sem dados de $label ainda. Lance para ver a evolução.'
              : 'Sem dados de $label neste período.',
        ),
      );
    }
    final decimals = metric.startsWith('body:') ? 1 : 0;
    final first = data.first.$1;
    final spots = [
      for (final p in data)
        FlSpot(p.$1.difference(first).inDays.toDouble(), p.$2),
    ];
    final ys = data.map((p) => p.$2);
    var minY = ys.reduce((a, b) => a < b ? a : b);
    var maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).abs() * 0.15 + (maxY == minY ? 1 : 0);
    minY = (minY - pad).clamp(0, double.infinity).toDouble();
    maxY = maxY + pad;
    final spanX = spots.last.x;
    final last = data.last;
    final delta = data.length > 1 ? last.$2 - data.first.$2 : null;
    final u = unit.isEmpty ? '' : ' $unit';

    final semantics = 'Gráfico de $label, ${data.length} pontos, de '
        '${fmtDate(data.first.$1)} a ${fmtDate(last.$1)}. Último valor '
        '${fmtNum(last.$2, decimals: decimals)}$u'
        '${delta == null ? '' : ', variação no período ${fmtSigned(delta, decimals: decimals)}$u'}.';

    return AppCard(
      child: Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BigStat(
              label: 'Último · ${fmtDateShort(last.$1)}',
              value: fmtNum(last.$2, decimals: decimals),
              unit: unit,
              size: 30,
              footer: delta == null
                  ? null
                  : VariationText(
                      delta: delta,
                      unit: unit,
                      decimals: decimals,
                      suffix: ' no período'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: spanX == 0 ? 1 : spanX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                        color: FolegoColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                              fmtNum(v, decimals: maxY - minY < 10 ? 1 : 0),
                              style: _axis),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: spanX <= 0 ? 1 : (spanX / 3).ceilToDouble(),
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                              fmtDateShort(addDays(first, v.round())),
                              style: _axis),
                        ),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => FolegoColors.surfaceHigh,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${fmtDateShort(addDays(first, s.x.round()))}\n'
                            '${fmtNum(s.y, decimals: decimals)}$u',
                            const TextStyle(
                                color: FolegoColors.text,
                                fontFeatures: tabular),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: FolegoColors.lime,
                      barWidth: 3,
                      isCurved: spots.length > 2,
                      preventCurveOverShooting: true,
                      dotData: FlDotData(show: spots.length <= 30),
                      belowBarData: BarAreaData(
                        show: true,
                        color: FolegoColors.lime.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _axis = TextStyle(
    fontSize: 11, color: FolegoColors.textSecondary, fontFeatures: tabular);

class _MonthCards extends ConsumerWidget {
  const _MonthCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(monthCardsProvider).value;
    final streak = ref.watch(streakProvider).value ?? 0;
    if (m == null) return const LoadingView();

    Widget card(String label, String value, String unit, double? prev,
        double cur, String semantics) {
      final delta = prev == null ? null : cur - prev;
      return AppCard(
        padding: const EdgeInsets.all(14),
        child: BigStat(
          label: label,
          value: value,
          unit: unit,
          size: 26,
          semanticsLabel: semantics,
          footer: delta == null
              ? null
              : VariationText(
                  delta: delta, unit: '', decimals: 0, suffix: ' vs mês anterior'),
        ),
      );
    }

    final cards = [
      card('Volume (reps)', fmtNum(m.reps, decimals: 0), '', m.prevReps, m.reps,
          'Volume do mês, ${fmtNum(m.reps, decimals: 0)} repetições; mês anterior ${fmtNum(m.prevReps, decimals: 0)}'),
      card('Isometria', fmtNum(m.secs, decimals: 0), 's', m.prevSecs, m.secs,
          'Tempo de isometria no mês, ${fmtNum(m.secs, decimals: 0)} segundos; mês anterior ${fmtNum(m.prevSecs, decimals: 0)}'),
      card('Recordes do mês', '${m.records}', '', null, 0,
          'Recordes do mês, ${m.records}'),
      card('Sequência', '$streak', streak == 1 ? 'dia' : 'dias', null, 0,
          'Sequência atual, $streak dias'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final x in cards) SizedBox(width: w, child: x)],
      );
    });
  }
}

class _RecordsTimeline extends ConsumerWidget {
  const _RecordsTimeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(recordsProvider).value;
    if (list == null) return const LoadingView();
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        message: 'Nenhum recorde ainda. Supere um lançamento anterior e ele '
            'aparece aqui.',
      );
    }
    // Ganho de cada recorde contra o recorde anterior do mesmo exercício.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final r = list[i];
        final older = list
            .skip(i + 1)
            .where((x) => x.exercise.id == r.exercise.id)
            .firstOrNull;
        final gain = older == null ? null : r.record.value - older.record.value;
        final value = fmtExercise(r.record.value, r.exercise.unit);
        return Semantics(
          label: 'Recorde de ${r.exercise.name}: $value em ${fmtDate(r.record.date)}',
          excludeSemantics: true,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: FolegoColors.surfaceHigh,
              child: Icon(Icons.emoji_events, color: FolegoColors.lime),
            ),
            title: Text(r.exercise.name),
            subtitle: Text(fmtDate(r.record.date)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: numberStyle(18, color: FolegoColors.lime)),
                if (gain != null)
                  Text('+${fmtNum(gain, decimals: 0)} ${r.exercise.unit.short}',
                      style: const TextStyle(
                          fontSize: 12, color: FolegoColors.textSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }
}

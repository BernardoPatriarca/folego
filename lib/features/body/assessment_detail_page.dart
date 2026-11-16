// Detalhe de uma avaliação: todos os valores, derivados e variações contra a
// anterior e contra a primeira.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/body.dart';
import '../../domain/body_metrics.dart';
import '../../domain/models.dart';
import 'metric_info.dart';

class AssessmentDetailPage extends ConsumerWidget {
  const AssessmentDetailPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(assessmentsProvider).value;
    final profile = ref.watch(profileProvider).value;
    final types = ref.watch(measureTypesProvider).value ?? const [];
    if (list == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    final a = list.where((x) => x.id == id).firstOrNull;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.search_off, message: 'Avaliação não encontrada.'),
      );
    }

    Widget row(String key, {String? labelOverride}) {
      final v = metricValue(a, key, profile);
      if (v == null) return const SizedBox.shrink();
      final info = metricInfo(key, types);
      final prev = previousValue(list, a, key, profile);
      final first = firstValue(list, key, profile);
      final u = info.unit.isEmpty ? '' : ' ${info.unit}';
      final changes = [
        if (prev != null)
          '${fmtSigned(v - prev, decimals: info.decimals)}$u vs anterior',
        if (first != null && first.date.isBefore(a.date))
          '${fmtSigned(v - first.value, decimals: info.decimals)}$u desde '
              '${fmtMonthShort(first.date)}',
      ];
      return Semantics(
        label: '${labelOverride ?? info.label}, '
            '${fmtNum(v, decimals: info.decimals)}$u. ${changes.join('. ')}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labelOverride ?? info.label),
                    if (changes.isNotEmpty)
                      Text(changes.join(' · '),
                          style: Theme.of(context).textTheme.bodySmall),
                    if (key == 'imc')
                      Text(bmiCategory(v).label,
                          style: const TextStyle(
                              fontSize: 12, color: FolegoColors.lime)),
                  ],
                ),
              ),
              Text('${fmtNum(v, decimals: info.decimals)}$u',
                  style: numberStyle(18)),
            ],
          ),
        ),
      );
    }

    final waistId = types.where((t) => t.name == 'Cintura').firstOrNull?.id;
    final hipId = types.where((t) => t.name == 'Quadril').firstOrNull?.id;
    final whr = waistHipRatio(a.measures[waistId], a.measures[hipId]);
    final wht = waistHeightRatio(
        a.measures[waistId], effectiveHeight(a, profile));
    final fatInformed = a['massa_gorda_kg'] != null;

    List<Widget> measureRows(MeasureCategory cat) => [
          for (final t in types.where((t) => t.category == cat))
            if (a.measures.containsKey(t.id)) row('medida:${t.id}'),
        ];

    final sections = <(String, List<Widget>)>[
      (
        'Composição',
        [
          for (final m in bodyMetrics)
            if (m.section == MetricSection.composition &&
                m.key != 'massa_gorda_kg')
              row(m.key),
          row('massa_gorda_kg',
              labelOverride:
                  fatInformed ? 'Massa gorda' : 'Massa gorda (calculada)'),
          row('residuos_pct'),
          row('imc'),
        ]
      ),
      ('Circunferências', measureRows(MeasureCategory.circumference)),
      ('Dobras cutâneas', measureRows(MeasureCategory.skinfold)),
      ('Outras medidas', measureRows(MeasureCategory.other)),
      (
        'Sinais vitais',
        [
          for (final m in bodyMetrics)
            if (m.section == MetricSection.vitals) row(m.key),
        ]
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('AVALIAÇÃO ${fmtDate(a.date)}'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/avaliacao/$id/editar'),
          ),
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, a),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (a.origin != null)
              Text('Origem: ${capitalize(a.origin!)}',
                  style: const TextStyle(color: FolegoColors.textSecondary)),
            for (final (title, rows) in sections)
              if (rows.any((w) => w is! SizedBox)) ...[
                SectionTitle(title),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: rows),
                ),
              ],
            if (whr != null || wht != null) ...[
              const SectionTitle('Relações'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (whr != null)
                      Text('Cintura/quadril: ${fmtNum(whr, decimals: 2)}'),
                    if (wht != null)
                      Text('Cintura/altura: ${fmtNum(wht, decimals: 2)}'),
                  ],
                ),
              ),
            ],
            if (a.note != null) ...[
              const SectionTitle('Observação'),
              Text(a.note!),
            ],
            const HealthDisclaimer(),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, BodyAssessment a) async {
    final ok = await confirmDialog(context,
        title: 'Excluir avaliação?',
        message: 'A avaliação de ${fmtDate(a.date)} e todas as suas medidas '
            'serão apagadas.');
    if (!ok || !context.mounted) return;
    final repo = ref.read(bodyRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await repo.delete(a.id!);
    ref.bumpData();
    if (!context.mounted) return;
    context.pop();
    if (deleted != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('Avaliação de ${fmtDate(a.date)} excluída.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            await repo.restore(deleted);
            ref.bumpData();
          },
        ),
      ));
    }
  }
}

// Comparador: duas avaliações lado a lado, com a diferença de cada métrica.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/body.dart';
import '../../domain/body_metrics.dart';
import 'metric_info.dart';

class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key});

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  int? _a;
  int? _b;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(assessmentsProvider).value;
    final profile = ref.watch(profileProvider).value;
    final types = ref.watch(measureTypesProvider).value ?? const [];
    if (list == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    if (list.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('COMPARAR')),
        body: const EmptyState(
            icon: Icons.compare_arrows,
            message: 'São precisas pelo menos duas avaliações para comparar.'),
      );
    }
    // Padrão: a mais antiga (A) contra a mais recente (B).
    _a ??= list.last.id;
    _b ??= list.first.id;
    final a = list.firstWhere((x) => x.id == _a, orElse: () => list.last);
    final b = list.firstWhere((x) => x.id == _b, orElse: () => list.first);

    final keys = [
      for (final m in bodyMetrics) m.key,
      'imc',
      'residuos_pct',
      for (final t in types) 'medida:${t.id}',
    ];
    final rows = <Widget>[];
    for (final k in keys) {
      final va = metricValue(a, k, profile);
      final vb = metricValue(b, k, profile);
      if (va == null && vb == null) continue;
      final info = metricInfo(k, types);
      final d = info.decimals;
      final delta = variation(vb, va);
      rows.add(Semantics(
        label: '${info.label}: A ${va == null ? 'sem valor' : fmtNum(va, decimals: d)}, '
            'B ${vb == null ? 'sem valor' : fmtNum(vb, decimals: d)}'
            '${delta == null ? '' : ', diferença ${fmtSigned(delta, decimals: d)}'}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                    info.unit.isEmpty ? info.label : '${info.label} (${info.unit})'),
              ),
              Expanded(
                flex: 2,
                child: Text(va == null ? '–' : fmtNum(va, decimals: d),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontFeatures: tabular)),
              ),
              Expanded(
                flex: 2,
                child: Text(vb == null ? '–' : fmtNum(vb, decimals: d),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontFeatures: tabular)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  delta == null ? '' : fmtSigned(delta, decimals: d),
                  textAlign: TextAlign.end,
                  style: numberStyle(15,
                      color: delta == null || delta == 0
                          ? FolegoColors.textSecondary
                          : FolegoColors.lime),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    DropdownButtonFormField<int> picker(String label, int? value,
            ValueChanged<int?> onChanged) =>
        DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final x in list)
              DropdownMenuItem(
                value: x.id,
                child: Text(
                    '${fmtDate(x.date)}${x.origin == null ? '' : ' · ${x.origin}'}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('COMPARAR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            picker('Avaliação A', _a, (v) => setState(() => _a = v)),
            const SizedBox(height: 12),
            picker('Avaliação B', _b, (v) => setState(() => _b = v)),
            const SizedBox(height: 8),
            Text(
              _daysBetween(a.date, b.date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(flex: 4, child: Text('MÉTRICA', style: _h)),
                      Expanded(
                          flex: 2,
                          child: Text('A', textAlign: TextAlign.end, style: _h)),
                      Expanded(
                          flex: 2,
                          child: Text('B', textAlign: TextAlign.end, style: _h)),
                      Expanded(
                          flex: 3,
                          child: Text('B − A',
                              textAlign: TextAlign.end, style: _h)),
                    ]),
                  ),
                  const Divider(),
                  ...rows,
                ],
              ),
            ),
            const HealthDisclaimer(),
          ],
        ),
      ),
    );
  }

  String _daysBetween(DateTime a, DateTime b) {
    final d = b.difference(a).inDays.abs();
    return d == 0 ? 'Mesmo dia' : '$d dias entre as avaliações';
  }
}

const _h = TextStyle(
    fontFamily: headingFont,
    fontSize: 13,
    letterSpacing: 1,
    color: FolegoColors.textSecondary);

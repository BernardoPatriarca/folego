// Pré-visualização da importação CSV: linhas válidas, erros, colunas novas e
// avaliações em datas já existentes (substituir ou pular).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/csv_import.dart';
import '../../domain/dates.dart';
import 'csv_import_service.dart';

class CsvPreviewPage extends ConsumerStatefulWidget {
  const CsvPreviewPage({super.key, required this.result});
  final CsvParseResult result;

  @override
  ConsumerState<CsvPreviewPage> createState() => _CsvPreviewPageState();
}

class _CsvPreviewPageState extends ConsumerState<CsvPreviewPage> {
  Set<DateTime>? _existing;
  late final Set<String> _create = {...widget.result.unknownColumns};
  DuplicatePolicy _policy = DuplicatePolicy.skip;
  String _newUnit = 'cm';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(csvImportServiceProvider)
        .existingDates(widget.result.rows)
        .then((d) => mounted ? setState(() => _existing = d) : null);
  }

  Future<void> _import() async {
    setState(() => _saving = true);
    final report = await ref.read(csvImportServiceProvider).apply(
          rows: widget.result.rows,
          createTypes: _create,
          policy: _policy,
          newTypeUnit: _newUnit,
        );
    ref.bumpData();
    if (!mounted) return;
    final parts = [
      '${report.inserted} novas',
      if (report.replaced > 0) '${report.replaced} substituídas',
      if (report.skipped > 0) '${report.skipped} puladas',
      if (report.createdTypes > 0) '${report.createdTypes} medidas criadas',
    ];
    showMessage(context, 'Importação concluída: ${parts.join(', ')}.',
        icon: Icons.check_circle);
    context.go('/corpo');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final t = Theme.of(context).textTheme;
    final existing = _existing;
    final dupInFile = duplicatedDates(r.rows);
    final sorted = [...r.rows]..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(title: const Text('PRÉ-VISUALIZAÇÃO')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverList.list(children: [
                      AppCard(
                        child: Row(children: [
                          Expanded(
                            child: BigStat(
                                label: 'Válidas',
                                value: '${r.rows.length}',
                                color: FolegoColors.lime),
                          ),
                          Expanded(
                            child: BigStat(
                                label: 'Com erro',
                                value: '${r.errors.length}',
                                color: r.errors.isEmpty
                                    ? FolegoColors.text
                                    : FolegoColors.bold),
                          ),
                        ]),
                      ),
                      if (r.rows.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                            'Período: ${fmtDate(sorted.first.date)} a ${fmtDate(sorted.last.date)}',
                            style: t.bodySmall),
                      ],
                      if (r.unknownColumns.isNotEmpty) ...[
                        const SectionTitle('Colunas que não estão no catálogo'),
                        Text('Marque as que devem virar um tipo de medida novo. '
                            'As desmarcadas serão ignoradas.',
                            style: t.bodySmall),
                        for (final c in r.unknownColumns)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _create.contains(c),
                            title: Text('Criar "$c"'),
                            activeColor: FolegoColors.lime,
                            checkColor: FolegoColors.onLime,
                            onChanged: (v) => setState(
                                () => v! ? _create.add(c) : _create.remove(c)),
                          ),
                        if (_create.isNotEmpty)
                          Wrap(spacing: 8, children: [
                            Text('Unidade das novas: ', style: t.bodyMedium),
                            for (final u in const ['cm', 'mm', '%', 'kg'])
                              ChoiceChip(
                                label: Text(u),
                                selected: _newUnit == u,
                                onSelected: (_) => setState(() => _newUnit = u),
                              ),
                          ]),
                      ],
                      if (existing != null && existing.isNotEmpty) ...[
                        const SectionTitle('Datas que já têm avaliação'),
                        Text(
                          '${existing.length} ${existing.length == 1 ? 'avaliação' : 'avaliações'} '
                          'do arquivo cai${existing.length == 1 ? '' : 'em'} em data já '
                          'existente. Substituir ou pular?',
                          style: t.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<DuplicatePolicy>(
                          segments: const [
                            ButtonSegment(
                                value: DuplicatePolicy.skip,
                                label: Text('Pular')),
                            ButtonSegment(
                                value: DuplicatePolicy.replace,
                                label: Text('Substituir')),
                          ],
                          selected: {_policy},
                          onSelectionChanged: (s) =>
                              setState(() => _policy = s.first),
                        ),
                      ],
                      if (dupInFile.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        WarningLine(
                            'Datas repetidas no próprio arquivo: '
                            '${dupInFile.map(fmtDate).join(', ')}. '
                            'Com "Substituir", a última linha vence.'),
                      ],
                      if (r.errors.isNotEmpty) ...[
                        const SectionTitle('Linhas com erro'),
                        for (final e in r.errors)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 18, color: FolegoColors.bold),
                                const SizedBox(width: 8),
                                Expanded(child: Text(e.toString())),
                              ],
                            ),
                          ),
                      ],
                      if (r.rows.isNotEmpty) const SectionTitle('Linhas válidas'),
                    ]),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, i) {
                        final row = sorted[i];
                        final exists = existing?.any(
                                (d) => toIsoDate(d) == toIsoDate(row.date)) ??
                            false;
                        final parts = [
                          if (row.values['peso_kg'] != null)
                            '${fmtNum(row.values['peso_kg'])} kg',
                          if (row.values['gordura_pct'] != null)
                            '${fmtNum(row.values['gordura_pct'])}%',
                          '${row.values.length + row.measures.length} valores',
                        ];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(fmtDate(row.date)),
                          subtitle: Text(parts.join(' · ')),
                          trailing: exists
                              ? Text(
                                  _policy == DuplicatePolicy.skip
                                      ? 'já existe · pular'
                                      : 'já existe · substituir',
                                  style: const TextStyle(
                                      color: FolegoColors.bold, fontSize: 12))
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.download_done),
                  label: Text(r.rows.isEmpty
                      ? 'Nada para importar'
                      : 'Importar ${r.rows.length} ${r.rows.length == 1 ? 'avaliação' : 'avaliações'}'),
                  onPressed: r.rows.isEmpty || existing == null || _saving
                      ? null
                      : _import,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

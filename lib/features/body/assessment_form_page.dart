// Nova avaliação / edição: seções recolhíveis (Composição, Circunferências,
// Dobras, Sinais vitais, Outras medidas). Só a data é obrigatória.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/body_metrics.dart';
import '../../domain/models.dart';
import '../../domain/numbers.dart';
import '../../domain/validators.dart';

class AssessmentFormPage extends ConsumerStatefulWidget {
  const AssessmentFormPage({super.key, this.editId});

  /// Id da avaliação a editar; `null` = nova.
  final int? editId;

  @override
  ConsumerState<AssessmentFormPage> createState() =>
      _AssessmentFormPageState();
}

class _AssessmentFormPageState extends ConsumerState<AssessmentFormPage> {
  final _form = GlobalKey<FormState>();
  final _origin = TextEditingController();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _metric = {
    for (final m in bodyMetrics) m.key: TextEditingController(),
  };
  final Map<int, TextEditingController> _measure = {};
  late DateTime _date;
  bool _loading = true;
  bool _saving = false;
  List<MeasureType> _types = const [];

  @override
  void initState() {
    super.initState();
    _date = ref.read(todayProvider);
    _load();
  }

  Future<void> _load() async {
    final types = await ref.read(catalogRepositoryProvider).measureTypes();
    BodyAssessment? existing;
    if (widget.editId != null) {
      existing = await ref.read(bodyRepositoryProvider).assessment(widget.editId!);
    }
    if (!mounted) return;
    setState(() {
      // Na edição, mostra também tipos desativados que tenham valor.
      _types = types
          .where((t) => t.active || (existing?.measures.containsKey(t.id) ?? false))
          .toList();
      for (final t in _types) {
        _measure[t.id!] = TextEditingController();
      }
      if (existing != null) _fill(existing, keepDate: false);
      _loading = false;
    });
  }

  void _fill(BodyAssessment a, {required bool keepDate}) {
    if (!keepDate) _date = a.date;
    _origin.text = a.origin ?? '';
    _note.text = keepDate ? '' : (a.note ?? '');
    for (final m in bodyMetrics) {
      _metric[m.key]!.text = numToField(a[m.key]);
    }
    for (final e in _measure.entries) {
      e.value.text = numToField(a.measures[e.key]);
    }
  }

  Future<void> _duplicateLast() async {
    final list = await ref.read(assessmentsProvider.future);
    if (!mounted) return;
    if (list.isEmpty) {
      showMessage(context, 'Ainda não há avaliação para duplicar.');
      return;
    }
    setState(() => _fill(list.first, keepDate: true));
    showMessage(context,
        'Valores de ${fmtDate(list.first.date)} copiados. Ajuste o que mudou.',
        icon: Icons.copy_all);
  }

  @override
  void dispose() {
    _origin.dispose();
    _note.dispose();
    for (final c in [..._metric.values, ..._measure.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      showMessage(context, 'Confira os campos marcados.',
          icon: Icons.error_outline);
      return;
    }
    final values = <String, double>{
      for (final m in bodyMetrics) m.key: ?parseDecimal(_metric[m.key]!.text),
    };
    final measures = <int, double>{
      for (final e in _measure.entries) e.key: ?parseDecimal(e.value.text),
    };
    if (values.isEmpty && measures.isEmpty && _note.text.trim().isEmpty) {
      showMessage(context, 'Preencha pelo menos um valor.',
          icon: Icons.error_outline);
      return;
    }
    setState(() => _saving = true);
    final id = await ref.read(bodyRepositoryProvider).save(BodyAssessment(
          id: widget.editId,
          date: _date,
          origin: _origin.text,
          values: values,
          measures: measures,
          note: _note.text,
        ));
    ref.bumpData();
    if (!mounted) return;
    showMessage(context, 'Avaliação de ${fmtDate(_date)} salva.',
        icon: Icons.check_circle);
    if (widget.editId == null) {
      context.pushReplacement('/avaliacao/$id');
    } else {
      context.pop();
    }
  }

  String? _validate(BodyMetric m, String? v) {
    if (m.key == 'peso_kg') return validateWeight(v);
    if (m.key == 'altura_cm') return validateHeight(v);
    return validateNumber(v,
        min: m.min, max: m.max, integer: m.isInt, unit: m.unit);
  }

  Widget _metricField(BodyMetric m) => NumberField(
        controller: _metric[m.key]!,
        label: m.label,
        suffix: m.unit.isEmpty ? null : m.unit,
        decimal: !m.isInt,
        validator: (v) => _validate(m, v),
      );

  Widget _grid(List<Widget> fields) => LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final f in fields)
              SizedBox(width: c.maxWidth < 300 ? c.maxWidth : w, child: f),
          ],
        );
      });

  Widget _section(String title, IconData icon, List<Widget> fields,
      {bool expanded = false}) {
    if (fields.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        initiallyExpanded: expanded,
        leading: Icon(icon, color: FolegoColors.lime),
        title: Text(title.toUpperCase(),
            style: const TextStyle(fontFamily: headingFont, fontSize: 16)),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [_grid(fields)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final measureFields = <MeasureCategory, List<Widget>>{};
    for (final t in _types) {
      measureFields.putIfAbsent(t.category, () => []).add(NumberField(
            controller: _measure[t.id]!,
            label: t.name,
            suffix: t.unit,
            validator: (v) => validateNumber(v, max: 10000),
          ));
    }
    final composition = bodyMetrics
        .where((m) => m.section == MetricSection.composition)
        .map(_metricField)
        .toList();
    final vitals = bodyMetrics
        .where((m) => m.section == MetricSection.vitals)
        .map(_metricField)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editId == null ? 'NOVA AVALIAÇÃO' : 'EDITAR AVALIAÇÃO'),
      ),
      body: _loading
          ? const LoadingView()
          : SafeArea(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DateButton(
                          date: _date,
                          lastDate: ref.read(todayProvider),
                          onChanged: (d) => setState(() => _date = d),
                        ),
                        if (widget.editId == null)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy_all_outlined, size: 18),
                            label: const Text('Duplicar última avaliação'),
                            onPressed: _duplicateLast,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _origin,
                      decoration: const InputDecoration(
                          labelText: 'Origem',
                          hintText: 'balança, academia, nutricionista…'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final o in const ['balança', 'academia', 'nutricionista'])
                        ActionChip(
                          label: Text(capitalize(o)),
                          onPressed: () => setState(() => _origin.text = o),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    _section('Composição', Icons.monitor_weight_outlined,
                        composition,
                        expanded: true),
                    const SizedBox(height: 8),
                    _section('Circunferências', Icons.straighten,
                        measureFields[MeasureCategory.circumference] ?? []),
                    const SizedBox(height: 8),
                    _section('Dobras', Icons.pinch_outlined,
                        measureFields[MeasureCategory.skinfold] ?? []),
                    const SizedBox(height: 8),
                    _section('Sinais vitais', Icons.favorite_border, vitals),
                    const SizedBox(height: 8),
                    _section('Outras medidas', Icons.tune,
                        measureFields[MeasureCategory.other] ?? []),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      decoration: const InputDecoration(labelText: 'Observação'),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const HealthDisclaimer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Salvar avaliação'),
                      onPressed: _saving ? null : _save,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

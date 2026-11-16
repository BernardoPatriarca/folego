// Metas corporais: criar, editar, pausar e excluir.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import '../../domain/numbers.dart';
import '../../domain/validators.dart';
import 'body_page.dart';
import 'metric_info.dart';

class BodyGoalsPage extends ConsumerWidget {
  const BodyGoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(bodyGoalsProvider).value;
    final list = ref.watch(assessmentsProvider).value ?? const [];
    final profile = ref.watch(profileProvider).value;
    final types = ref.watch(measureTypesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('METAS CORPORAIS')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova meta',
        onPressed: () => _edit(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: goals == null
          ? const LoadingView()
          : goals.isEmpty
              ? EmptyState(
                  icon: Icons.flag_outlined,
                  message: 'Nenhuma meta corporal. Ex.: peso 75 kg, '
                      'gordura 15% ou cintura 85 cm.',
                  actionLabel: 'Criar meta',
                  onAction: () => _edit(context, ref, null),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: goals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final g = goals[i];
                    return Opacity(
                      opacity: g.active ? 1 : 0.55,
                      child: BodyGoalCard(
                        goal: g,
                        assessments: list,
                        profile: profile,
                        types: types,
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Opções',
                          onSelected: (a) => _action(context, ref, g, a),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                                value: 'toggle',
                                child: Text(g.active ? 'Pausar' : 'Reativar')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Excluir')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _action(
      BuildContext context, WidgetRef ref, BodyGoal g, String a) async {
    final repo = ref.read(bodyRepositoryProvider);
    switch (a) {
      case 'edit':
        await _edit(context, ref, g);
      case 'toggle':
        await repo.saveGoal(BodyGoal(
            id: g.id,
            metric: g.metric,
            target: g.target,
            targetDate: g.targetDate,
            active: !g.active));
        ref.bumpData();
      case 'delete':
        final ok = await confirmDialog(context,
            title: 'Excluir meta?', message: 'A meta será apagada.');
        if (!ok) return;
        final row = await repo.deleteGoal(g.id!);
        ref.bumpData();
        if (row != null && context.mounted) {
          showUndoSnack(context, 'Meta excluída.', () async {
            await repo.restoreGoal(row);
            ref.bumpData();
          });
        }
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, BodyGoal? g) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GoalForm(existing: g),
    );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.existing});
  final BodyGoal? existing;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _form = GlobalKey<FormState>();
  final _target = TextEditingController();
  String _metric = 'peso_kg';
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    if (g != null) {
      _metric = g.metric;
      _target.text = numToField(g.target);
      _date = g.targetDate;
    }
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(bodyRepositoryProvider).saveGoal(BodyGoal(
          id: widget.existing?.id,
          metric: _metric,
          target: parseDecimal(_target.text)!,
          targetDate: _date,
          active: widget.existing?.active ?? true,
        ));
    ref.bumpData();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(measureTypesProvider).value ?? const [];
    final metrics = chartableMetrics(types)
        .where((m) => !m.key.startsWith('medida:') ||
            types.any((t) => 'medida:${t.id}' == m.key && t.active) ||
            m.key == _metric)
        .toList();
    final info = metricInfo(_metric, types);
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.existing == null ? 'NOVA META' : 'EDITAR META',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _metric,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Métrica'),
                items: [
                  for (final m in metrics)
                    DropdownMenuItem(
                        value: m.key,
                        child: Text(m.unit.isEmpty
                            ? m.label
                            : '${m.label} (${m.unit})')),
                ],
                onChanged: (v) => setState(() => _metric = v!),
              ),
              const SizedBox(height: 12),
              NumberField(
                controller: _target,
                label: 'Valor-alvo',
                suffix: info.unit.isEmpty ? null : info.unit,
                validator: (v) => _metric == 'peso_kg'
                    ? validateWeight(v, required: true)
                    : validateNumber(v, required: true, max: 10000),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(_date == null
                          ? 'Data-alvo (opcional)'
                          : 'Até ${fmtDate(_date!)}'),
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date ?? now.add(const Duration(days: 90)),
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                  ),
                  if (_date != null)
                    IconButton(
                      tooltip: 'Remover data',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _date = null),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: const Text('Salvar meta')),
            ],
          ),
        ),
      ),
    );
  }
}

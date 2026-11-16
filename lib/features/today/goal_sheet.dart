// Folha para adicionar ou editar a meta de um exercício no dia.
// Já preenche a meta sugerida pela regra de ouro e avisa quando é ousada.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/golden_rule.dart';
import '../../domain/models.dart';
import '../../domain/numbers.dart';
import '../../domain/validators.dart';

/// Abre a folha. Com [existing], edita a meta; senão, adiciona.
Future<void> showGoalSheet(BuildContext context,
    {required DateTime date, GoalView? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _GoalSheet(date: date, existing: existing),
  );
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({required this.date, this.existing});
  final DateTime date;
  final GoalView? existing;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  final _form = GlobalKey<FormState>();
  final _target = TextEditingController();
  final _sets = TextEditingController();
  Exercise? _exercise;
  bool _saving = false;
  int? _prefilledFor;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _exercise = e.exercise;
      _target.text = numToField(e.goal.target);
      _sets.text = numToField(e.goal.sets);
      _prefilledFor = e.exercise.id;
    }
  }

  @override
  void dispose() {
    _target.dispose();
    _sets.dispose();
    super.dispose();
  }

  /// Escolhe o exercício e preenche a meta com a sugestão da regra de ouro.
  Future<void> _choose(Exercise e) async {
    setState(() => _exercise = e);
    final sug =
        await ref.read(suggestionProvider((e.id!, widget.date)).future);
    if (!mounted || _exercise?.id != e.id || _prefilledFor == e.id) return;
    setState(() {
      _prefilledFor = e.id;
      _target.text = sug == null ? '' : '$sug';
    });
  }

  Future<void> _save(int? suggestion) async {
    if (_exercise == null || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final target = parseDecimal(_target.text)!;
    final sets = int.tryParse(_sets.text.trim());
    final bold = isBoldTarget(target, suggestion);
    final repo = ref.read(workoutRepositoryProvider);
    if (widget.existing != null) {
      await repo.updateGoalTarget(widget.existing!.goal.id!,
          target: target, sets: sets, bold: bold);
    } else {
      await repo.addGoal(
          date: widget.date,
          exerciseId: _exercise!.id!,
          target: target,
          sets: sets,
          bold: bold);
    }
    ref.bumpData();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(activeExercisesProvider).value ?? const [];
    final planned = ref.watch(goalsForDateProvider(widget.date)).value ?? [];
    final plannedIds = planned.map((g) => g.exercise.id).toSet();
    final available = widget.existing != null
        ? [widget.existing!.exercise]
        : exercises.where((e) => !plannedIds.contains(e.id)).toList();
    final rule = ref.watch(goldenRuleProvider).value ?? const GoldenRuleConfig();
    final ex = _exercise;
    final suggestion = ex == null
        ? null
        : ref.watch(suggestionProvider((ex.id!, widget.date))).value;

    final target = parseDecimal(_target.text);
    final bold = target != null && isBoldTarget(target, suggestion);
    final t = Theme.of(context).textTheme;

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
              Text(
                  widget.existing == null
                      ? 'ADICIONAR EXERCÍCIO'
                      : 'EDITAR META',
                  style: t.titleLarge),
              const SizedBox(height: 16),
              if (available.isEmpty)
                const EmptyState(
                    icon: Icons.fitness_center,
                    message: 'Todos os exercícios ativos já estão no plano '
                        'de hoje. Ative mais em Mais › Exercícios.')
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in available)
                      ChoiceChip(
                        label: Text(e.name),
                        selected: ex?.id == e.id,
                        onSelected: widget.existing != null
                            ? null
                            : (_) => _choose(e),
                      ),
                  ],
                ),
                if (ex != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    suggestion == null
                        ? 'Sem histórico: a meta é livre.'
                        : 'Sugestão da regra de ouro: '
                            '${fmtExercise(suggestion, ex.unit)} '
                            '(${(rule.factor * 100).round()}% do melhor das '
                            'últimas ${rule.window} sessões).',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: NumberField(
                          controller: _target,
                          label: 'Meta do dia',
                          suffix: ex.unit == ExerciseUnit.reps ? 'reps' : 's',
                          decimal: false,
                          autofocus: suggestion == null,
                          onChanged: (_) => setState(() {}),
                          validator: (v) => validateNumber(v,
                              required: true, min: 1, integer: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: NumberField(
                          controller: _sets,
                          label: 'Séries',
                          decimal: false,
                          helper: 'opcional',
                          textInputAction: TextInputAction.done,
                          validator: (v) => validateNumber(v,
                              min: 1, max: 100, integer: true),
                        ),
                      ),
                    ],
                  ),
                  if (bold) ...[
                    const SizedBox(height: 12),
                    WarningLine(boldWarning(rule.factor)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(suggestion),
                    child: Text(widget.existing == null
                        ? 'Adicionar ao plano'
                        : 'Salvar meta'),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Text(
                'Dica: metas ousadas são permitidas, só ficam marcadas.',
                style: t.bodySmall?.copyWith(color: FolegoColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Aba Lançar: força (exercício + realizado + esforço) ou cardio, numa tela só.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import '../../domain/numbers.dart';
import '../cardio/cardio_form.dart';
import 'log_request.dart';

class LogPage extends ConsumerStatefulWidget {
  const LogPage({super.key});

  @override
  ConsumerState<LogPage> createState() => _LogPageState();
}

class _LogPageState extends ConsumerState<LogPage> {
  final _value = TextEditingController();
  final _cardioKey = GlobalKey<CardioFormState>();
  late DateTime _date;
  bool _cardio = false;
  int? _exerciseId;
  int? _effort;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = ref.read(todayProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final r = ref.read(logRequestProvider);
      if (r != null) _apply(r);
    });
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _apply(LogRequest r) {
    ref.read(logRequestProvider.notifier).consume();
    setState(() {
      _date = r.date;
      _cardio = r.cardio;
    });
    _cardioKey.currentState?.setDate(r.date);
    if (r.exerciseId != null) _select(r.exerciseId!);
  }

  /// Escolhe o exercício e pré-preenche com o que já existe no dia.
  Future<void> _select(int exerciseId) async {
    setState(() {
      _exerciseId = exerciseId;
      _error = null;
    });
    final goals = await ref.read(goalsForDateProvider(_date).future);
    if (!mounted || _exerciseId != exerciseId) return;
    final g = goals.where((g) => g.exercise.id == exerciseId).firstOrNull;
    setState(() {
      _value.text = g?.goal.done != null ? numToField(g!.goal.done) : '';
      _effort = g?.goal.effort;
    });
  }

  Future<void> _changeDate(DateTime d) async {
    setState(() => _date = d);
    _cardioKey.currentState?.setDate(d);
    if (_exerciseId != null) await _select(_exerciseId!);
  }

  void _step(int delta, ExerciseUnit unit) {
    final step = unit == ExerciseUnit.seconds ? 5 : 1;
    final current = parseDecimal(_value.text) ?? 0;
    final next = (current + delta * step).clamp(0, 100000);
    HapticFeedback.selectionClick();
    setState(() {
      _value.text = numToField(next);
      _error = null;
    });
  }

  Future<void> _save(Exercise exercise) async {
    final v = parseDecimal(_value.text);
    if (v == null) {
      setState(() => _error = 'Digite quanto você fez');
      return;
    }
    if (v < 0) {
      setState(() => _error = 'Não pode ser negativo');
      return;
    }
    if (v != v.roundToDouble()) {
      setState(() => _error = 'Use um número inteiro');
      return;
    }
    setState(() => _saving = true);
    final r = await ref.read(workoutRepositoryProvider).logDone(
        date: _date, exerciseId: exercise.id!, done: v, effort: _effort);
    ref.bumpData();
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isRecord) {
      showMessage(context,
          'Novo recorde: ${exercise.name.toLowerCase()} ${fmtExercise(v, exercise.unit).replaceAll(' s', 's')}',
          icon: Icons.emoji_events);
    } else {
      showMessage(
          context,
          '${exercise.name}: ${fmtExercise(v, exercise.unit)} lançado '
          'em ${fmtDateShort(_date)}.',
          icon: Icons.check_circle);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(logRequestProvider, (_, next) {
      if (next != null) _apply(next);
    });
    final today = ref.watch(todayProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('LANÇAR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.fitness_center),
                    label: Text('Força')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.directions_run),
                    label: Text('Cardio')),
              ],
              selected: {_cardio},
              onSelectionChanged: (s) => setState(() => _cardio = s.first),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: DateButton(
                date: _date,
                label: _date == today ? 'Hoje' : 'Dia',
                lastDate: today,
                onChanged: _changeDate,
              ),
            ),
            const SizedBox(height: 16),
            if (_cardio)
              CardioForm(key: _cardioKey, initialDate: _date, showDate: false)
            else
              _strength(context),
          ],
        ),
      ),
    );
  }

  Widget _strength(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final exercises = ref.watch(activeExercisesProvider).value ?? const [];
    final goals = ref.watch(goalsForDateProvider(_date)).value ?? const [];
    final goalByExercise = {for (final g in goals) g.exercise.id: g};
    // Planejados do dia primeiro.
    final ordered = [
      ...exercises.where((e) => goalByExercise.containsKey(e.id)),
      ...exercises.where((e) => !goalByExercise.containsKey(e.id)),
    ];
    final selected = ordered.where((e) => e.id == _exerciseId).firstOrNull;
    final goal = selected == null ? null : goalByExercise[selected.id];

    if (exercises.isEmpty) {
      return const EmptyState(
          icon: Icons.fitness_center,
          message: 'Nenhum exercício ativo. Ative em Mais › Exercícios.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Exercício', style: t.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in ordered)
              ChoiceChip(
                label: Text(goalByExercise[e.id] == null
                    ? e.name
                    : '${e.name} · ${fmtNum(goalByExercise[e.id]!.goal.target, decimals: 0)}'),
                avatar: goalByExercise[e.id]?.goal.isLogged == true
                    ? const Icon(Icons.check, size: 16)
                    : null,
                selected: e.id == _exerciseId,
                onSelected: (_) => _select(e.id!),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (selected == null)
          const EmptyState(
              icon: Icons.touch_app_outlined,
              message: 'Escolha o exercício para lançar o que você fez.')
        else ...[
          Text(selected.name.toUpperCase(),
              textAlign: TextAlign.center, style: t.titleLarge),
          const SizedBox(height: 4),
          Text(
            goal == null
                ? 'Sem meta planejada neste dia'
                : 'Meta: ${fmtExercise(goal.goal.target, selected.unit)}'
                    '${goal.goal.bold ? ' (ousada)' : ''}',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RoundButton(
                icon: Icons.remove,
                label: 'Diminuir',
                onPressed: () => _step(-1, selected.unit),
              ),
              Expanded(
                child: TextField(
                  key: const Key('valor-realizado'),
                  controller: _value,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: numberStyle(64),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: numberStyle(64, color: FolegoColors.border),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    suffixText: selected.unit.short,
                    suffixStyle: numberStyle(20,
                        color: FolegoColors.textSecondary,
                        weight: FontWeight.w400),
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.add,
                label: 'Aumentar',
                onPressed: () => _step(1, selected.unit),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Center(child: WarningLine(_error!)),
          ],
          const SizedBox(height: 20),
          Text('Esforço percebido', style: t.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 1; i <= 10; i++)
                ChoiceChip(
                  label: Text('$i'),
                  showCheckmark: false,
                  tooltip: _effortLabel(i),
                  selected: _effort == i,
                  onSelected: (s) => setState(() => _effort = s ? i : null),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_effort == null ? 'Opcional · 1 leve, 10 máximo' : _effortLabel(_effort!),
              style: t.bodySmall),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('salvar-lancamento'),
            icon: const Icon(Icons.check),
            label: const Text('Salvar lançamento'),
            onPressed: _saving ? null : () => _save(selected),
          ),
        ],
      ],
    );
  }

  String _effortLabel(int e) => switch (e) {
        <= 2 => '$e · muito leve',
        <= 4 => '$e · leve',
        <= 6 => '$e · moderado',
        <= 8 => '$e · pesado',
        _ => '$e · máximo',
      };
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: label,
      iconSize: 32,
      style: IconButton.styleFrom(
        minimumSize: const Size(64, 64),
        backgroundColor: FolegoColors.surfaceHigh,
        foregroundColor: FolegoColors.text,
      ),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

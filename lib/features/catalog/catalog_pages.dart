// Catálogo: exercícios e tipos de medida (adicionar, renomear, desativar e
// excluir quando não houver histórico).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import 'catalog_repository.dart';

const exerciseGroups = [
  'peito',
  'costas',
  'pernas',
  'core',
  'braços',
  'ombros',
  'corpo todo',
];

class ExercisesPage extends ConsumerWidget {
  const ExercisesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(exercisesProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('EXERCÍCIOS')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo exercício',
        onPressed: () => _edit(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: list == null
          ? const LoadingView()
          : list.isEmpty
              ? EmptyState(
                  icon: Icons.fitness_center,
                  message: 'Nenhum exercício. Crie o primeiro.',
                  actionLabel: 'Novo exercício',
                  onAction: () => _edit(context, ref, null))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    return ListTile(
                      title: Text(e.name),
                      subtitle: Text([
                        e.unit == ExerciseUnit.reps ? 'Repetições' : 'Segundos',
                        ?e.group,
                        if (!e.active) 'desativado',
                      ].join(' · ')),
                      onTap: () => _edit(context, ref, e),
                      trailing: Switch(
                        value: e.active,
                        onChanged: (v) async {
                          await ref
                              .read(catalogRepositoryProvider)
                              .setExerciseActive(e.id!, v);
                          ref.bumpData();
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Exercise? e) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExerciseForm(existing: e),
    );
  }
}

class _ExerciseForm extends ConsumerStatefulWidget {
  const _ExerciseForm({this.existing});
  final Exercise? existing;

  @override
  ConsumerState<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends ConsumerState<_ExerciseForm> {
  final _name = TextEditingController();
  ExerciseUnit _unit = ExerciseUnit.reps;
  String? _group;
  String? _error;
  bool _hasHistory = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _unit = e.unit;
      _group = e.group;
      ref
          .read(catalogRepositoryProvider)
          .exerciseHasHistory(e.id!)
          .then((h) => mounted ? setState(() => _hasHistory = h) : null);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(catalogRepositoryProvider);
    try {
      final e = widget.existing;
      if (e == null) {
        await repo.addExercise(
            Exercise(name: _name.text, unit: _unit, group: _group));
      } else {
        await repo.updateExercise(Exercise(
            id: e.id,
            name: _name.text,
            unit: _unit,
            group: _group,
            active: e.active,
            order: e.order));
      }
      ref.bumpData();
      if (mounted) Navigator.pop(context);
    } on CatalogException catch (err) {
      setState(() => _error = err.message);
    }
  }

  Future<void> _delete() async {
    final e = widget.existing!;
    final ok = await confirmDialog(context,
        title: 'Excluir ${e.name}?',
        message: 'O exercício sai do catálogo.');
    if (!ok) return;
    try {
      await ref.read(catalogRepositoryProvider).deleteExercise(e.id!);
      ref.bumpData();
      if (mounted) Navigator.pop(context);
    } on CatalogException catch (err) {
      setState(() => _error = err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.existing == null ? 'NOVO EXERCÍCIO' : 'EDITAR EXERCÍCIO',
                style: t.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Nome', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            Text('Unidade', style: t.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ExerciseUnit>(
              segments: const [
                ButtonSegment(value: ExerciseUnit.reps, label: Text('Repetições')),
                ButtonSegment(value: ExerciseUnit.seconds, label: Text('Segundos')),
              ],
              selected: {_unit},
              onSelectionChanged:
                  _hasHistory ? null : (s) => setState(() => _unit = s.first),
            ),
            if (_hasHistory)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Com histórico, a unidade não pode mudar.',
                    style: t.bodySmall),
              ),
            const SizedBox(height: 16),
            Text('Grupo', style: t.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in exerciseGroups)
                ChoiceChip(
                  label: Text(g),
                  selected: _group == g,
                  onSelected: (s) => setState(() => _group = s ? g : null),
                ),
            ]),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Salvar')),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              if (_hasHistory)
                Text('Tem histórico: para tirar do app, desative no interruptor.',
                    textAlign: TextAlign.center, style: t.bodySmall)
              else
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir exercício'),
                  onPressed: _delete,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class MeasureTypesPage extends ConsumerWidget {
  const MeasureTypesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(measureTypesProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('TIPOS DE MEDIDA')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova medida',
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: list == null
          ? const LoadingView()
          : list.isEmpty
              ? EmptyState(
                  icon: Icons.straighten,
                  message: 'Nenhum tipo de medida.',
                  actionLabel: 'Nova medida',
                  onAction: () => _edit(context, null))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final cat in MeasureCategory.values) ...[
                      if (list.any((t) => t.category == cat))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SectionTitle(cat.label),
                        ),
                      for (final t in list.where((t) => t.category == cat))
                        ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                              [t.unit, if (!t.active) 'desativada'].join(' · ')),
                          onTap: () => _edit(context, t),
                          trailing: Switch(
                            value: t.active,
                            onChanged: (v) async {
                              await ref
                                  .read(catalogRepositoryProvider)
                                  .setMeasureTypeActive(t.id!, v);
                              ref.bumpData();
                            },
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }

  Future<void> _edit(BuildContext context, MeasureType? t) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MeasureTypeForm(existing: t),
    );
  }
}

class _MeasureTypeForm extends ConsumerStatefulWidget {
  const _MeasureTypeForm({this.existing});
  final MeasureType? existing;

  @override
  ConsumerState<_MeasureTypeForm> createState() => _MeasureTypeFormState();
}

class _MeasureTypeFormState extends ConsumerState<_MeasureTypeForm> {
  final _name = TextEditingController();
  final _unit = TextEditingController(text: 'cm');
  MeasureCategory _cat = MeasureCategory.circumference;
  String? _error;
  bool _hasHistory = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _name.text = t.name;
      _unit.text = t.unit;
      _cat = t.category;
      ref
          .read(catalogRepositoryProvider)
          .measureTypeHasHistory(t.id!)
          .then((h) => mounted ? setState(() => _hasHistory = h) : null);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_unit.text.trim().isEmpty) {
      setState(() => _error = 'Informe a unidade.');
      return;
    }
    final repo = ref.read(catalogRepositoryProvider);
    try {
      final t = widget.existing;
      final value = MeasureType(
        id: t?.id,
        name: _name.text,
        unit: _unit.text,
        category: _cat,
        active: t?.active ?? true,
        order: t?.order ?? 0,
      );
      if (t == null) {
        await repo.addMeasureType(value);
      } else {
        await repo.updateMeasureType(value);
      }
      ref.bumpData();
      if (mounted) Navigator.pop(context);
    } on CatalogException catch (err) {
      setState(() => _error = err.message);
    }
  }

  Future<void> _delete() async {
    final t = widget.existing!;
    final ok = await confirmDialog(context,
        title: 'Excluir ${t.name}?', message: 'A medida sai do catálogo.');
    if (!ok) return;
    try {
      await ref.read(catalogRepositoryProvider).deleteMeasureType(t.id!);
      ref.bumpData();
      if (mounted) Navigator.pop(context);
    } on CatalogException catch (err) {
      setState(() => _error = err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.existing == null ? 'NOVA MEDIDA' : 'EDITAR MEDIDA',
                style: t.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Nome', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unit,
              decoration: const InputDecoration(
                  labelText: 'Unidade', hintText: 'cm, mm, %, kg…'),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in MeasureCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _cat == c,
                  onSelected: (_) => setState(() {
                    _cat = c;
                    if (c == MeasureCategory.skinfold) _unit.text = 'mm';
                    if (c == MeasureCategory.circumference) _unit.text = 'cm';
                  }),
                ),
            ]),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Salvar')),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              if (_hasHistory)
                Text('Tem histórico: para esconder, desative no interruptor.',
                    textAlign: TextAlign.center, style: t.bodySmall)
              else
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir medida'),
                  onPressed: _delete,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

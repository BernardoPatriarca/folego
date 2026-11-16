// Formulário de cardio: só tipo e duração são obrigatórios.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import '../../domain/numbers.dart';
import '../../domain/validators.dart';

class CardioForm extends ConsumerStatefulWidget {
  const CardioForm({
    super.key,
    this.existing,
    this.initialDate,
    this.onSaved,
    this.showDate = true,
  });

  final CardioView? existing;
  final DateTime? initialDate;
  final VoidCallback? onSaved;
  final bool showDate;

  @override
  ConsumerState<CardioForm> createState() => CardioFormState();
}

class CardioFormState extends ConsumerState<CardioForm> {
  final _form = GlobalKey<FormState>();
  final _duration = TextEditingController();
  final _kcal = TextEditingController();
  final _avgHr = TextEditingController();
  final _maxHr = TextEditingController();
  final _distance = TextEditingController();
  final _steps = TextEditingController();
  final _note = TextEditingController();
  String? _type;
  late DateTime _date;
  bool _saving = false;
  bool _typeError = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? widget.initialDate ?? ref.read(todayProvider);
    if (e != null) {
      final s = e.session;
      _type = s.type;
      _duration.text = numToField(s.durationMin);
      _kcal.text = numToField(s.kcal);
      _avgHr.text = numToField(s.avgHr);
      _maxHr.text = numToField(s.maxHr);
      _distance.text = numToField(s.distanceKm);
      _steps.text = numToField(s.steps);
      _note.text = s.note ?? '';
    }
  }

  /// Usado pela aba Lançar quando o usuário muda a data lá em cima.
  void setDate(DateTime d) => setState(() => _date = d);

  @override
  void dispose() {
    for (final c in [_duration, _kcal, _avgHr, _maxHr, _distance, _steps, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clear() {
    for (final c in [_duration, _kcal, _avgHr, _maxHr, _distance, _steps, _note]) {
      c.clear();
    }
    setState(() => _type = null);
  }

  Future<void> _save() async {
    setState(() => _typeError = _type == null);
    if (!_form.currentState!.validate() || _type == null) return;
    setState(() => _saving = true);
    final session = CardioSession(
      dayId: 0,
      type: _type!,
      durationMin: parseDecimal(_duration.text)!,
      kcal: parseDecimal(_kcal.text),
      avgHr: parseDecimal(_avgHr.text)?.round(),
      maxHr: parseDecimal(_maxHr.text)?.round(),
      distanceKm: parseDecimal(_distance.text),
      steps: parseDecimal(_steps.text)?.round(),
      note: _note.text,
    );
    final repo = ref.read(cardioRepositoryProvider);
    if (widget.existing != null) {
      await repo.update(widget.existing!.session.id!, _date, session);
    } else {
      await repo.add(_date, session);
    }
    ref.bumpData();
    if (!mounted) return;
    setState(() => _saving = false);
    showMessage(
        context,
        '${capitalize(session.type)} · ${fmtMinutes(session.durationMin)} '
        'lançado em ${fmtDateShort(_date)}.',
        icon: Icons.check_circle);
    if (widget.existing == null) _clear();
    widget.onSaved?.call();
  }

  String? _hr(String? v) =>
      validateNumber(v, min: 30, max: 250, integer: true, unit: 'bpm');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showDate) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: DateButton(
                  date: _date,
                  lastDate: ref.read(todayProvider),
                  onChanged: setDate),
            ),
            const SizedBox(height: 16),
          ],
          Text('Tipo', style: t.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in cardioTypes)
                ChoiceChip(
                  label: Text(capitalize(type)),
                  selected: _type == type,
                  onSelected: (_) => setState(() {
                    _type = type;
                    _typeError = false;
                  }),
                ),
            ],
          ),
          if (_typeError)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: WarningLine('Escolha o tipo de cardio'),
            ),
          const SizedBox(height: 16),
          NumberField(
            controller: _duration,
            label: 'Duração *',
            suffix: 'min',
            validator: (v) =>
                validateNumber(v, required: true, min: 1, max: 1440, unit: 'min'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: NumberField(
                controller: _kcal,
                label: 'Calorias',
                suffix: 'kcal',
                validator: (v) => validateNumber(v, max: 20000),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberField(
                controller: _distance,
                label: 'Distância',
                suffix: 'km',
                validator: (v) => validateNumber(v, max: 1000),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: NumberField(
                controller: _avgHr,
                label: 'FC média',
                suffix: 'bpm',
                decimal: false,
                validator: _hr,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberField(
                controller: _maxHr,
                label: 'FC máx.',
                suffix: 'bpm',
                decimal: false,
                validator: (v) {
                  final e = _hr(v);
                  if (e != null) return e;
                  final max = parseDecimal(v), avg = parseDecimal(_avgHr.text);
                  if (max != null && avg != null && max < avg) {
                    return 'Menor que a média';
                  }
                  return null;
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          NumberField(
            controller: _steps,
            label: 'Passos',
            decimal: false,
            validator: (v) => validateNumber(v, max: 200000, integer: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Observação'),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _save,
            label: Text(widget.existing == null ? 'Lançar cardio' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

/// Página cheia para lançar/editar cardio (vinda da tela Hoje).
class CardioFormPage extends StatelessWidget {
  const CardioFormPage({super.key, this.existing, this.date});
  final CardioView? existing;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(existing == null ? 'LANÇAR CARDIO' : 'EDITAR CARDIO')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CardioForm(
              existing: existing,
              initialDate: date,
              onSaved: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

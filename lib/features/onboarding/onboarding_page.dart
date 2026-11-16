// Primeira execução: boas-vindas, PIN, perfil, primeira avaliação,
// exercícios ativos e meta semanal de cardio. Tudo é gravado só no fim.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/numbers.dart';
import '../../domain/validators.dart';
import '../auth/lock_controller.dart';
import '../auth/pin_pad.dart';
import '../settings/config_repository.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _steps = 6;
  int _step = 0;

  // PIN
  String? _pin;
  String? _pinFirst;
  String? _pinError;

  // Perfil
  final _profileForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _height = TextEditingController();
  DateTime? _birth;
  String? _sex;

  // Primeira avaliação
  final _bodyForm = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _muscle = TextEditingController();
  final _water = TextEditingController();
  bool _skipAssessment = false;

  // Exercícios e cardio
  List<Exercise>? _exercises;
  final Set<int> _selected = {};
  final _cardio = TextEditingController(text: '150');
  final _cardioForm = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(catalogRepositoryProvider).exercises().then((list) {
      if (!mounted) return;
      setState(() {
        _exercises = list;
        _selected.addAll(list.map((e) => e.id!));
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _height, _weight, _fat, _muscle, _water, _cardio]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  void _onPin(String pin) {
    if (_pinFirst == null) {
      setState(() {
        _pinFirst = pin;
        _pinError = null;
      });
    } else if (pin == _pinFirst) {
      setState(() {
        _pin = pin;
        _step++;
      });
    } else {
      setState(() {
        _pinFirst = null;
        _pinError = 'Os PINs não conferem. Crie de novo.';
      });
    }
  }

  Future<void> _finish() async {
    if (!_cardioForm.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final config = ref.read(configRepositoryProvider);
    final body = ref.read(bodyRepositoryProvider);
    final profile = Profile(
      name: _name.text.trim(),
      birthDate: _birth,
      sex: _sex,
      heightCm: parseDecimal(_height.text),
    );
    final values = <String, double>{
      'peso_kg': ?parseDecimal(_weight.text),
      'gordura_pct': ?parseDecimal(_fat.text),
      'massa_muscular_kg': ?parseDecimal(_muscle.text),
      'agua_pct': ?parseDecimal(_water.text),
    };
    await db.transaction((txn) async {
      await config.saveProfile(profile, txn: txn);
      await txn.update('exercicio', {'ativo': 0});
      for (final id in _selected) {
        await txn.update('exercicio', {'ativo': 1},
            where: 'id = ?', whereArgs: [id]);
      }
      await config.setCardioWeeklyGoal(parseDecimal(_cardio.text)!.round(),
          txn: txn);
      if (!_skipAssessment && values.isNotEmpty) {
        await body.save(
            BodyAssessment(
                date: dateOnly(DateTime.now()),
                origin: 'onboarding',
                values: values),
            txn: txn);
      }
      await config.set(ConfigRepository.keyOnboarded, '1', txn: txn);
    });
    await ref.read(pinServiceProvider).setPin(_pin!);
    ref.bumpData();
    ref.read(lockControllerProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _saving
                          ? null
                          : () {
                              if (_step == 1) _pinFirst = null;
                              _back();
                            },
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Semantics(
                      label: 'Passo ${_step + 1} de $_steps',
                      child: ProgressBar((_step + 1) / _steps, height: 6),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _welcome(),
                    1 => _pinStep(),
                    2 => _profileStep(),
                    3 => _assessmentStep(),
                    4 => _exercisesStep(),
                    _ => _cardioStep(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page({
    required String title,
    String? subtitle,
    required List<Widget> children,
    required Widget actions,
  }) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              Text(title.toUpperCase(), style: t.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle,
                    style: t.bodyLarge
                        ?.copyWith(color: FolegoColors.textSecondary)),
              ],
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: actions),
      ],
    );
  }

  Widget _welcome() {
    final t = Theme.of(context).textTheme;
    return _page(
      title: 'Fôlego',
      subtitle: 'O Lastro do seu corpo.',
      children: [
        const Icon(Icons.bolt, size: 96, color: FolegoColors.lime),
        const SizedBox(height: 16),
        for (final (icon, text) in const [
          (Icons.flag_outlined, 'De manhã você planeja as metas do dia.'),
          (Icons.edit_note, 'Depois do treino, lança o que fez e o esforço.'),
          (Icons.monitor_heart_outlined,
              'Cardio com os números do relógio e avaliações corporais.'),
          (Icons.receipt_long_outlined,
              'Evolução, recordes e um extrato semanal — só você contra você.'),
          (Icons.lock_outline,
              '100% offline. Os dados só saem do celular por backup.'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: FolegoColors.lime),
                const SizedBox(width: 16),
                Expanded(child: Text(text, style: t.bodyLarge)),
              ],
            ),
          ),
      ],
      actions: SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _next, child: const Text('Começar')),
      ),
    );
  }

  Widget _pinStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: PinPad(
        key: ValueKey(_pinFirst == null),
        title: _pinFirst == null ? 'Crie seu PIN' : 'Confirme o PIN',
        subtitle: _pinFirst == null
            ? 'De 4 a 6 dígitos. Ele protege o app ao abrir.'
            : 'Digite o mesmo PIN de novo.',
        error: _pinError,
        onSubmit: _onPin,
      ),
    );
  }

  Widget _profileStep() {
    return Form(
      key: _profileForm,
      child: _page(
        title: 'Seu perfil',
        subtitle: 'Usado para IMC, idade e relações corporais.',
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome'),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.cake_outlined),
            label: Text(_birth == null
                ? 'Data de nascimento'
                : 'Nascimento: ${fmtDate(_birth!)}'),
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _birth ?? DateTime(now.year - 30),
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (d != null) setState(() => _birth = d);
            },
          ),
          const SizedBox(height: 16),
          Text('Sexo', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final (v, l) in const [('M', 'Masculino'), ('F', 'Feminino')])
              ChoiceChip(
                label: Text(l),
                selected: _sex == v,
                onSelected: (s) => setState(() => _sex = s ? v : null),
              ),
          ]),
          const SizedBox(height: 16),
          NumberField(
            controller: _height,
            label: 'Altura',
            suffix: 'cm',
            validator: (v) => validateHeight(v),
          ),
        ],
        actions: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (_profileForm.currentState!.validate()) _next();
            },
            child: const Text('Continuar'),
          ),
        ),
      ),
    );
  }

  Widget _assessmentStep() {
    return Form(
      key: _bodyForm,
      child: _page(
        title: 'Primeira avaliação',
        subtitle: 'Opcional. Depois você pode importar todo o histórico '
            'por CSV em Mais › Backup e importação.',
        children: [
          NumberField(
              controller: _weight,
              label: 'Peso',
              suffix: 'kg',
              validator: (v) => validateWeight(v)),
          const SizedBox(height: 12),
          NumberField(
              controller: _fat,
              label: 'Gordura corporal',
              suffix: '%',
              validator: (v) => validateNumber(v, max: 80, unit: '%')),
          const SizedBox(height: 12),
          NumberField(
              controller: _muscle,
              label: 'Massa muscular',
              suffix: 'kg',
              validator: (v) => validateNumber(v, max: 300, unit: 'kg')),
          const SizedBox(height: 12),
          NumberField(
              controller: _water,
              label: 'Água',
              suffix: '%',
              textInputAction: TextInputAction.done,
              validator: (v) => validateNumber(v, max: 100, unit: '%')),
          const HealthDisclaimer(),
        ],
        actions: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _skipAssessment = true;
                  _next();
                },
                child: const Text('Pular'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_bodyForm.currentState!.validate()) {
                    _skipAssessment = false;
                    _next();
                  }
                },
                child: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exercisesStep() {
    final list = _exercises;
    return _page(
      title: 'Seus exercícios',
      subtitle: 'Escolha os que você pratica. Dá para mudar depois.',
      children: [
        if (list == null)
          const LoadingView()
        else
          for (final e in list)
            CheckboxListTile(
              value: _selected.contains(e.id),
              onChanged: (v) => setState(() =>
                  v! ? _selected.add(e.id!) : _selected.remove(e.id)),
              title: Text(e.name),
              subtitle: Text(
                  '${e.unit == ExerciseUnit.reps ? 'Repetições' : 'Segundos'}'
                  '${e.group == null ? '' : ' · ${e.group}'}'),
              activeColor: FolegoColors.lime,
              checkColor: FolegoColors.onLime,
              contentPadding: EdgeInsets.zero,
            ),
      ],
      actions: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _selected.isEmpty ? null : _next,
          child: Text(_selected.isEmpty
              ? 'Escolha pelo menos um'
              : 'Continuar (${_selected.length})'),
        ),
      ),
    );
  }

  Widget _cardioStep() {
    return Form(
      key: _cardioForm,
      child: _page(
        title: 'Meta de cardio',
        subtitle: 'Minutos por semana. A OMS recomenda de 150 a 300 '
            'minutos de atividade moderada.',
        children: [
          NumberField(
            controller: _cardio,
            label: 'Minutos por semana',
            suffix: 'min',
            decimal: false,
            textInputAction: TextInputAction.done,
            validator: (v) => validateNumber(v,
                required: true, min: 1, max: 5000, integer: true, unit: 'min'),
          ),
        ],
        actions: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _finish,
            child: Text(_saving ? 'Salvando…' : 'Concluir'),
          ),
        ),
      ),
    );
  }
}

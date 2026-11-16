// Configurações: regra de ouro, semana/cardio, perfil e sobre.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class GoldenRulePage extends ConsumerStatefulWidget {
  const GoldenRulePage({super.key});

  @override
  ConsumerState<GoldenRulePage> createState() => _GoldenRulePageState();
}

class _GoldenRulePageState extends ConsumerState<GoldenRulePage> {
  double? _factor;
  int? _window;

  @override
  Widget build(BuildContext context) {
    final rule = ref.watch(goldenRuleProvider).value;
    if (rule == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    final factor = _factor ?? rule.factor;
    final window = _window ?? rule.window;
    final pct = ((factor - 1) * 100).round();
    final example = suggestedTarget(30, factor, ExerciseUnit.reps);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('REGRA DE OURO')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'A meta sugerida é o seu melhor recente × fator, arredondado para '
              'cima (em segundos, para múltiplos de 5). Metas acima disso são '
              'permitidas, mas ficam marcadas como ousadas.',
              style: t.bodyMedium,
            ),
            const SectionTitle('Fator'),
            Text('+$pct% sobre o melhor recente',
                style: numberStyle(28, color: FolegoColors.lime)),
            Slider(
              value: factor,
              min: 1.0,
              max: 1.5,
              divisions: 50,
              label: factor.toStringAsFixed(2).replaceAll('.', ','),
              semanticFormatterCallback: (v) => 'mais ${((v - 1) * 100).round()} por cento',
              onChanged: (v) => setState(() => _factor = v),
            ),
            const SectionTitle('Janela'),
            Text('Últimas $window sessões', style: numberStyle(28)),
            Slider(
              value: window.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$window',
              onChanged: (v) => setState(() => _window = v.round()),
            ),
            AppCard(
              child: Text(
                'Exemplo: se o melhor das últimas $window sessões foi 30 '
                'flexões, a sugestão é $example.',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                await ref.read(configRepositoryProvider).setGoldenRule(
                    GoldenRuleConfig(factor: factor, window: window));
                ref.bumpData();
                if (!context.mounted) return;
                showMessage(context, 'Regra de ouro salva.', icon: Icons.check);
                context.pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class WeekCardioPage extends ConsumerStatefulWidget {
  const WeekCardioPage({super.key});

  @override
  ConsumerState<WeekCardioPage> createState() => _WeekCardioPageState();
}

class _WeekCardioPageState extends ConsumerState<WeekCardioPage> {
  final _form = GlobalKey<FormState>();
  final _minutes = TextEditingController();
  bool? _sunday;
  bool _loaded = false;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(cardioWeeklyGoalProvider).value;
    final sunday = ref.watch(weekStartsOnSundayProvider).value;
    if (goal == null || sunday == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    if (!_loaded) {
      _loaded = true;
      _minutes.text = '$goal';
      _sunday = sunday;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('SEMANA E CARDIO')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle('Meta semanal de cardio'),
              NumberField(
                controller: _minutes,
                label: 'Minutos por semana',
                suffix: 'min',
                decimal: false,
                validator: (v) => validateNumber(v,
                    required: true, min: 1, max: 5000, integer: true, unit: 'min'),
              ),
              const SectionTitle('Início da semana'),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Segunda')),
                  ButtonSegment(value: true, label: Text('Domingo')),
                ],
                selected: {_sunday!},
                onSelectionChanged: (s) => setState(() => _sunday = s.first),
              ),
              const SizedBox(height: 8),
              Text('Vale para o extrato semanal e o gráfico de cardio.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final config = ref.read(configRepositoryProvider);
                  await config.setCardioWeeklyGoal(
                      parseDecimal(_minutes.text)!.round());
                  await config.setWeekStartsOnSunday(_sunday!);
                  ref.bumpData();
                  if (!context.mounted) return;
                  showMessage(context, 'Preferências salvas.', icon: Icons.check);
                  context.pop();
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _height = TextEditingController();
  DateTime? _birth;
  String? _sex;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profileProvider);
    if (!async.hasValue) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    if (!_loaded) {
      _loaded = true;
      final p = async.value;
      _name.text = p?.name ?? '';
      _height.text = numToField(p?.heightCm);
      _birth = p?.birthDate;
      _sex = p?.sex;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('PERFIL')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
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
                label: 'Altura atual',
                suffix: 'cm',
                validator: (v) => validateHeight(v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  await ref.read(configRepositoryProvider).saveProfile(Profile(
                        name: _name.text,
                        birthDate: _birth,
                        sex: _sex,
                        heightCm: parseDecimal(_height.text),
                      ));
                  ref.bumpData();
                  if (!context.mounted) return;
                  showMessage(context, 'Perfil salvo.', icon: Icons.check);
                  context.pop();
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('SOBRE')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.bolt, size: 72, color: FolegoColors.lime),
            const SizedBox(height: 8),
            Text('FÔLEGO', textAlign: TextAlign.center, style: t.displaySmall),
            Text('O Lastro do seu corpo · versão $version',
                textAlign: TextAlign.center, style: t.bodySmall),
            const SizedBox(height: 24),
            for (final line in const [
              'Uso pessoal, 100% offline: sem servidor, sem login, sem '
                  'analytics e sem permissão de internet.',
              'Protegido por PIN. Os dados só saem do celular pelo backup que '
                  'você exporta.',
              'O treino funciona como um extrato: planeje, lance e acompanhe.',
              'Só você contra você: sem rankings e sem comparação com outras '
                  'pessoas.',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 18, color: FolegoColors.lime),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
            const HealthDisclaimer(),
            const SizedBox(height: 8),
            Text('Fontes Oswald e Rubik sob a SIL Open Font License 1.1.',
                style: t.bodySmall),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Fôlego',
                  applicationVersion: version),
              child: const Text('Licenças de software'),
            ),
          ],
        ),
      ),
    );
  }
}

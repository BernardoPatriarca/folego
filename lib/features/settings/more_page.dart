// Aba Mais: atalhos para catálogo, regras, metas, backup e sobre.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/data_providers.dart';
import '../../core/widgets/common.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final rule = ref.watch(goldenRuleProvider).value;
    final cardio = ref.watch(cardioWeeklyGoalProvider).value;

    Widget tile(IconData icon, String title, String route, {String? sub}) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: sub == null ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('MAIS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            const SectionTitle('Você'),
            tile(Icons.person_outline, 'Perfil', '/mais/perfil',
                sub: profile?.name),
            tile(Icons.flag_outlined, 'Metas corporais', '/mais/metas-corporais'),
            tile(Icons.receipt_long_outlined, 'Extrato semanal', '/extrato'),
            const SectionTitle('Treino'),
            tile(Icons.fitness_center, 'Exercícios', '/mais/exercicios'),
            tile(Icons.straighten, 'Tipos de medida', '/mais/medidas'),
            tile(Icons.trending_up, 'Regra de ouro', '/mais/regra',
                sub: rule == null
                    ? null
                    : 'Fator ${rule.factor.toStringAsFixed(2).replaceAll('.', ',')} · '
                        'últimas ${rule.window} sessões'),
            tile(Icons.calendar_view_week, 'Semana e cardio', '/mais/semana',
                sub: cardio == null ? null : 'Meta: $cardio min por semana'),
            const SectionTitle('Dados'),
            tile(Icons.backup_outlined, 'Backup e importação', '/mais/backup',
                sub: 'Exportar, restaurar e importar CSV'),
            tile(Icons.info_outline, 'Sobre', '/mais/sobre'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

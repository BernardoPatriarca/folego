// Card com o cardio de um dia (tela Hoje).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';

class CardioDayCard extends ConsumerWidget {
  const CardioDayCard({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(cardioForDateProvider(date)).value ?? const [];
    final total = list.fold(0.0, (s, c) => s + c.session.durationMin);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Nenhum cardio hoje. Copie os números do relógio '
                  'depois do treino.',
                  style: TextStyle(color: FolegoColors.textSecondary)),
            )
          else ...[
            Text('${fmtMinutes(total)} no total',
                style: numberStyle(22, color: FolegoColors.lime)),
            const SizedBox(height: 4),
            for (final c in list) _CardioLine(c),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.directions_run),
            label: const Text('Lançar cardio'),
            onPressed: () => context.push('/cardio', extra: date),
          ),
        ],
      ),
    );
  }
}

class _CardioLine extends ConsumerWidget {
  const _CardioLine(this.view);
  final CardioView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = view.session;
    final details = [
      fmtMinutes(s.durationMin),
      if (s.distanceKm != null) '${fmtNum(s.distanceKm, decimals: 2)} km',
      if (s.kcal != null) '${fmtNum(s.kcal, decimals: 0)} kcal',
      if (s.avgHr != null) 'FC ${s.avgHr}${s.maxHr != null ? '/${s.maxHr}' : ''}',
      if (s.steps != null) '${fmtNum(s.steps, decimals: 0)} passos',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.monitor_heart_outlined),
      title: Text(capitalize(s.type)),
      subtitle: Text(details),
      onTap: () => context.push('/cardio/editar', extra: view),
      trailing: IconButton(
        tooltip: 'Excluir cardio',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final ok = await confirmDialog(context,
              title: 'Excluir cardio?',
              message: '${capitalize(s.type)} de ${fmtMinutes(s.durationMin)} '
                  'será apagado.');
          if (!ok) return;
          final repo = ref.read(cardioRepositoryProvider);
          final row = await repo.delete(s.id!);
          ref.bumpData();
          if (row != null && context.mounted) {
            showUndoSnack(context, 'Cardio excluído.', () async {
              await repo.restore(row);
              ref.bumpData();
            });
          }
        },
      ),
    );
  }
}

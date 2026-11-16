// Sequência de dias ativos (seção 6.4).
import 'dates.dart';

/// Um dia é ativo com pelo menos uma meta lançada, um cardio ou descanso
/// planejado. A sequência conta dias ativos consecutivos até hoje; se hoje
/// ainda está vazio, conta até ontem.
int currentStreak(Set<DateTime> activeDays, DateTime today) {
  final days = {for (final d in activeDays) dateOnly(d)};
  var cursor = dateOnly(today);
  if (!days.contains(cursor)) cursor = addDays(cursor, -1);
  var count = 0;
  while (days.contains(cursor)) {
    count++;
    cursor = addDays(cursor, -1);
  }
  return count;
}

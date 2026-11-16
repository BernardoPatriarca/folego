// Cumprimento de metas (seção 6.2) e recordes (seção 6.3).

/// Cumprimento de uma meta: `min(realizado / alvo, 1)`.
///
/// Passar da meta conta como 100%. Meta não lançada devolve `null`.
double? goalCompliance(double? done, double target) {
  if (done == null) return null;
  if (target <= 0) return 1;
  final c = done / target;
  if (c < 0) return 0;
  return c > 1 ? 1 : c;
}

/// Cumprimento do dia: média das metas lançadas. Sem metas lançadas, `null`.
double? dayCompliance(Iterable<({double? done, double target})> goals) {
  final values = [
    for (final g in goals) ?goalCompliance(g.done, g.target),
  ];
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

/// É recorde quando supera todos os lançamentos anteriores do exercício.
///
/// [previousBest] é o maior realizado dos outros lançamentos; `null` quando
/// este é o primeiro lançamento (o primeiro nunca conta como recorde).
bool isNewRecord(double? previousBest, double value) =>
    previousBest != null && value > previousBest;

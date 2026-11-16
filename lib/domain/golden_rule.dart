// Regra de ouro: sugestão e limite de meta (seção 6.1).
import 'dart:math' as math;

import 'models.dart';

/// Configuração da regra (tabela `config`).
class GoldenRuleConfig {
  const GoldenRuleConfig({this.factor = 1.10, this.window = 3});

  /// Fator sobre o melhor recente (1,10 = +10%).
  final double factor;

  /// Quantas sessões recentes entram no "melhor recente".
  final int window;
}

/// Maior realizado entre as últimas [window] sessões.
///
/// [doneBySession] vem da sessão mais recente para a mais antiga e contém só
/// sessões em que o exercício foi lançado. Sem histórico, devolve `null`.
double? bestRecent(List<double> doneBySession, int window) {
  if (doneBySession.isEmpty || window <= 0) return null;
  return doneBySession.take(window).reduce(math.max);
}

/// `ceil(melhor × fator)`; em segundos, arredonda para cima em múltiplos de 5.
///
/// Sem histórico (`best == null`) não há sugestão.
int? suggestedTarget(double? best, double factor, ExerciseUnit unit) {
  if (best == null || best <= 0) return null;
  // Arredonda a 6 casas antes do ceil para que 30 × 1,1 = 33,000000000000004
  // não vire 34.
  final raw = double.parse((best * factor).toStringAsFixed(6));
  if (unit == ExerciseUnit.seconds) {
    return (raw / 5).ceil() * 5;
  }
  return raw.ceil();
}

/// A meta é ousada quando passa da sugestão. Sem sugestão, nunca é ousada.
bool isBoldTarget(double target, int? suggested) =>
    suggested != null && target > suggested;

/// Texto do aviso de meta ousada, com o percentual configurado.
String boldWarning(double factor) {
  final pct = (factor * 100).round();
  return 'Meta ousada: acima de $pct% do seu melhor recente';
}

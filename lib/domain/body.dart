// Cálculos corporais derivados (seção 6.6) e metas corporais (seção 6.7).
//
// Nada daqui é gravado no banco: tudo é recalculado a partir da avaliação.
import 'models.dart';

/// IMC = peso / (altura em m)².
double? bmi(double? weightKg, double? heightCm) {
  if (weightKg == null || heightCm == null || heightCm <= 0) return null;
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// Faixas de IMC da OMS.
enum BmiCategory {
  underweight('Abaixo do peso'),
  normal('Peso normal'),
  overweight('Sobrepeso'),
  obesity1('Obesidade grau I'),
  obesity2('Obesidade grau II'),
  obesity3('Obesidade grau III');

  const BmiCategory(this.label);
  final String label;
}

BmiCategory bmiCategory(double value) {
  if (value < 18.5) return BmiCategory.underweight;
  if (value < 25) return BmiCategory.normal;
  if (value < 30) return BmiCategory.overweight;
  if (value < 35) return BmiCategory.obesity1;
  if (value < 40) return BmiCategory.obesity2;
  return BmiCategory.obesity3;
}

/// Relação cintura/quadril.
double? waistHipRatio(double? waist, double? hip) {
  if (waist == null || hip == null || hip <= 0) return null;
  return waist / hip;
}

/// Relação cintura/altura (ambas em cm).
double? waistHeightRatio(double? waist, double? heightCm) {
  if (waist == null || heightCm == null || heightCm <= 0) return null;
  return waist / heightCm;
}

/// Massa gorda em kg = peso × gordura%. Usada só quando não foi informada.
double? fatMassKg(double? weightKg, double? fatPct) {
  if (weightKg == null || fatPct == null) return null;
  return weightKg * fatPct / 100;
}

/// Resíduos (%) = 100 − gordura% − massa muscular%.
double? residualPct(double? fatPct, double? musclePct) {
  if (fatPct == null || musclePct == null) return null;
  final r = 100 - fatPct - musclePct;
  return r < 0 ? null : r;
}

/// Altura efetiva: a da avaliação ou, se vazia, a do perfil.
double? effectiveHeight(BodyAssessment a, Profile? profile) =>
    a['altura_cm'] ?? profile?.heightCm;

/// Valor de uma métrica numa avaliação, incluindo as derivadas:
/// `imc`, `massa_gorda_kg` (calculada se faltar) e `medida:<id>`.
double? metricValue(BodyAssessment a, String metric, Profile? profile) {
  if (metric == 'imc') return bmi(a['peso_kg'], effectiveHeight(a, profile));
  if (metric == 'residuos_pct') {
    return residualPct(a['gordura_pct'], a['massa_muscular_pct']);
  }
  if (metric == 'massa_gorda_kg') {
    return a['massa_gorda_kg'] ?? fatMassKg(a['peso_kg'], a['gordura_pct']);
  }
  if (metric.startsWith('medida:')) {
    final id = int.tryParse(metric.substring(7));
    return id == null ? null : a.measures[id];
  }
  return a[metric];
}

/// Diferença `atual − referência`; `null` se faltar algum dos dois.
double? variation(double? current, double? reference) {
  if (current == null || reference == null) return null;
  return current - reference;
}

/// Avaliação imediatamente anterior a [current] na lista (ordenada ou não).
BodyAssessment? previousAssessment(
    List<BodyAssessment> all, BodyAssessment current) {
  BodyAssessment? best;
  for (final a in all) {
    if (a.id == current.id) continue;
    final before = a.date.isBefore(current.date) ||
        (a.date == current.date && (a.id ?? 0) < (current.id ?? 0));
    if (!before) continue;
    if (best == null ||
        a.date.isAfter(best.date) ||
        (a.date == best.date && (a.id ?? 0) > (best.id ?? 0))) {
      best = a;
    }
  }
  return best;
}

/// Última avaliação anterior a [current] que tem a [metric] preenchida.
double? previousValue(List<BodyAssessment> all, BodyAssessment current,
    String metric, Profile? profile) {
  var cursor = current;
  while (true) {
    final prev = previousAssessment(all, cursor);
    if (prev == null) return null;
    final v = metricValue(prev, metric, profile);
    if (v != null) return v;
    cursor = prev;
  }
}

/// Primeiro valor registrado da métrica (avaliação mais antiga que a tem).
({double value, DateTime date})? firstValue(
    List<BodyAssessment> all, String metric, Profile? profile) {
  final sorted = [...all]..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
    });
  for (final a in sorted) {
    final v = metricValue(a, metric, profile);
    if (v != null) return (value: v, date: a.date);
  }
  return null;
}

/// Progresso de uma meta corporal.
class BodyGoalProgress {
  const BodyGoalProgress({
    required this.current,
    required this.target,
    required this.remaining,
    required this.fraction,
    required this.reached,
  });

  final double current;
  final double target;

  /// Quanto falta, sempre positivo (0 quando atingida).
  final double remaining;

  /// 0–1: quanto do caminho entre o ponto de partida e o alvo já foi feito.
  final double fraction;
  final bool reached;
}

/// [start] é o valor quando a jornada começou (primeira avaliação com a
/// métrica). A direção da meta (subir ou descer) é deduzida de start × alvo.
BodyGoalProgress bodyGoalProgress({
  required double start,
  required double current,
  required double target,
}) {
  final goingDown = target < start;
  final reached = goingDown ? current <= target : current >= target;
  final remaining = reached ? 0.0 : (target - current).abs();
  final total = (target - start).abs();
  double fraction;
  if (reached) {
    fraction = 1;
  } else if (total == 0) {
    fraction = 0;
  } else {
    final done = goingDown ? start - current : current - start;
    fraction = (done / total).clamp(0.0, 1.0);
  }
  return BodyGoalProgress(
    current: current,
    target: target,
    remaining: remaining,
    fraction: fraction,
    reached: reached,
  );
}

// Rótulo, unidade e casas decimais de qualquer métrica corporal, inclusive
// derivadas (IMC) e medidas (`medida:<id>`).
import '../../domain/body_metrics.dart';
import '../../domain/models.dart';

class MetricInfo {
  const MetricInfo(this.key, this.label, this.unit, this.decimals);
  final String key;
  final String label;
  final String unit;
  final int decimals;
}

MetricInfo metricInfo(String key, List<MeasureType> types) {
  if (key == 'imc') return const MetricInfo('imc', 'IMC', '', 1);
  if (key == 'residuos_pct') {
    return const MetricInfo('residuos_pct', 'Resíduos', '%', 1);
  }
  if (key.startsWith('medida:')) {
    final id = int.tryParse(key.substring(7));
    final t = types.where((t) => t.id == id).firstOrNull;
    return MetricInfo(key, t?.name ?? 'Medida removida', t?.unit ?? '', 1);
  }
  final m = bodyMetricByKey[key];
  if (m == null) return MetricInfo(key, key, '', 1);
  return MetricInfo(key, m.label, m.unit, m.decimals);
}

/// Métricas que podem virar meta ou gráfico (sem altura).
List<MetricInfo> chartableMetrics(List<MeasureType> types) => [
      for (final m in bodyMetrics)
        if (m.key != 'altura_cm') MetricInfo(m.key, m.label, m.unit, m.decimals),
      const MetricInfo('imc', 'IMC', '', 1),
      const MetricInfo('residuos_pct', 'Resíduos', '%', 1),
      for (final t in types) MetricInfo('medida:${t.id}', t.name, t.unit, 1),
    ];

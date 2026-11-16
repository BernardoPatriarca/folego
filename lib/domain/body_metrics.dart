// Catálogo das métricas numéricas de `avaliacao_corporal`.
//
// Serve para o formulário, o CSV, o comparador e o gráfico de evolução: tudo
// usa a mesma lista, então uma métrica nova só precisa entrar aqui.

enum MetricSection { composition, vitals }

class BodyMetric {
  const BodyMetric({
    required this.key,
    required this.label,
    required this.unit,
    this.decimals = 1,
    this.isInt = false,
    this.section = MetricSection.composition,
    this.min = 0,
    this.max = 100000,
    this.lowerIsBetter,
  });

  /// Nome da coluna no banco.
  final String key;
  final String label;
  final String unit;
  final int decimals;
  final bool isInt;
  final MetricSection section;
  final double min;
  final double max;

  /// `true` quando diminuir é a direção "boa" (peso, gordura...), `false`
  /// quando aumentar é bom, `null` quando é neutro. Só muda o texto de apoio,
  /// nunca a cor sozinha.
  final bool? lowerIsBetter;
}

const bodyMetrics = <BodyMetric>[
  BodyMetric(key: 'peso_kg', label: 'Peso', unit: 'kg', min: 20, max: 400),
  BodyMetric(
      key: 'altura_cm', label: 'Altura', unit: 'cm', min: 100, max: 250),
  BodyMetric(key: 'gordura_pct', label: 'Gordura', unit: '%', max: 80),
  BodyMetric(key: 'massa_gorda_kg', label: 'Massa gorda', unit: 'kg', max: 300),
  BodyMetric(key: 'massa_magra_kg', label: 'Massa magra', unit: 'kg', max: 300),
  BodyMetric(
      key: 'massa_muscular_kg', label: 'Massa muscular', unit: 'kg', max: 300),
  BodyMetric(key: 'massa_ossea_kg', label: 'Massa óssea', unit: 'kg', max: 50),
  BodyMetric(key: 'agua_pct', label: 'Água', unit: '%', max: 100),
  BodyMetric(key: 'proteina_pct', label: 'Proteína', unit: '%', max: 100),
  BodyMetric(
      key: 'gordura_visceral', label: 'Gordura visceral', unit: '', max: 60),
  BodyMetric(
      key: 'tmb_kcal',
      label: 'TMB',
      unit: 'kcal',
      decimals: 0,
      max: 10000),
  BodyMetric(
      key: 'idade_metabolica',
      label: 'Idade metabólica',
      unit: 'anos',
      decimals: 0,
      isInt: true,
      max: 150),
  BodyMetric(
      key: 'fc_repouso',
      label: 'FC de repouso',
      unit: 'bpm',
      decimals: 0,
      isInt: true,
      section: MetricSection.vitals,
      max: 250),
  BodyMetric(
      key: 'pressao_sistolica',
      label: 'Pressão sistólica',
      unit: 'mmHg',
      decimals: 0,
      isInt: true,
      section: MetricSection.vitals,
      max: 300),
  BodyMetric(
      key: 'pressao_diastolica',
      label: 'Pressão diastólica',
      unit: 'mmHg',
      decimals: 0,
      isInt: true,
      section: MetricSection.vitals,
      max: 200),
];

final bodyMetricByKey = {for (final m in bodyMetrics) m.key: m};

/// Métricas derivadas (calculadas, nunca gravadas).
const derivedBmiKey = 'imc';
const derivedFatMassKey = 'massa_gorda_calc';

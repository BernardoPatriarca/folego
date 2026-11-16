// Conversão entre linhas do SQLite e modelos de domínio.
import '../../domain/body_metrics.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';

bool _b(Object? v) => v == 1 || v == true;
double? _d(Object? v) => v == null ? null : (v as num).toDouble();
int? _i(Object? v) => v == null ? null : (v as num).toInt();

Exercise exerciseFromRow(Map<String, Object?> r) => Exercise(
      id: r['id'] as int,
      name: r['nome'] as String,
      unit: ExerciseUnit.fromDb(r['unidade'] as String),
      group: r['grupo'] as String?,
      active: _b(r['ativo']),
      order: _i(r['ordem']) ?? 0,
    );

Map<String, Object?> exerciseToRow(Exercise e) => {
      'nome': e.name.trim(),
      'unidade': e.unit.db,
      'grupo': e.group,
      'ativo': e.active ? 1 : 0,
      'ordem': e.order,
    };

WorkoutDay dayFromRow(Map<String, Object?> r) => WorkoutDay(
      id: r['id'] as int,
      date: fromIsoDate(r['data'] as String),
      rest: _b(r['descanso']),
      note: r['observacao'] as String?,
    );

Goal goalFromRow(Map<String, Object?> r) => Goal(
      id: r['id'] as int,
      dayId: r['treino_dia_id'] as int,
      exerciseId: r['exercicio_id'] as int,
      target: _d(r['alvo'])!,
      sets: _i(r['series']),
      done: _d(r['realizado']),
      effort: _i(r['esforco']),
      bold: _b(r['ousada']),
    );

CardioSession cardioFromRow(Map<String, Object?> r) => CardioSession(
      id: r['id'] as int,
      dayId: r['treino_dia_id'] as int,
      type: r['tipo'] as String,
      durationMin: _d(r['duracao_min'])!,
      kcal: _d(r['kcal']),
      avgHr: _i(r['fc_media']),
      maxHr: _i(r['fc_max']),
      distanceKm: _d(r['distancia_km']),
      steps: _i(r['passos']),
      note: r['observacao'] as String?,
    );

Map<String, Object?> cardioToRow(CardioSession c) => {
      'treino_dia_id': c.dayId,
      'tipo': c.type,
      'duracao_min': c.durationMin,
      'kcal': c.kcal,
      'fc_media': c.avgHr,
      'fc_max': c.maxHr,
      'distancia_km': c.distanceKm,
      'passos': c.steps,
      'observacao': c.note,
    };

MeasureType measureTypeFromRow(Map<String, Object?> r) => MeasureType(
      id: r['id'] as int,
      name: r['nome'] as String,
      unit: r['unidade'] as String,
      category: MeasureCategory.fromDb(r['categoria'] as String),
      active: _b(r['ativo']),
      order: _i(r['ordem']) ?? 0,
    );

Map<String, Object?> measureTypeToRow(MeasureType t) => {
      'nome': t.name.trim(),
      'unidade': t.unit.trim(),
      'categoria': t.category.db,
      'ativo': t.active ? 1 : 0,
      'ordem': t.order,
    };

BodyAssessment assessmentFromRow(
    Map<String, Object?> r, Map<int, double> measures) {
  final values = <String, double>{};
  for (final m in bodyMetrics) {
    final v = _d(r[m.key]);
    if (v != null) values[m.key] = v;
  }
  return BodyAssessment(
    id: r['id'] as int,
    date: fromIsoDate(r['data'] as String),
    origin: r['origem'] as String?,
    values: values,
    measures: measures,
    note: r['observacao'] as String?,
  );
}

Map<String, Object?> assessmentToRow(BodyAssessment a) => {
      'data': toIsoDate(a.date),
      'origem': (a.origin?.trim().isEmpty ?? true) ? null : a.origin!.trim(),
      for (final m in bodyMetrics)
        m.key: m.isInt ? a[m.key]?.round() : a[m.key],
      'observacao': (a.note?.trim().isEmpty ?? true) ? null : a.note!.trim(),
    };

BodyGoal bodyGoalFromRow(Map<String, Object?> r) => BodyGoal(
      id: r['id'] as int,
      metric: r['metrica'] as String,
      target: _d(r['valor_alvo'])!,
      targetDate: r['data_alvo'] == null
          ? null
          : fromIsoDate(r['data_alvo'] as String),
      active: _b(r['ativa']),
    );

Map<String, Object?> bodyGoalToRow(BodyGoal g) => {
      'metrica': g.metric,
      'valor_alvo': g.target,
      'data_alvo': g.targetDate == null ? null : toIsoDate(g.targetDate!),
      'ativa': g.active ? 1 : 0,
    };

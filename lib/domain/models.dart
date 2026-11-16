// Modelos de domínio do Fôlego. Classes imutáveis, sem dependência de Flutter.
//
// Os nomes das colunas do banco (em português) aparecem só no `toMap`/`fromMap`.

/// Unidade de medida de um exercício.
enum ExerciseUnit {
  reps('reps'),
  seconds('seg');

  const ExerciseUnit(this.db);
  final String db;

  static ExerciseUnit fromDb(String v) =>
      v == 'seg' ? ExerciseUnit.seconds : ExerciseUnit.reps;

  /// Rótulo curto usado depois do número (ex.: "30 reps", "45 s").
  String get short => this == ExerciseUnit.reps ? 'reps' : 's';
}

class Profile {
  const Profile({
    required this.name,
    this.birthDate,
    this.sex,
    this.heightCm,
  });

  final String name;
  final DateTime? birthDate;

  /// 'M' ou 'F'.
  final String? sex;
  final double? heightCm;

  Profile copyWith({
    String? name,
    DateTime? birthDate,
    String? sex,
    double? heightCm,
  }) =>
      Profile(
        name: name ?? this.name,
        birthDate: birthDate ?? this.birthDate,
        sex: sex ?? this.sex,
        heightCm: heightCm ?? this.heightCm,
      );
}

class Exercise {
  const Exercise({
    this.id,
    required this.name,
    required this.unit,
    this.group,
    this.active = true,
    this.order = 0,
  });

  final int? id;
  final String name;
  final ExerciseUnit unit;
  final String? group;
  final bool active;
  final int order;

  Exercise copyWith({
    String? name,
    ExerciseUnit? unit,
    String? group,
    bool? active,
    int? order,
  }) =>
      Exercise(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        group: group ?? this.group,
        active: active ?? this.active,
        order: order ?? this.order,
      );
}

class WorkoutDay {
  const WorkoutDay({
    this.id,
    required this.date,
    this.rest = false,
    this.note,
  });

  final int? id;
  final DateTime date;
  final bool rest;
  final String? note;
}

/// Meta de um exercício num dia (tabela `meta`).
class Goal {
  const Goal({
    this.id,
    required this.dayId,
    required this.exerciseId,
    required this.target,
    this.sets,
    this.done,
    this.effort,
    this.bold = false,
  });

  final int? id;
  final int dayId;
  final int exerciseId;

  /// Alvo do dia (reps ou segundos).
  final double target;
  final int? sets;

  /// Realizado; `null` = ainda não lançado.
  final double? done;

  /// Esforço percebido 1–10.
  final int? effort;

  /// Meta "ousada" (acima da sugestão da regra de ouro).
  final bool bold;

  bool get isLogged => done != null;
}

/// Meta com dados do exercício e da data, para as telas.
class GoalView {
  const GoalView({required this.goal, required this.exercise, required this.date});

  final Goal goal;
  final Exercise exercise;
  final DateTime date;
}

class CardioSession {
  const CardioSession({
    this.id,
    required this.dayId,
    required this.type,
    required this.durationMin,
    this.kcal,
    this.avgHr,
    this.maxHr,
    this.distanceKm,
    this.steps,
    this.note,
  });

  final int? id;
  final int dayId;
  final String type;
  final double durationMin;
  final double? kcal;
  final int? avgHr;
  final int? maxHr;
  final double? distanceKm;
  final int? steps;
  final String? note;
}

/// Sessão de cardio com a data do dia.
class CardioView {
  const CardioView({required this.session, required this.date});
  final CardioSession session;
  final DateTime date;
}

const cardioTypes = [
  'corrida',
  'caminhada',
  'bike',
  'elíptico',
  'natação',
  'outro',
];

class PersonalRecord {
  const PersonalRecord({
    this.id,
    required this.exerciseId,
    required this.value,
    required this.date,
    this.goalId,
  });

  final int? id;
  final int exerciseId;
  final double value;
  final DateTime date;
  final int? goalId;
}

enum MeasureCategory {
  circumference('circunferencia', 'Circunferências'),
  skinfold('dobra', 'Dobras cutâneas'),
  other('outro', 'Outras medidas');

  const MeasureCategory(this.db, this.label);
  final String db;
  final String label;

  static MeasureCategory fromDb(String v) =>
      MeasureCategory.values.firstWhere((c) => c.db == v,
          orElse: () => MeasureCategory.other);
}

class MeasureType {
  const MeasureType({
    this.id,
    required this.name,
    required this.unit,
    required this.category,
    this.active = true,
    this.order = 0,
  });

  final int? id;
  final String name;
  final String unit;
  final MeasureCategory category;
  final bool active;
  final int order;
}

/// Avaliação corporal. Todos os números são opcionais, menos a data.
class BodyAssessment {
  const BodyAssessment({
    this.id,
    required this.date,
    this.origin,
    this.values = const {},
    this.measures = const {},
    this.note,
  });

  final int? id;
  final DateTime date;
  final String? origin;

  /// Valores numéricos por métrica (chave = coluna do banco, ex.: `peso_kg`).
  final Map<String, double> values;

  /// Valores de medidas por `medida_tipo.id`.
  final Map<int, double> measures;
  final String? note;

  double? operator [](String key) => values[key];

  BodyAssessment copyWith({
    int? id,
    DateTime? date,
    String? origin,
    Map<String, double>? values,
    Map<int, double>? measures,
    String? note,
  }) =>
      BodyAssessment(
        id: id ?? this.id,
        date: date ?? this.date,
        origin: origin ?? this.origin,
        values: values ?? this.values,
        measures: measures ?? this.measures,
        note: note ?? this.note,
      );
}

/// Meta corporal (ex.: peso 75 kg). `metric` é uma coluna de avaliação ou
/// `medida:<id>`.
class BodyGoal {
  const BodyGoal({
    this.id,
    required this.metric,
    required this.target,
    this.targetDate,
    this.active = true,
  });

  final int? id;
  final String metric;
  final double target;
  final DateTime? targetDate;
  final bool active;
}

// Fonte de dados de cardio.
//
// No MVP o cardio é lançado à mão. Esta interface deixa pronto o caminho para
// a v2 ler do Health Connect: basta criar uma implementação nova e trocar o
// provider `cardioSourceProvider`, sem mexer nas telas.
import '../../domain/models.dart';

/// Uma sessão vinda de uma fonte externa, ainda não gravada.
class CardioSample {
  const CardioSample({
    required this.date,
    required this.type,
    required this.durationMin,
    this.kcal,
    this.avgHr,
    this.maxHr,
    this.distanceKm,
    this.steps,
    this.sourceId,
  });

  final DateTime date;
  final String type;
  final double durationMin;
  final double? kcal;
  final int? avgHr;
  final int? maxHr;
  final double? distanceKm;
  final int? steps;

  /// Identificador na fonte (para não importar duas vezes).
  final String? sourceId;

  CardioSession toSession() => CardioSession(
        dayId: 0,
        type: type,
        durationMin: durationMin,
        kcal: kcal,
        avgHr: avgHr,
        maxHr: maxHr,
        distanceKm: distanceKm,
        steps: steps,
      );
}

abstract interface class CardioSource {
  /// Nome exibido na interface (ex.: "Manual", "Health Connect").
  String get name;

  /// `true` quando a fonte consegue buscar sessões sozinha.
  bool get canFetch;

  Future<List<CardioSample>> fetch(DateTime from, DateTime to);
}

/// Fonte do MVP: nada é buscado; o usuário digita os números do relógio.
class ManualCardioSource implements CardioSource {
  const ManualCardioSource();

  @override
  String get name => 'Manual';

  @override
  bool get canFetch => false;

  @override
  Future<List<CardioSample>> fetch(DateTime from, DateTime to) async =>
      const [];
}

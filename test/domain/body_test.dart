import 'package:flutter_test/flutter_test.dart';
import 'package:folego/domain/body.dart';
import 'package:folego/domain/models.dart';

void main() {
  group('IMC', () {
    test('cálculo', () {
      expect(bmi(72.4, 178), closeTo(22.85, 0.01));
      expect(bmi(null, 178), isNull);
      expect(bmi(70, null), isNull);
    });

    test('faixas da OMS nos limites', () {
      expect(bmiCategory(18.4), BmiCategory.underweight);
      expect(bmiCategory(18.5), BmiCategory.normal);
      expect(bmiCategory(24.99), BmiCategory.normal);
      expect(bmiCategory(25), BmiCategory.overweight);
      expect(bmiCategory(30), BmiCategory.obesity1);
      expect(bmiCategory(35), BmiCategory.obesity2);
      expect(bmiCategory(40), BmiCategory.obesity3);
      expect(BmiCategory.obesity2.label, 'Obesidade grau II');
    });
  });

  test('relações cintura/quadril e cintura/altura', () {
    expect(waistHipRatio(85, 100), closeTo(0.85, 1e-9));
    expect(waistHipRatio(85, null), isNull);
    expect(waistHeightRatio(89, 178), closeTo(0.5, 1e-9));
    expect(waistHeightRatio(null, 178), isNull);
  });

  test('massa gorda = peso × gordura%', () {
    expect(fatMassKg(80, 20), closeTo(16, 1e-9));
    expect(fatMassKg(80, null), isNull);
  });

  group('valores de métricas e variações', () {
    const profile = Profile(name: 'Eu', heightCm: 180);
    final a1 = BodyAssessment(
        id: 1,
        date: DateTime(2026, 1, 10),
        values: const {'peso_kg': 82, 'gordura_pct': 22},
        measures: const {9: 92});
    final a2 = BodyAssessment(
        id: 2,
        date: DateTime(2026, 2, 10),
        values: const {'gordura_pct': 21});
    final a3 = BodyAssessment(
        id: 3,
        date: DateTime(2026, 3, 10),
        values: const {'peso_kg': 79.7, 'gordura_pct': 20, 'massa_gorda_kg': 15},
        measures: const {9: 88});
    final all = [a3, a1, a2];

    test('IMC usa a altura do perfil quando a avaliação não tem', () {
      expect(metricValue(a1, 'imc', profile), closeTo(82 / 3.24, 1e-9));
    });

    test('massa gorda: informada vence a calculada', () {
      expect(metricValue(a3, 'massa_gorda_kg', profile), 15);
      expect(metricValue(a1, 'massa_gorda_kg', profile), closeTo(18.04, 1e-9));
    });

    test('medida por id', () {
      expect(metricValue(a3, 'medida:9', profile), 88);
      expect(metricValue(a2, 'medida:9', profile), isNull);
    });

    test('anterior pula avaliações sem a métrica', () {
      expect(previousAssessment(all, a3)?.id, 2);
      expect(previousValue(all, a3, 'peso_kg', profile), 82);
      expect(previousValue(all, a3, 'gordura_pct', profile), 21);
      expect(previousValue(all, a1, 'peso_kg', profile), isNull);
    });

    test('variação contra a anterior e contra a primeira', () {
      final prev = previousValue(all, a3, 'peso_kg', profile);
      expect(variation(79.7, prev), closeTo(-2.3, 1e-9));
      final first = firstValue(all, 'peso_kg', profile)!;
      expect(first.value, 82);
      expect(first.date, DateTime(2026, 1, 10));
      expect(variation(null, 1), isNull);
    });
  });

  group('metas corporais', () {
    test('meta de descer (peso)', () {
      final p = bodyGoalProgress(start: 80, current: 76.6, target: 75);
      expect(p.reached, isFalse);
      expect(p.remaining, closeTo(1.6, 1e-9));
      expect(p.fraction, closeTo(0.68, 1e-9));
    });

    test('meta de subir (massa muscular)', () {
      final p = bodyGoalProgress(start: 30, current: 31, target: 34);
      expect(p.remaining, closeTo(3, 1e-9));
      expect(p.fraction, closeTo(0.25, 1e-9));
    });

    test('atingida e ultrapassada', () {
      final p = bodyGoalProgress(start: 80, current: 74, target: 75);
      expect(p.reached, isTrue);
      expect(p.remaining, 0);
      expect(p.fraction, 1);
    });

    test('piorou: progresso não fica negativo', () {
      final p = bodyGoalProgress(start: 80, current: 82, target: 75);
      expect(p.fraction, 0);
      expect(p.remaining, closeTo(7, 1e-9));
    });
  });
}

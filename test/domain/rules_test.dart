import 'package:flutter_test/flutter_test.dart';
import 'package:folego/domain/compliance.dart';
import 'package:folego/domain/dates.dart';
import 'package:folego/domain/golden_rule.dart';
import 'package:folego/domain/models.dart';
import 'package:folego/domain/numbers.dart';
import 'package:folego/domain/streak.dart';
import 'package:folego/domain/validators.dart';

void main() {
  group('Regra de ouro', () {
    test('sem histórico: sem sugestão e nada é ousado', () {
      final best = bestRecent([], 3);
      expect(best, isNull);
      final sug = suggestedTarget(best, 1.10, ExerciseUnit.reps);
      expect(sug, isNull);
      expect(isBoldTarget(500, sug), isFalse);
    });

    test('melhor recente olha só as últimas N sessões', () {
      // Mais recente primeiro: o 50 está fora da janela de 3.
      expect(bestRecent([20, 25, 22, 50], 3), 25);
      expect(bestRecent([20, 25, 22, 50], 4), 50);
      expect(bestRecent([18], 3), 18);
    });

    test('reps: ceil(melhor × fator) sem erro de ponto flutuante', () {
      // 30 × 1,1 = 33,000000000000004 em double; precisa dar 33.
      expect(suggestedTarget(30, 1.10, ExerciseUnit.reps), 33);
      expect(suggestedTarget(26, 1.10, ExerciseUnit.reps), 29); // 28,6
      expect(suggestedTarget(10, 1.00, ExerciseUnit.reps), 10);
    });

    test('segundos: arredonda para cima em múltiplos de 5', () {
      expect(suggestedTarget(60, 1.10, ExerciseUnit.seconds), 70); // 66
      expect(suggestedTarget(50, 1.10, ExerciseUnit.seconds), 55); // 55
      expect(suggestedTarget(45, 1.10, ExerciseUnit.seconds), 50); // 49,5
    });

    test('acima da sugestão é ousada; igual não é', () {
      expect(isBoldTarget(34, 33), isTrue);
      expect(isBoldTarget(33, 33), isFalse);
      expect(isBoldTarget(20, 33), isFalse);
    });

    test('aviso usa o percentual configurado', () {
      expect(boldWarning(1.10),
          'Meta ousada: acima de 110% do seu melhor recente');
      expect(boldWarning(1.25), contains('125%'));
    });
  });

  group('Cumprimento', () {
    test('por meta é limitado a 100%', () {
      expect(goalCompliance(26, 30), closeTo(0.8667, 0.001));
      expect(goalCompliance(40, 30), 1);
      expect(goalCompliance(null, 30), isNull);
      expect(goalCompliance(0, 30), 0);
    });

    test('do dia é a média das metas lançadas', () {
      final c = dayCompliance([
        (done: 15, target: 30), // 50%
        (done: 60, target: 30), // 100% (passou da meta)
        (done: null, target: 20), // não lançada: fora da média
      ]);
      expect(c, closeTo(0.75, 1e-9));
      expect(dayCompliance([(done: null, target: 10)]), isNull);
      expect(dayCompliance([]), isNull);
    });
  });

  group('Recordes', () {
    test('primeiro lançamento não é recorde', () {
      expect(isNewRecord(null, 100), isFalse);
    });
    test('precisa superar (não só igualar) o anterior', () {
      expect(isNewRecord(75, 76), isTrue);
      expect(isNewRecord(75, 75), isFalse);
      expect(isNewRecord(75, 60), isFalse);
    });
  });

  group('Sequência', () {
    final today = DateTime(2026, 11, 16);
    test('conta dias consecutivos até hoje', () {
      final days = {today, addDays(today, -1), addDays(today, -2)};
      expect(currentStreak(days, today), 3);
    });
    test('hoje vazio: vale até ontem', () {
      final days = {addDays(today, -1), addDays(today, -2)};
      expect(currentStreak(days, today), 2);
    });
    test('descanso conta como dia ativo (já entra no conjunto)', () {
      final days = {today, addDays(today, -1) /* descanso */, addDays(today, -2)};
      expect(currentStreak(days, today), 3);
    });
    test('buraco quebra a sequência', () {
      final days = {today, addDays(today, -2), addDays(today, -3)};
      expect(currentStreak(days, today), 1);
    });
    test('sem nada ontem nem hoje: zero', () {
      expect(currentStreak({addDays(today, -2)}, today), 0);
      expect(currentStreak({}, today), 0);
    });
    test('ignora a hora do dia', () {
      final days = {DateTime(2026, 11, 16, 22, 5)};
      expect(currentStreak(days, DateTime(2026, 11, 16, 7)), 1);
    });
  });

  group('Datas', () {
    test('início da semana (segunda ou domingo)', () {
      final wed = DateTime(2026, 11, 18);
      expect(weekStart(wed), DateTime(2026, 11, 16));
      expect(weekStart(wed, startsOnSunday: true), DateTime(2026, 11, 15));
      final sun = DateTime(2026, 11, 22);
      expect(weekStart(sun), DateTime(2026, 11, 16));
      expect(weekStart(sun, startsOnSunday: true), sun);
    });
    test('ISO ida e volta', () {
      expect(toIsoDate(DateTime(2026, 3, 5)), '2026-03-05');
      expect(fromIsoDate('2026-03-05'), DateTime(2026, 3, 5));
    });
    test('idade', () {
      final birth = DateTime(1990, 11, 17);
      expect(ageOn(birth, DateTime(2026, 11, 16)), 35);
      expect(ageOn(birth, DateTime(2026, 11, 17)), 36);
    });
  });

  group('Números e validação', () {
    test('decimal com vírgula ou ponto', () {
      expect(parseDecimal('72,4'), 72.4);
      expect(parseDecimal('72.4'), 72.4);
      expect(parseDecimal('1.234,5'), 1234.5);
      expect(parseDecimal(' 80 '), 80);
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal('1,2,3'), isNull);
    });
    test('mensagens em português', () {
      expect(validateWeight('10'), 'Use um valor entre 20 e 400 kg');
      expect(validateWeight('72,4'), isNull);
      expect(validateHeight('99'), 'Use um valor entre 100 e 250 cm');
      expect(validateHeight('', required: true), 'Campo obrigatório');
      expect(validateNumber('-3'), 'Não pode ser negativo');
      expect(validateNumber('2,5', integer: true), 'Use um número inteiro');
      expect(validateEffort(11), 'O esforço vai de 1 a 10');
      expect(validateEffort(0), 'O esforço vai de 1 a 10');
      expect(validateEffort(7), isNull);
      expect(validatePin('12a4'), 'Use apenas números');
      expect(validatePin('123'), 'O PIN tem de 4 a 6 dígitos');
      expect(validatePin('1234567'), 'O PIN tem de 4 a 6 dígitos');
      expect(validatePin('123456'), isNull);
    });
  });
}

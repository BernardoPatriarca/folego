// Percorre as telas em 320 dp com fonte 1,3x e falha em qualquer overflow
// ou exceção de layout. Rode ao mexer em layouts.
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/domain/models.dart';
import 'package:folego/features/body/body_repository.dart';
import 'package:folego/features/cardio/cardio_repository.dart';
import 'package:folego/features/today/workout_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('todas as telas cabem em 320 dp com fonte 1,3x', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final db = await openWidgetDb();
    final w = WorkoutRepository(db);
    final c = CardioRepository(db, w);
    final b = BodyRepository(db);
    final ids = {
      for (final r in await db.query('exercicio')) r['nome']: r['id'] as int
    };
    for (var d = 1; d <= 17; d++) {
      final day = DateTime(2026, 11, d);
      await w.addGoal(
          date: day, exerciseId: ids['Flexão']!, target: 20.0 + d, bold: d.isOdd);
      await w.logDone(date: day, exerciseId: ids['Flexão']!, done: 18.0 + d, effort: 6);
      await w.logDone(date: day, exerciseId: ids['Prancha']!, done: 40.0 + d * 5);
      await c.add(day, CardioSession(
          dayId: 0, type: 'corrida', durationMin: 30, kcal: 300, avgHr: 140,
          maxHr: 170, distanceKm: 5.25, steps: 6000));
    }
    await w.addGoal(date: DateTime(2026, 11, 18), exerciseId: ids['Agachamento']!, target: 40, bold: true);
    await w.setRest(DateTime(2026, 11, 10), true);
    final cintura = (await db.query('medida_tipo', where: "nome = 'Cintura'")).first['id'] as int;
    final quadril = (await db.query('medida_tipo', where: "nome = 'Quadril'")).first['id'] as int;
    for (var m = 6; m <= 11; m++) {
      await b.save(BodyAssessment(
        date: DateTime(2026, m, 5),
        origin: 'balança',
        values: {
          'peso_kg': 84.0 - m,
          'gordura_pct': 24.0 - m / 2,
          'massa_muscular_kg': 34 + m / 10,
          'agua_pct': 55,
          'gordura_visceral': 9,
          'tmb_kcal': 1750,
          'fc_repouso': 60,
        },
        measures: {cintura: 95.0 - m, quadril: 101},
      ));
    }
    await b.saveGoal(const BodyGoal(metric: 'peso_kg', target: 75));
    final store = await storeWithPin('1234');

    await pumpApp(tester, db, store);
    await typePin(tester, '1234');

    for (final tab in ['Hoje', 'Lançar', 'Corpo', 'Evolução', 'Mais']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'aba $tab');
    }

    final assessmentId =
        (await db.query('avaliacao_corporal', orderBy: 'data DESC')).first['id'];
    final routes = [
      '/cardio',
      '/avaliacao/nova',
      '/avaliacao/$assessmentId',
      '/avaliacao/$assessmentId/editar',
      '/comparar',
      '/extrato',
      '/extrato/2026-11-09',
      '/mais/perfil',
      '/mais/metas-corporais',
      '/mais/exercicios',
      '/mais/medidas',
      '/mais/regra',
      '/mais/semana',
      '/mais/pin',
      '/mais/backup',
      '/mais/sobre',
    ];
    for (final r in routes) {
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push(r);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'rota $r');
      GoRouter.of(ctx).pop();
      await settle(tester);
    }

    // Lançar cardio na aba Lançar.
    await tester.tap(find.text('Lançar').last);
    await settle(tester);
    await tester.tap(find.text('Cardio').first);
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'lançar cardio');

    await db.close();
  });
}

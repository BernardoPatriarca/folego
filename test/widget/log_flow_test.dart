import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/today/workout_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('desbloqueia com PIN, lança flexão e vê o recorde',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final db = await openWidgetDb();
    final workouts = WorkoutRepository(db);
    final flexao = (await db.query('exercicio', where: "nome = 'Flexão'"))
        .first['id'] as int;
    // Histórico: 20 flexões anteontem.
    await workouts.logDone(
        date: DateTime(2026, 11, 16), exerciseId: flexao, done: 20);
    final store = await storeWithPin('2468');

    await pumpApp(tester, db, store);

    // Tela de PIN: um erro, depois o certo.
    expect(find.text('Digite seu PIN'), findsOneWidget);
    await typePin(tester, '1111');
    expect(find.textContaining('PIN incorreto'), findsOneWidget);
    await typePin(tester, '2468');
    expect(find.text('BORA, BERNARDO'), findsOneWidget);

    // Aba Lançar.
    await tester.tap(find.text('Lançar'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Flexão'));
    await settle(tester);

    // + três vezes a partir de vazio = 3; depois digita 25.
    await tester.tap(find.byTooltip('Aumentar'));
    await tester.tap(find.byTooltip('Aumentar'));
    await tester.tap(find.byTooltip('Aumentar'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('valor-realizado')), '25');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '7'));
    expect(find.text('7 · pesado'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('salvar-lancamento')));
    await settle(tester);

    expect(find.text('Novo recorde: flexão 25 reps'), findsOneWidget);
    final goals = await workouts.goalsForDate(DateTime(2026, 11, 18));
    expect(goals.single.goal.done, 25);
    expect(goals.single.goal.effort, 7);
    expect((await workouts.records()).single.record.value, 25);

    // Hoje mostra a meta lançada e a sequência (16 e 18 → só hoje conta).
    await tester.tap(find.text('Hoje'));
    await settle(tester);
    expect(find.text('Flexão'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await db.close();
  });

  testWidgets('salvar sem valor mostra erro em português', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final db = await openWidgetDb();
    await pumpApp(tester, db, await storeWithPin('1234'));
    await typePin(tester, '1234');
    await tester.tap(find.text('Lançar'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Prancha'));
    await settle(tester);
    await tapVisible(tester, find.byKey(const Key('salvar-lancamento')));
    await settle(tester);
    expect(find.text('Digite quanto você fez'), findsOneWidget);
    // Em segundos, o + anda de 5 em 5.
    await tapVisible(tester, find.byTooltip('Aumentar'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    await db.close();
  });
}

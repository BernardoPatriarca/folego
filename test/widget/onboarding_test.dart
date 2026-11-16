import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/db/database.dart';
import 'package:folego/features/auth/pin_service.dart';
import 'package:folego/features/settings/config_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  testWidgets('primeira execução: onboarding completo grava tudo',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    sqfliteFfiInit();
    final db =
        await openWithFactory(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
    final store = MemorySecureStore();

    await pumpApp(tester, db, store);
    expect(find.text('FÔLEGO'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await settle(tester);

    await typePin(tester, '1357');
    expect(find.text('CONFIRME O PIN'), findsOneWidget);
    await typePin(tester, '9999');
    expect(find.text('Os PINs não conferem. Crie de novo.'), findsOneWidget);
    await typePin(tester, '1357');
    await typePin(tester, '1357');

    expect(find.text('SEU PERFIL'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Ana Lima');
    await tester.enterText(find.widgetWithText(TextFormField, 'Altura'), '90');
    await tester.tap(find.text('Continuar'));
    await settle(tester);
    expect(find.text('Use um valor entre 100 e 250 cm'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Altura'), '168');
    await tester.tap(find.text('Continuar'));
    await settle(tester);

    expect(find.text('PRIMEIRA AVALIAÇÃO'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Peso'), '64,5');
    await tester.tap(find.text('Continuar'));
    await settle(tester);

    expect(find.text('SEUS EXERCÍCIOS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Burpee'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Burpee'));
    await tester.pump();
    await tester.tap(find.textContaining('Continuar ('));
    await settle(tester);

    expect(find.text('META DE CARDIO'), findsOneWidget);
    await tester.tap(find.text('Concluir'));
    await settle(tester);

    expect(find.text('BORA, ANA'), findsOneWidget);
    final config = ConfigRepository(db);
    expect(await config.onboarded(), isTrue);
    expect((await config.profile())!.heightCm, 168);
    expect(await PinService(store).hasPin(), isTrue);
    final burpee = await db.query('exercicio', where: "nome = 'Burpee'");
    expect(burpee.first['ativo'], 0);
    final av = await db.query('avaliacao_corporal');
    expect(av.single['peso_kg'], 64.5);
    await db.close();
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/app/app.dart';
import 'package:folego/core/db/database.dart';
import 'package:folego/core/providers.dart';
import 'package:folego/domain/models.dart';
import 'package:folego/features/auth/pin_service.dart';
import 'package:folego/features/settings/config_repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final fixedNow = DateTime(2026, 11, 18, 9);

/// Banco em memória sem isolate (funciona com o relógio falso dos widget
/// tests), já com perfil e onboarding concluído.
Future<Database> openWidgetDb() async {
  sqfliteFfiInit();
  final db = await openWithFactory(
      databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
  final config = ConfigRepository(db);
  await config.saveProfile(
      const Profile(name: 'Bernardo Teste', heightCm: 178));
  await config.set(ConfigRepository.keyOnboarded, '1');
  return db;
}

Future<MemorySecureStore> storeWithPin(String pin) async {
  final store = MemorySecureStore();
  await PinService(store).setPin(pin);
  return store;
}

Future<void> pumpApp(WidgetTester tester, Database db, SecureStore store) async {
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      secureStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => fixedNow),
    ],
    child: const FolegoApp(),
  ));
  await settle(tester);
}

/// pumpAndSettle com limite (barras de progresso indeterminadas não param).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.bySemanticsLabel(d).last);
    await tester.pump();
  }
  await tester.tap(find.bySemanticsLabel('Confirmar'));
  await settle(tester);
}

/// Rola até o widget e toca nele.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

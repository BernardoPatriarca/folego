// Providers de infraestrutura: banco, repositórios e "revisão" dos dados.
//
// Toda escrita no banco chama `ref.read(dataRevisionProvider.notifier).bump()`
// e os providers de leitura observam a revisão, então as telas se atualizam
// sozinhas depois de um lançamento.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../features/body/body_repository.dart';
import '../features/cardio/cardio_repository.dart';
import '../features/cardio/cardio_source.dart';
import '../features/catalog/catalog_repository.dart';
import '../features/settings/backup_service.dart';
import '../features/settings/config_repository.dart';
import '../features/settings/csv_import_service.dart';
import '../features/today/workout_repository.dart';

/// Sobrescrito em `main.dart` (e nos testes) com o banco aberto.
final databaseProvider = Provider<Database>(
    (ref) => throw UnimplementedError('databaseProvider não configurado'));

/// Relógio do app (sobrescrito nos testes).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider =
    NotifierProvider<DataRevision, int>(DataRevision.new);

final catalogRepositoryProvider =
    Provider((ref) => CatalogRepository(ref.watch(databaseProvider)));

final configRepositoryProvider =
    Provider((ref) => ConfigRepository(ref.watch(databaseProvider)));

final workoutRepositoryProvider =
    Provider((ref) => WorkoutRepository(ref.watch(databaseProvider)));

final cardioRepositoryProvider = Provider((ref) => CardioRepository(
    ref.watch(databaseProvider), ref.watch(workoutRepositoryProvider)));

final bodyRepositoryProvider =
    Provider((ref) => BodyRepository(ref.watch(databaseProvider)));

final backupServiceProvider =
    Provider((ref) => BackupService(ref.watch(databaseProvider)));

final csvImportServiceProvider = Provider((ref) => CsvImportService(
      ref.watch(databaseProvider),
      ref.watch(bodyRepositoryProvider),
      ref.watch(catalogRepositoryProvider),
    ));

final cardioSourceProvider =
    Provider<CardioSource>((ref) => const ManualCardioSource());

/// Atalho para avisar que os dados mudaram.
extension BumpRevision on WidgetRef {
  void bumpData() => read(dataRevisionProvider.notifier).bump();
}

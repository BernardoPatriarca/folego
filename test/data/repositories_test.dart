import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/db/database.dart';
import 'package:folego/domain/body.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:folego/core/db/schema.dart';
import 'package:folego/domain/csv_import.dart';
import 'package:folego/domain/golden_rule.dart';
import 'package:folego/domain/models.dart';
import 'package:folego/features/body/body_repository.dart';
import 'package:folego/features/cardio/cardio_repository.dart';
import 'package:folego/features/catalog/catalog_repository.dart';
import 'package:folego/features/settings/backup_service.dart';
import 'package:folego/features/settings/config_repository.dart';
import 'package:folego/features/settings/csv_import_service.dart';
import 'package:folego/features/today/workout_repository.dart';

import 'test_db.dart';

void main() {
  late Database db;
  late CatalogRepository catalog;
  late WorkoutRepository workouts;
  late CardioRepository cardio;
  late BodyRepository body;
  late ConfigRepository config;

  setUp(() async {
    db = await openTestDb();
    catalog = CatalogRepository(db);
    workouts = WorkoutRepository(db);
    cardio = CardioRepository(db, workouts);
    body = BodyRepository(db);
    config = ConfigRepository(db);
  });

  tearDown(() => db.close());

  Future<Exercise> ex(String name) async =>
      (await catalog.exercises()).firstWhere((e) => e.name == name);

  group('schema e seeds', () {
    test('foreign keys ligadas e versão atual', () async {
      final fk = await db.rawQuery('PRAGMA foreign_keys');
      expect(fk.first.values.first, 1);
      expect(await db.getVersion(), schemaVersion);
    });

    test('seeds de exercícios, medidas e config', () async {
      final exercises = await catalog.exercises();
      expect(exercises, hasLength(11));
      expect((await ex('Prancha')).unit, ExerciseUnit.seconds);
      final types = await catalog.measureTypes();
      expect(types.where((t) => t.category == MeasureCategory.circumference),
          hasLength(15));
      expect(types.where((t) => t.category == MeasureCategory.skinfold),
          hasLength(7));
      final rule = await config.goldenRule();
      expect(rule.factor, 1.10);
      expect(rule.window, 3);
      expect(await config.weekStartsOnSunday(), isFalse);
      expect(await config.cardioWeeklyGoal(), 150);
    });

    test('índices pedidos existem', () async {
      final idx = (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type = 'index'"))
          .map((r) => r['name'])
          .toSet();
      expect(idx, containsAll([
        'idx_treino_dia_data',
        'idx_meta_exercicio',
        'idx_avaliacao_data',
        'idx_recorde_exercicio',
      ]));
    });
  });

  group('catálogo', () {
    test('não apaga exercício com histórico, só desativa', () async {
      final flexao = await ex('Flexão');
      await workouts.logDone(
          date: DateTime(2026, 11, 1), exerciseId: flexao.id!, done: 20);
      expect(() => catalog.deleteExercise(flexao.id!),
          throwsA(isA<CatalogException>()));
      await catalog.setExerciseActive(flexao.id!, false);
      expect((await catalog.exercises(onlyActive: true))
          .any((e) => e.id == flexao.id), isFalse);
    });

    test('apaga exercício sem histórico e bloqueia nome repetido', () async {
      final id = await catalog.addExercise(
          const Exercise(name: 'Remada', unit: ExerciseUnit.reps));
      expect(() => catalog.addExercise(
              const Exercise(name: 'remada', unit: ExerciseUnit.reps)),
          throwsA(isA<CatalogException>()));
      await catalog.deleteExercise(id);
      expect(await catalog.exercise(id), isNull);
    });

    test('tipo de medida com histórico não pode ser apagado', () async {
      final cintura = (await catalog.measureTypes())
          .firstWhere((t) => t.name == 'Cintura');
      await body.save(BodyAssessment(
          date: DateTime(2026, 1, 1), measures: {cintura.id!: 88}));
      expect(() => catalog.deleteMeasureType(cintura.id!),
          throwsA(isA<CatalogException>()));
    });
  });

  group('treino, regra de ouro e recordes', () {
    test('sugestão usa as últimas sessões antes do dia', () async {
      final flexao = await ex('Flexão');
      const rule = GoldenRuleConfig();
      expect(await workouts.suggestion(flexao, DateTime(2026, 11, 1), rule),
          isNull);
      for (final (d, v) in [(1, 20.0), (2, 30.0), (3, 25.0), (4, 22.0)]) {
        await workouts.logDone(
            date: DateTime(2026, 11, d), exerciseId: flexao.id!, done: v);
      }
      // Janela de 3 antes do dia 5: 22, 25, 30 → 30 × 1,1 = 33.
      expect(await workouts.suggestion(flexao, DateTime(2026, 11, 5), rule), 33);
      // Antes do dia 3: só 20 e 30.
      expect(await workouts.suggestion(flexao, DateTime(2026, 11, 3), rule), 33);
      // Janela 1 antes do dia 5: só 22 → 24,2 → 25.
      expect(
          await workouts.suggestion(flexao, DateTime(2026, 11, 5),
              const GoldenRuleConfig(window: 1)),
          25);
    });

    test('recorde: primeiro não conta, superar conta, editar recalcula',
        () async {
      final prancha = await ex('Prancha');
      final r1 = await workouts.logDone(
          date: DateTime(2026, 11, 1), exerciseId: prancha.id!, done: 60);
      expect(r1.isRecord, isFalse);
      final r2 = await workouts.logDone(
          date: DateTime(2026, 11, 2), exerciseId: prancha.id!, done: 75);
      expect(r2.isRecord, isTrue);
      expect(r2.previousBest, 60);
      expect((await workouts.records()).single.record.value, 75);

      // Corrigir o lançamento para baixo remove o recorde.
      final r3 = await workouts.logDone(
          date: DateTime(2026, 11, 2), exerciseId: prancha.id!, done: 50);
      expect(r3.isRecord, isFalse);
      expect(await workouts.records(), isEmpty);
    });

    test('lançar sem plano cria meta com alvo = realizado', () async {
      final burpee = await ex('Burpee');
      final day = DateTime(2026, 11, 3);
      await workouts.logDone(
          date: day, exerciseId: burpee.id!, done: 15, effort: 8);
      final goals = await workouts.goalsForDate(day);
      expect(goals.single.goal.target, 15);
      expect(goals.single.goal.done, 15);
      expect(goals.single.goal.effort, 8);
    });

    test('meta planejada e lançada; copiar plano', () async {
      final flexao = await ex('Flexão');
      final agach = await ex('Agachamento');
      final d1 = DateTime(2026, 11, 10), d2 = DateTime(2026, 11, 11);
      await workouts.addGoal(date: d1, exerciseId: flexao.id!, target: 30);
      await workouts.addGoal(
          date: d1, exerciseId: agach.id!, target: 40, sets: 4);
      await workouts.logDone(date: d1, exerciseId: flexao.id!, done: 26);
      final g = await workouts.goalsForDate(d1);
      expect(g, hasLength(2));
      expect(g.firstWhere((x) => x.exercise.id == flexao.id).goal.done, 26);

      final copied =
          await workouts.copyPlan(d1, d2, const GoldenRuleConfig());
      expect(copied, 2);
      final g2 = await workouts.goalsForDate(d2);
      expect(g2.every((x) => x.goal.done == null), isTrue);
      // Flexão: melhor 26 → sugestão 29; 30 > 29 → ousada.
      expect(g2.firstWhere((x) => x.exercise.id == flexao.id).goal.bold,
          isTrue);
      // Agachamento sem histórico → nunca ousada.
      expect(g2.firstWhere((x) => x.exercise.id == agach.id).goal.bold,
          isFalse);
      expect(await workouts.copyPlan(d1, d2, const GoldenRuleConfig()), 0);
    });

    test('apagar meta e desfazer', () async {
      final flexao = await ex('Flexão');
      final d = DateTime(2026, 11, 10);
      final id =
          await workouts.addGoal(date: d, exerciseId: flexao.id!, target: 30);
      final snap = await workouts.deleteGoal(id);
      expect(await workouts.goalsForDate(d), isEmpty);
      await workouts.restoreGoal(snap);
      expect((await workouts.goalsForDate(d)).single.goal.id, id);
    });

    test('dias ativos: meta lançada, cardio e descanso', () async {
      final flexao = await ex('Flexão');
      await workouts.addGoal(
          date: DateTime(2026, 11, 1), exerciseId: flexao.id!, target: 30);
      await workouts.logDone(
          date: DateTime(2026, 11, 2), exerciseId: flexao.id!, done: 10);
      await cardio.add(DateTime(2026, 11, 3),
          const CardioSession(dayId: 0, type: 'corrida', durationMin: 30));
      await workouts.setRest(DateTime(2026, 11, 4), true);
      expect(await workouts.activeDays(), {
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 4),
      });
    });
  });

  group('cardio', () {
    test('grava, lista por período, apaga e restaura', () async {
      final id = await cardio.add(
          DateTime(2026, 11, 5),
          const CardioSession(
              dayId: 0,
              type: 'corrida',
              durationMin: 32.5,
              kcal: 350,
              avgHr: 148,
              maxHr: 171,
              distanceKm: 5.2,
              steps: 6100));
      final list = await cardio.range(DateTime(2026, 11, 1), DateTime(2026, 11, 7));
      expect(list.single.session.distanceKm, 5.2);
      final row = await cardio.delete(id);
      expect(await cardio.forDate(DateTime(2026, 11, 5)), isEmpty);
      await cardio.restore(row!);
      expect((await cardio.forDate(DateTime(2026, 11, 5))).single.session.id,
          id);
    });
  });

  group('avaliações', () {
    test('salva com medidas, edita, apaga e restaura', () async {
      final types = await catalog.measureTypes();
      final cintura = types.firstWhere((t) => t.name == 'Cintura').id!;
      final id = await body.save(BodyAssessment(
        date: DateTime(2026, 1, 10),
        origin: 'balança',
        values: const {'peso_kg': 82.4, 'idade_metabolica': 31},
        measures: {cintura: 90},
      ));
      var a = (await body.assessment(id))!;
      expect(a['peso_kg'], 82.4);
      expect(a.measures[cintura], 90);

      await body.save(a.copyWith(
          values: {...a.values, 'gordura_pct': 21}, measures: {cintura: 88}));
      a = (await body.assessment(id))!;
      expect(a['gordura_pct'], 21);
      expect(a.measures[cintura], 88);

      final deleted = await body.delete(id);
      expect(await body.assessments(), isEmpty);
      expect(await db.query('medida'), isEmpty);
      await body.restore(deleted!);
      expect((await body.assessments()).single.measures[cintura], 88);
    });

    test('metas corporais', () async {
      final id = await body.saveGoal(BodyGoal(
          metric: 'peso_kg', target: 75, targetDate: DateTime(2027, 1, 1)));
      expect((await body.goals()).single.targetDate, DateTime(2027, 1, 1));
      final row = await body.deleteGoal(id);
      expect(await body.goals(), isEmpty);
      await body.restoreGoal(row!);
      expect(await body.goals(), hasLength(1));
    });
  });

  group('importação CSV', () {
    test('cria tipos novos, substitui ou pula datas existentes', () async {
      await body.save(BodyAssessment(
          date: DateTime(2026, 1, 10), values: const {'peso_kg': 90}));
      final parsed = parseAssessmentCsv(
          'data;peso_kg;Cintura;Punho\n'
          '10/01/2026;82;90;17\n'
          '10/02/2026;81;89;\n',
          (await catalog.measureTypes()).map((t) => t.name).toSet());
      expect(parsed.unknownColumns, ['Punho']);
      final service = CsvImportService(db, body, catalog);
      expect(await service.existingDates(parsed.rows), {DateTime(2026, 1, 10)});

      final skip = await service.apply(
          rows: parsed.rows, createTypes: {}, policy: DuplicatePolicy.skip);
      expect(skip.inserted, 1);
      expect(skip.skipped, 1);
      expect((await body.assessments()).last['peso_kg'], 90);

      final replace = await service.apply(
          rows: parsed.rows,
          createTypes: {'Punho'},
          policy: DuplicatePolicy.replace);
      expect(replace.replaced, 2);
      expect(replace.createdTypes, 1);
      final all = await body.assessments();
      expect(all, hasLength(2));
      final jan = all.firstWhere((a) => a.date == DateTime(2026, 1, 10));
      expect(jan['peso_kg'], 82);
      final punho = (await catalog.measureTypes())
          .firstWhere((t) => t.name == 'Punho');
      expect(jan.measures[punho.id], 17);
    });
  });

  group('backup', () {
    test('exporta e importa (substitui tudo)', () async {
      final service = BackupService(db);
      await config.saveProfile(const Profile(name: 'Eu', heightCm: 178));
      final flexao = await ex('Flexão');
      await workouts.logDone(
          date: DateTime(2026, 11, 1), exerciseId: flexao.id!, done: 20);
      await workouts.logDone(
          date: DateTime(2026, 11, 2), exerciseId: flexao.id!, done: 25);
      final json = await service.exportJson(now: DateTime(2026, 11, 16));
      expect(BackupService.fileName(DateTime(2026, 11, 16)),
          'folego-backup-2026-11-16.json');

      // Muda tudo depois do backup.
      await catalog.addExercise(
          const Exercise(name: 'Remada', unit: ExerciseUnit.reps));
      await config.saveProfile(const Profile(name: 'Outro'));

      final data = service.decode(json);
      final summary = service.validate(data);
      expect(summary.counts['recorde'], 1);
      await service.importData(data);
      expect((await config.profile())!.name, 'Eu');
      expect((await catalog.exercises()).any((e) => e.name == 'Remada'),
          isFalse);
      expect(await workouts.records(), hasLength(1));
    });

    test('recusa arquivo inválido ou de versão mais nova', () {
      final service = BackupService(db);
      expect(() => service.decode('não é json'),
          throwsA(isA<BackupException>()));
      expect(() => service.validate({'app': 'lastro'}),
          throwsA(isA<BackupException>()));
      expect(
          () => service.validate({
                'app': 'folego',
                'schema_version': schemaVersion + 1,
                'tabelas': {}
              }),
          throwsA(isA<BackupException>()));
    });
  });

  group('dados iniciais do dono', () {
    test('banco novo já vem com perfil e a avaliação de 08/09/2026',
        () async {
      sqfliteFfiInit();
      final seeded =
          await openWithFactory(databaseFactoryFfi, inMemoryDatabasePath);
      final p = (await ConfigRepository(seeded).profile())!;
      expect(p.name, 'Bernardo');
      expect(p.heightCm, 184);
      expect(await ConfigRepository(seeded).onboarded(), isTrue);
      final a = (await BodyRepository(seeded).assessments()).single;
      expect(a.date, DateTime(2026, 9, 8));
      expect(a['peso_kg'], 82.5);
      expect(a['gordura_pct'], 13.93);
      expect(a['massa_muscular_pct'], 62.07);
      expect(metricValue(a, 'residuos_pct', p), closeTo(24, 1e-9));
      expect(bmi(a['peso_kg'], p.heightCm), closeTo(24.37, 0.01));
      expect(a.measures, hasLength(11));
      await seeded.close();
    });

    test('migração v1 → v2 mantém os dados e soma a avaliação', () async {
      sqfliteFfiInit();
      final path = '${Directory.systemTemp.createTempSync().path}/v1.db';
      final v1 = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (d, _) => migrate(d, 0, 1, personalSeed: false)));
      await v1.insert('perfil', {'id': 1, 'nome': 'Eu mesmo'});
      await v1.close();
      final v2 = await openWithFactory(databaseFactoryFfi, path);
      expect(await v2.getVersion(), 2);
      expect((await ConfigRepository(v2).profile())!.name, 'Eu mesmo');
      expect((await ConfigRepository(v2).profile())!.heightCm, 184);
      expect(await BodyRepository(v2).assessments(), hasLength(1));
      await v2.close();
    });
  });
}

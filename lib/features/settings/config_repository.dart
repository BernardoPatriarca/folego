// Configurações (tabela `config`), perfil e meta semanal de cardio.
import 'package:sqflite/sqflite.dart';

import '../../domain/dates.dart';
import '../../domain/golden_rule.dart';
import '../../domain/models.dart';

class ConfigRepository {
  ConfigRepository(this.db);
  final Database db;

  static const keyFactor = 'fator_regra';
  static const keyWindow = 'janela_sessoes';
  static const keyWeekStart = 'inicio_semana';
  static const keyOnboarded = 'onboarding_concluido';
  static const keyLastBackup = 'ultimo_backup';

  Future<String?> get(String key) async {
    final rows =
        await db.query('config', where: 'chave = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['valor'] as String;
  }

  Future<void> set(String key, String value, {DatabaseExecutor? txn}) =>
      (txn ?? db).insert('config', {'chave': key, 'valor': value},
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<GoldenRuleConfig> goldenRule() async {
    final f = double.tryParse(await get(keyFactor) ?? '') ?? 1.10;
    final w = int.tryParse(await get(keyWindow) ?? '') ?? 3;
    return GoldenRuleConfig(factor: f, window: w);
  }

  Future<void> setGoldenRule(GoldenRuleConfig c) async {
    await set(keyFactor, c.factor.toStringAsFixed(2));
    await set(keyWindow, c.window.toString());
  }

  Future<bool> weekStartsOnSunday() async =>
      (await get(keyWeekStart)) == 'domingo';

  Future<void> setWeekStartsOnSunday(bool sunday) =>
      set(keyWeekStart, sunday ? 'domingo' : 'segunda');

  Future<bool> onboarded() async => (await get(keyOnboarded)) == '1';

  Future<int> cardioWeeklyGoal() async {
    final rows = await db.query('meta_cardio_semanal');
    return rows.isEmpty ? 150 : rows.first['minutos'] as int;
  }

  Future<void> setCardioWeeklyGoal(int minutes, {DatabaseExecutor? txn}) =>
      (txn ?? db).insert('meta_cardio_semanal', {'id': 1, 'minutos': minutes},
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Profile?> profile() async {
    final rows = await db.query('perfil', where: 'id = 1');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Profile(
      name: r['nome'] as String,
      birthDate: r['data_nascimento'] == null
          ? null
          : fromIsoDate(r['data_nascimento'] as String),
      sex: r['sexo'] as String?,
      heightCm: (r['altura_cm'] as num?)?.toDouble(),
    );
  }

  Future<void> saveProfile(Profile p, {DatabaseExecutor? txn}) =>
      (txn ?? db).insert(
          'perfil',
          {
            'id': 1,
            'nome': p.name.trim(),
            'data_nascimento':
                p.birthDate == null ? null : toIsoDate(p.birthDate!),
            'sexo': p.sex,
            'altura_cm': p.heightCm,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
}

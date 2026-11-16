// Dados iniciais do dono do app: perfil e a avaliação física de 08/09/2026
// (academia). Gravados uma única vez, na criação do banco ou na migração
// para o schema 2, sem sobrescrever o que já existir.
import 'package:sqflite/sqflite.dart';

const _assessmentDate = '2026-09-08';

Future<void> seedPersonalData(DatabaseExecutor db) async {
  final profile = await db.query('perfil', where: 'id = 1');
  if (profile.isEmpty) {
    await db.insert('perfil', {'id': 1, 'nome': 'Bernardo', 'altura_cm': 184});
  } else if (profile.first['altura_cm'] == null) {
    await db.update('perfil', {'altura_cm': 184}, where: 'id = 1');
  }

  final exists = await db.query('avaliacao_corporal',
      where: 'data = ?', whereArgs: [_assessmentDate]);
  if (exists.isEmpty) {
    final id = await db.insert('avaliacao_corporal', {
      'data': _assessmentDate,
      'origem': 'academia',
      'peso_kg': 82.5,
      'altura_cm': 184,
      'gordura_pct': 13.93,
      'massa_muscular_pct': 62.07,
    });
    // Circunferências em cm e dobras em mm (valores 0 = não medido).
    const measures = {
      'Braço direito relaxado': 32.0,
      'Braço direito contraído': 34.0,
      'Coxa direita': 53.0,
      'Panturrilha direita': 35.5,
      'Abdominal': 14.0,
      'Suprailíaca': 14.0,
      'Peitoral': 7.0,
      'Tríceps': 20.0,
      'Coxa': 15.0,
      'Subescapular': 20.0,
      'Axilar média': 13.0,
    };
    for (final e in measures.entries) {
      final t = await db.query('medida_tipo',
          columns: ['id'], where: 'nome = ?', whereArgs: [e.key]);
      if (t.isEmpty) continue;
      await db.insert('medida', {
        'avaliacao_id': id,
        'medida_tipo_id': t.first['id'],
        'valor': e.value,
      });
    }
  }

  // Sem onboarding: o app já abre com os dados.
  await db.insert('config', {'chave': 'onboarding_concluido', 'valor': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace);
}

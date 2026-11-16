// Schema do banco e migrations versionadas.
//
// Para mudar o schema: crie uma entrada nova em [migrations] com a próxima
// versão e suba [schemaVersion]. Nunca edite uma migration já publicada.
import 'package:sqflite/sqflite.dart';

import 'personal_seed.dart';

const schemaVersion = 2;

/// Ordem das tabelas respeitando as chaves estrangeiras (pais primeiro).
/// Usada pelo backup para apagar (ordem inversa) e inserir.
const tablesInOrder = [
  'perfil',
  'exercicio',
  'treino_dia',
  'meta',
  'cardio',
  'meta_cardio_semanal',
  'recorde',
  'avaliacao_corporal',
  'medida_tipo',
  'medida',
  'meta_corporal',
  'config',
];

final Map<int, List<String>> migrations = {
  1: [
    '''
CREATE TABLE perfil (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  nome TEXT NOT NULL,
  data_nascimento TEXT,
  sexo TEXT CHECK (sexo IN ('M','F')),
  altura_cm REAL
)''',
    '''
CREATE TABLE exercicio (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL UNIQUE,
  unidade TEXT NOT NULL CHECK (unidade IN ('reps','seg')),
  grupo TEXT,
  ativo INTEGER NOT NULL DEFAULT 1,
  ordem INTEGER NOT NULL DEFAULT 0
)''',
    '''
CREATE TABLE treino_dia (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  data TEXT NOT NULL UNIQUE,
  descanso INTEGER NOT NULL DEFAULT 0,
  observacao TEXT
)''',
    '''
CREATE TABLE meta (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  treino_dia_id INTEGER NOT NULL REFERENCES treino_dia(id) ON DELETE CASCADE,
  exercicio_id INTEGER NOT NULL REFERENCES exercicio(id),
  alvo REAL NOT NULL,
  series INTEGER,
  realizado REAL,
  esforco INTEGER CHECK (esforco BETWEEN 1 AND 10),
  ousada INTEGER NOT NULL DEFAULT 0,
  UNIQUE (treino_dia_id, exercicio_id)
)''',
    '''
CREATE TABLE cardio (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  treino_dia_id INTEGER NOT NULL REFERENCES treino_dia(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL,
  duracao_min REAL NOT NULL,
  kcal REAL,
  fc_media INTEGER,
  fc_max INTEGER,
  distancia_km REAL,
  passos INTEGER,
  observacao TEXT
)''',
    '''
CREATE TABLE meta_cardio_semanal (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  minutos INTEGER NOT NULL DEFAULT 150
)''',
    '''
CREATE TABLE recorde (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  exercicio_id INTEGER NOT NULL REFERENCES exercicio(id),
  valor REAL NOT NULL,
  data TEXT NOT NULL,
  meta_id INTEGER REFERENCES meta(id) ON DELETE SET NULL
)''',
    '''
CREATE TABLE avaliacao_corporal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  data TEXT NOT NULL,
  origem TEXT,
  peso_kg REAL,
  altura_cm REAL,
  gordura_pct REAL,
  massa_gorda_kg REAL,
  massa_magra_kg REAL,
  massa_muscular_kg REAL,
  massa_ossea_kg REAL,
  agua_pct REAL,
  proteina_pct REAL,
  gordura_visceral REAL,
  tmb_kcal REAL,
  idade_metabolica INTEGER,
  fc_repouso INTEGER,
  pressao_sistolica INTEGER,
  pressao_diastolica INTEGER,
  observacao TEXT
)''',
    '''
CREATE TABLE medida_tipo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL UNIQUE,
  unidade TEXT NOT NULL,
  categoria TEXT NOT NULL CHECK (categoria IN ('circunferencia','dobra','outro')),
  ativo INTEGER NOT NULL DEFAULT 1,
  ordem INTEGER NOT NULL DEFAULT 0
)''',
    '''
CREATE TABLE medida (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  avaliacao_id INTEGER NOT NULL REFERENCES avaliacao_corporal(id) ON DELETE CASCADE,
  medida_tipo_id INTEGER NOT NULL REFERENCES medida_tipo(id),
  valor REAL NOT NULL,
  UNIQUE (avaliacao_id, medida_tipo_id)
)''',
    '''
CREATE TABLE meta_corporal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  metrica TEXT NOT NULL,
  valor_alvo REAL NOT NULL,
  data_alvo TEXT,
  ativa INTEGER NOT NULL DEFAULT 1
)''',
    '''
CREATE TABLE config (
  chave TEXT PRIMARY KEY,
  valor TEXT NOT NULL
)''',
    'CREATE INDEX idx_treino_dia_data ON treino_dia(data)',
    'CREATE INDEX idx_meta_exercicio ON meta(exercicio_id)',
    'CREATE INDEX idx_avaliacao_data ON avaliacao_corporal(data)',
    'CREATE INDEX idx_recorde_exercicio ON recorde(exercicio_id)',
    'CREATE INDEX idx_cardio_dia ON cardio(treino_dia_id)',
    'CREATE INDEX idx_medida_avaliacao ON medida(avaliacao_id)',
  ],
  // v2: massa muscular em percentual (como na avaliação da academia).
  2: [
    'ALTER TABLE avaliacao_corporal ADD COLUMN massa_muscular_pct REAL',
  ],
};

/// Exercícios iniciais: (nome, unidade, grupo).
const seedExercises = [
  ('Flexão', 'reps', 'peito'),
  ('Flexão diamante', 'reps', 'braços'),
  ('Agachamento', 'reps', 'pernas'),
  ('Afundo', 'reps', 'pernas'),
  ('Barra fixa', 'reps', 'costas'),
  ('Mergulho', 'reps', 'braços'),
  ('Abdominal', 'reps', 'core'),
  ('Prancha', 'seg', 'core'),
  ('Prancha lateral', 'seg', 'core'),
  ('Burpee', 'reps', 'corpo todo'),
  ('Polichinelo', 'reps', 'corpo todo'),
];

const seedCircumferences = [
  'Pescoço',
  'Ombros',
  'Peito',
  'Braço direito relaxado',
  'Braço esquerdo relaxado',
  'Braço direito contraído',
  'Braço esquerdo contraído',
  'Antebraço',
  'Cintura',
  'Abdômen',
  'Quadril',
  'Coxa direita',
  'Coxa esquerda',
  'Panturrilha direita',
  'Panturrilha esquerda',
];

const seedSkinfolds = [
  'Peitoral',
  'Axilar média',
  'Tríceps',
  'Subescapular',
  'Abdominal',
  'Suprailíaca',
  'Coxa',
];

const seedConfig = {
  'fator_regra': '1.10',
  'janela_sessoes': '3',
  'inicio_semana': 'segunda',
};

/// Dados iniciais da versão 1.
Future<void> seedV1(DatabaseExecutor db) async {
  final batch = db.batch();
  for (var i = 0; i < seedExercises.length; i++) {
    final (nome, unidade, grupo) = seedExercises[i];
    batch.insert('exercicio',
        {'nome': nome, 'unidade': unidade, 'grupo': grupo, 'ordem': i});
  }
  var ordem = 0;
  for (final nome in seedCircumferences) {
    batch.insert('medida_tipo', {
      'nome': nome,
      'unidade': 'cm',
      'categoria': 'circunferencia',
      'ordem': ordem++,
    });
  }
  for (final nome in seedSkinfolds) {
    batch.insert('medida_tipo', {
      'nome': nome,
      'unidade': 'mm',
      'categoria': 'dobra',
      'ordem': ordem++,
    });
  }
  batch.insert('meta_cardio_semanal', {'id': 1, 'minutos': 150});
  seedConfig.forEach((k, v) => batch.insert('config', {'chave': k, 'valor': v}));
  await batch.commit(noResult: true);
}

/// Aplica as migrations de [from] (exclusive) até [to] (inclusive).
///
/// [personalSeed] grava os dados iniciais do dono (desligado nos testes).
Future<void> migrate(DatabaseExecutor db, int from, int to,
    {bool personalSeed = true}) async {
  for (var v = from + 1; v <= to; v++) {
    for (final sql in migrations[v] ?? const <String>[]) {
      await db.execute(sql);
    }
    if (v == 1) await seedV1(db);
  }
  if (personalSeed && from < 2 && to >= 2) await seedPersonalData(db);
}

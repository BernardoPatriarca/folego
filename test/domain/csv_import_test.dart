import 'package:flutter_test/flutter_test.dart';
import 'package:folego/domain/csv_import.dart';

void main() {
  final header = csvFixedColumns.join(';');
  const known = {'Cintura', 'Braço direito contraído'};

  test('modelo tem o cabeçalho da especificação', () {
    expect(csvTemplate().trim(),
        'data;origem;peso_kg;altura_cm;gordura_pct;massa_gorda_kg;'
        'massa_magra_kg;massa_muscular_kg;massa_ossea_kg;agua_pct;'
        'proteina_pct;gordura_visceral;tmb_kcal;idade_metabolica;fc_repouso;'
        'pressao_sistolica;pressao_diastolica;observacao');
  });

  test('vírgula e ponto decimais, datas BR e ISO, campos vazios', () {
    final csv = '$header\n'
        '10/01/2026;balança;82,4;;22,5;;;;;;;;;;;;;\n'
        '2026-02-10;academia;81.2;178;21.9;;;35,1;;;;;1750;;58;120;80;ok\n';
    final r = parseAssessmentCsv(csv, known);
    expect(r.fatal, isNull);
    expect(r.errors, isEmpty);
    expect(r.rows, hasLength(2));
    expect(r.rows[0].date, DateTime(2026, 1, 10));
    expect(r.rows[0].values, {'peso_kg': 82.4, 'gordura_pct': 22.5});
    expect(r.rows[0].origin, 'balança');
    expect(r.rows[1].date, DateTime(2026, 2, 10));
    expect(r.rows[1].values['massa_muscular_kg'], 35.1);
    expect(r.rows[1].values['tmb_kcal'], 1750);
    expect(r.rows[1].values['pressao_diastolica'], 80);
    expect(r.rows[1].note, 'ok');
  });

  test('colunas extras: conhecidas e desconhecidas', () {
    final csv = '$header;Cintura;Braço direito contraído;Punho\n'
        '01/03/2026;;80;;;;;;;;;;;;;;;;88,5;36;17\n';
    final r = parseAssessmentCsv(csv, known);
    expect(r.extraColumns, ['Cintura', 'Braço direito contraído', 'Punho']);
    expect(r.unknownColumns, ['Punho']);
    expect(r.rows.single.measures,
        {'Cintura': 88.5, 'Braço direito contraído': 36, 'Punho': 17});
  });

  test('nome de medida sem diferenciar maiúsculas', () {
    final csv = 'data;cintura\n01/03/2026;88\n';
    final r = parseAssessmentCsv(csv, known);
    expect(r.unknownColumns, isEmpty);
    expect(r.rows.single.measures, {'cintura': 88});
  });

  test('linhas inválidas com o motivo', () {
    final csv = '$header\n'
        '31/02/2026;;80;;;;;;;;;;;;;;;\n' // data impossível
        ';;80;;;;;;;;;;;;;;;\n' // data vazia
        '01/03/2026;;oitenta;;;;;;;;;;;;;;;\n' // não é número
        '02/03/2026;;-80;;;;;;;;;;;;;;;\n' // negativo
        '03/03/2026;;500;;;;;;;;;;;;;;;\n' // peso fora da faixa
        '04/03/2026;;80;90;;;;;;;;;;;;;;\n' // altura fora da faixa
        '05/03/2026;só origem;;;;;;;;;;;;;;;;\n' // nada preenchido
        '06/03/2026;;80;;;;;;;;;;;;;;;\n'; // válida
    final r = parseAssessmentCsv(csv, known);
    expect(r.rows, hasLength(1));
    expect(r.rows.single.date, DateTime(2026, 3, 6));
    expect(r.errors.map((e) => e.line), [2, 3, 4, 5, 6, 7, 8]);
    expect(r.errors[0].message, contains('inválida'));
    expect(r.errors[1].message, 'data vazia');
    expect(r.errors[2].message, contains('não é um número'));
    expect(r.errors[3].message, contains('negativo'));
    expect(r.errors[4].message, contains('Peso fora da faixa'));
    expect(r.errors[5].message, contains('Altura fora da faixa'));
    expect(r.errors[6].message, 'nenhum valor preenchido');
  });

  test('BOM, CRLF, aspas e linhas em branco', () {
    final csv = '﻿data;origem;peso_kg;observacao\r\n'
        '\r\n'
        '01/03/2026;"balança; casa";80;"disse ""ok"""\r\n';
    final r = parseAssessmentCsv(csv, known);
    expect(r.rows.single.origin, 'balança; casa');
    expect(r.rows.single.note, 'disse "ok"');
  });

  test('erros fatais', () {
    expect(parseAssessmentCsv('', known).fatal, 'Arquivo vazio.');
    expect(parseAssessmentCsv('peso_kg;origem\n80;x', known).fatal,
        contains('coluna "data"'));
    expect(parseAssessmentCsv('data,peso_kg\n01/01/2026,80', known).fatal,
        contains('ponto e vírgula'));
  });

  test('datas repetidas no arquivo', () {
    final r = parseAssessmentCsv(
        'data;peso_kg\n01/03/2026;80\n2026-03-01;81\n02/03/2026;80', known);
    expect(duplicatedDates(r.rows), {DateTime(2026, 3, 1)});
  });

  test('parseCsvDate', () {
    expect(parseCsvDate('1/2/2026'), DateTime(2026, 2, 1));
    expect(parseCsvDate('2026-2-1'), DateTime(2026, 2, 1));
    expect(parseCsvDate('2026/02/01'), isNull);
    expect(parseCsvDate('29/02/2025'), isNull);
    expect(parseCsvDate('29/02/2028'), DateTime(2028, 2, 29));
  });
}

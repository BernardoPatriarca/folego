// Importação de avaliações corporais por CSV (seção 8).
//
// Formato: separador `;`, decimal com vírgula ou ponto, data DD/MM/AAAA ou
// AAAA-MM-DD, campos vazios ignorados. Depois das colunas fixas, colunas
// extras com o nome exato de um tipo de medida.
import 'body_metrics.dart';
import 'dates.dart';
import 'numbers.dart';

/// Cabeçalho fixo do modelo CSV.
const csvFixedColumns = [
  'data',
  'origem',
  'peso_kg',
  'altura_cm',
  'gordura_pct',
  'massa_gorda_kg',
  'massa_magra_kg',
  'massa_muscular_kg',
  'massa_muscular_pct',
  'massa_ossea_kg',
  'agua_pct',
  'proteina_pct',
  'gordura_visceral',
  'tmb_kcal',
  'idade_metabolica',
  'fc_repouso',
  'pressao_sistolica',
  'pressao_diastolica',
  'observacao',
];

String csvTemplate() => '${csvFixedColumns.join(';')}\n';

/// Uma linha válida do CSV.
class CsvAssessmentRow {
  const CsvAssessmentRow({
    required this.line,
    required this.date,
    this.origin,
    this.note,
    required this.values,
    required this.measures,
  });

  /// Número da linha no arquivo (1 = cabeçalho).
  final int line;
  final DateTime date;
  final String? origin;
  final String? note;
  final Map<String, double> values;

  /// Medidas pelo nome da coluna (nome do tipo de medida).
  final Map<String, double> measures;
}

class CsvLineError {
  const CsvLineError(this.line, this.message);
  final int line;
  final String message;

  @override
  String toString() => 'Linha $line: $message';
}

class CsvParseResult {
  const CsvParseResult({
    required this.rows,
    required this.errors,
    required this.extraColumns,
    required this.unknownColumns,
    this.fatal,
  });

  final List<CsvAssessmentRow> rows;
  final List<CsvLineError> errors;

  /// Todas as colunas extras (medidas) presentes no cabeçalho.
  final List<String> extraColumns;

  /// Colunas extras que não existem no catálogo de medidas.
  final List<String> unknownColumns;

  /// Erro que impede a leitura do arquivo inteiro (ex.: sem coluna `data`).
  final String? fatal;
}

/// Lê data em DD/MM/AAAA ou AAAA-MM-DD. Devolve `null` se inválida.
DateTime? parseCsvDate(String s) {
  final t = s.trim();
  RegExpMatch? m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t);
  int y, mo, d;
  if (m != null) {
    d = int.parse(m.group(1)!);
    mo = int.parse(m.group(2)!);
    y = int.parse(m.group(3)!);
  } else {
    m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
    if (m == null) return null;
    y = int.parse(m.group(1)!);
    mo = int.parse(m.group(2)!);
    d = int.parse(m.group(3)!);
  }
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, mo, d);
  // DateTime "normaliza" 31/02 para março: rejeita.
  if (date.month != mo || date.day != d) return null;
  return date;
}

/// Divide uma linha por `;`, respeitando aspas duplas.
List<String> splitCsvLine(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (ch == ';' && !quoted) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}

/// Lê o CSV. [knownMeasures] são os nomes dos tipos de medida do catálogo
/// (comparação exata, sem diferenciar maiúsculas).
CsvParseResult parseAssessmentCsv(String content, Set<String> knownMeasures) {
  var text = content;
  if (text.startsWith('﻿')) text = text.substring(1);
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final headerIndex = lines.indexWhere((l) => l.trim().isNotEmpty);
  if (headerIndex < 0) {
    return const CsvParseResult(
        rows: [],
        errors: [],
        extraColumns: [],
        unknownColumns: [],
        fatal: 'Arquivo vazio.');
  }
  final header = splitCsvLine(lines[headerIndex]).map((h) => h.trim()).toList();
  if (header.length < 2 && lines[headerIndex].contains(',')) {
    return const CsvParseResult(
        rows: [],
        errors: [],
        extraColumns: [],
        unknownColumns: [],
        fatal: 'O separador precisa ser ponto e vírgula (;).');
  }
  final lower = header.map((h) => h.toLowerCase()).toList();
  final dateCol = lower.indexOf('data');
  if (dateCol < 0) {
    return const CsvParseResult(
        rows: [],
        errors: [],
        extraColumns: [],
        unknownColumns: [],
        fatal: 'Cabeçalho sem a coluna "data". Use o modelo CSV.');
  }

  final fixed = csvFixedColumns.toSet();
  final knownLower = {for (final k in knownMeasures) k.toLowerCase(): k};
  final extra = <String>[];
  final unknown = <String>[];
  for (var i = 0; i < header.length; i++) {
    final h = header[i];
    if (h.isEmpty || fixed.contains(lower[i])) continue;
    extra.add(h);
    if (!knownLower.containsKey(h.toLowerCase())) unknown.add(h);
  }

  final rows = <CsvAssessmentRow>[];
  final errors = <CsvLineError>[];
  for (var li = headerIndex + 1; li < lines.length; li++) {
    final raw = lines[li];
    if (raw.trim().isEmpty || raw.replaceAll(';', '').trim().isEmpty) continue;
    final lineNo = li + 1;
    final cells = splitCsvLine(raw);
    String cell(int i) => i < cells.length ? cells[i].trim() : '';

    final dateText = cell(dateCol);
    if (dateText.isEmpty) {
      errors.add(CsvLineError(lineNo, 'data vazia'));
      continue;
    }
    final date = parseCsvDate(dateText);
    if (date == null) {
      errors.add(CsvLineError(
          lineNo, 'data "$dateText" inválida (use DD/MM/AAAA ou AAAA-MM-DD)'));
      continue;
    }

    final values = <String, double>{};
    final measures = <String, double>{};
    String? origin, note, problem;
    for (var i = 0; i < header.length && problem == null; i++) {
      if (i == dateCol) continue;
      final key = lower[i];
      final v = cell(i);
      if (v.isEmpty || header[i].isEmpty) continue;
      if (key == 'origem') {
        origin = v;
        continue;
      }
      if (key == 'observacao') {
        note = v;
        continue;
      }
      final number = parseDecimal(v);
      if (number == null) {
        problem = '"${header[i]}" com valor "$v" não é um número';
        break;
      }
      if (number < 0) {
        problem = '"${header[i]}" não pode ser negativo';
        break;
      }
      final metric = bodyMetricByKey[key];
      if (metric != null) {
        if (number < metric.min || number > metric.max) {
          problem = '${metric.label} fora da faixa '
              '(${_fmt(metric.min)} a ${_fmt(metric.max)} ${metric.unit})'
              .replaceAll(' )', ')');
          break;
        }
        values[metric.key] = metric.isInt ? number.roundToDouble() : number;
      } else {
        measures[header[i]] = number;
      }
    }
    if (problem != null) {
      errors.add(CsvLineError(lineNo, problem));
      continue;
    }
    if (values.isEmpty && measures.isEmpty) {
      errors.add(CsvLineError(lineNo, 'nenhum valor preenchido'));
      continue;
    }
    rows.add(CsvAssessmentRow(
      line: lineNo,
      date: date,
      origin: origin,
      note: note,
      values: values,
      measures: measures,
    ));
  }
  return CsvParseResult(
    rows: rows,
    errors: errors,
    extraColumns: extra,
    unknownColumns: unknown,
  );
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Datas repetidas dentro do próprio arquivo (útil para a pré-visualização).
Set<DateTime> duplicatedDates(List<CsvAssessmentRow> rows) {
  final seen = <String>{};
  final dup = <DateTime>{};
  for (final r in rows) {
    if (!seen.add(toIsoDate(r.date))) dup.add(r.date);
  }
  return dup;
}

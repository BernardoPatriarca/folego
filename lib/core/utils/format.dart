// Formatação no padrão brasileiro: `72,4 kg`, `1.240 reps`, `16/11/2026`.
import 'package:intl/intl.dart';

import '../../domain/models.dart';

const _locale = 'pt_BR';

/// Número com até [decimals] casas (sem zeros desnecessários se [trim]).
String fmtNum(num? v, {int decimals = 1, bool trim = true}) {
  if (v == null) return '–';
  final pattern = decimals == 0
      ? '#,##0'
      : trim
          ? '#,##0.${'#' * decimals}'
          : '#,##0.${'0' * decimals}';
  return NumberFormat(pattern, _locale).format(v);
}

/// Número com sinal explícito: `+1,2` / `−0,6` (sinal de menos tipográfico).
String fmtSigned(num v, {int decimals = 1}) {
  final rounded = double.parse(v.toStringAsFixed(decimals));
  if (rounded == 0) return '0';
  final s = fmtNum(rounded.abs(), decimals: decimals);
  return rounded > 0 ? '+$s' : '−$s';
}

String fmtPct(double? fraction) =>
    fraction == null ? '–' : '${fmtNum(fraction * 100, decimals: 0)}%';

/// Valor de exercício com unidade: `30 reps` ou `45 s`.
String fmtExercise(num v, ExerciseUnit unit) =>
    '${fmtNum(v, decimals: 0)} ${unit.short}';

String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy', _locale).format(d);

String fmtDateShort(DateTime d) => DateFormat('dd/MM', _locale).format(d);

/// "segunda, 16 de novembro".
String fmtDateLong(DateTime d) =>
    DateFormat("EEEE, d 'de' MMMM", _locale).format(d);

/// "nov/26".
String fmtMonthShort(DateTime d) =>
    DateFormat('MMM/yy', _locale).format(d).replaceAll('.', '');

String fmtMonthYear(DateTime d) => DateFormat('MMMM yyyy', _locale).format(d);

/// Minutos como "1h 25min" ou "40 min".
String fmtMinutes(num minutes) {
  final total = minutes.round();
  if (total < 60) return '$total min';
  final h = total ~/ 60, m = total % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}min';
}

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Para campos de texto: 72.4 → "72,4"; 30.0 → "30".
String numToField(num? v) {
  if (v == null) return '';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().replaceAll('.', ',');
}

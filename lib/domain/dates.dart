// Datas sem hora. No banco ficam como texto ISO (`AAAA-MM-DD`).

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String toIsoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime fromIsoDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Primeiro dia do mês.
DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

/// Início da semana que contém [d]. [startsOnSunday] = semana de domingo a
/// sábado; senão, segunda a domingo.
DateTime weekStart(DateTime d, {bool startsOnSunday = false}) {
  final day = dateOnly(d);
  // DateTime.weekday: 1 = segunda ... 7 = domingo.
  final offset = startsOnSunday ? day.weekday % 7 : day.weekday - 1;
  return addDays(day, -offset);
}

/// Idade completa em anos em [today].
int ageOn(DateTime birth, DateTime today) {
  var age = today.year - birth.year;
  if (today.month < birth.month ||
      (today.month == birth.month && today.day < birth.day)) {
    age--;
  }
  return age;
}

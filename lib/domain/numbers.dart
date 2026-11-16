// Leitura de números digitados no formato brasileiro (ou com ponto).

/// Converte "72,4", "72.4", "1.234,5" ou "1234.5" em double.
///
/// Regras: se tiver vírgula, ela é o decimal e os pontos são milhar. Sem
/// vírgula, um único ponto é decimal; vários pontos são milhar.
/// Devolve `null` para texto vazio ou inválido.
double? parseDecimal(String? input) {
  if (input == null) return null;
  var s = input.trim().replaceAll(' ', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if ('.'.allMatches(s).length > 1) {
    s = s.replaceAll('.', '');
  }
  if (!RegExp(r'^[+-]?\d+(\.\d+)?$').hasMatch(s) &&
      !RegExp(r'^[+-]?\d*\.\d+$').hasMatch(s)) {
    return null;
  }
  return double.tryParse(s);
}

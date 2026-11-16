// Validações de formulário (seção 9). Devolvem a mensagem de erro em
// português ou `null` quando o valor é válido.
import 'numbers.dart';

String? validateNumber(
  String? text, {
  bool required = false,
  double min = 0,
  double? max,
  bool integer = false,
  String unit = '',
}) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return required ? 'Campo obrigatório' : null;
  final v = parseDecimal(t);
  if (v == null) return 'Número inválido';
  if (v < 0) return 'Não pode ser negativo';
  if (integer && v != v.roundToDouble()) return 'Use um número inteiro';
  final u = unit.isEmpty ? '' : ' $unit';
  if (max != null && (v < min || v > max)) {
    return 'Use um valor entre ${_n(min)} e ${_n(max)}$u';
  }
  if (v < min) return 'Mínimo ${_n(min)}$u';
  return null;
}

String? validateWeight(String? text, {bool required = false}) =>
    validateNumber(text, required: required, min: 20, max: 400, unit: 'kg');

String? validateHeight(String? text, {bool required = false}) =>
    validateNumber(text, required: required, min: 100, max: 250, unit: 'cm');

String? validateEffort(int? effort) {
  if (effort == null) return null;
  if (effort < 1 || effort > 10) return 'O esforço vai de 1 a 10';
  return null;
}

String _n(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

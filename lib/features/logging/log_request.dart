// Pedido para abrir a aba Lançar já com exercício e data escolhidos
// (ex.: ao tocar numa meta na tela Hoje).
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogRequest {
  const LogRequest({this.exerciseId, required this.date, this.cardio = false});
  final int? exerciseId;
  final DateTime date;
  final bool cardio;
}

class LogRequestController extends Notifier<LogRequest?> {
  @override
  LogRequest? build() => null;

  void request(LogRequest r) => state = r;
  void consume() => state = null;
}

final logRequestProvider =
    NotifierProvider<LogRequestController, LogRequest?>(
        LogRequestController.new);

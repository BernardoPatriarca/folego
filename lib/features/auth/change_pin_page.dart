// Trocar PIN: atual → novo → confirmação.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import 'pin_pad.dart';
import 'pin_service.dart';

class ChangePinPage extends ConsumerStatefulWidget {
  const ChangePinPage({super.key});

  @override
  ConsumerState<ChangePinPage> createState() => _ChangePinPageState();
}

enum _Step { current, fresh, confirm }

class _ChangePinPageState extends ConsumerState<ChangePinPage> {
  _Step _step = _Step.current;
  String? _newPin;
  String? _error;

  Future<void> _submit(String pin) async {
    final service = ref.read(pinServiceProvider);
    switch (_step) {
      case _Step.current:
        final r = await service.verify(pin);
        if (!mounted) return;
        setState(() {
          switch (r) {
            case PinOk():
              _step = _Step.fresh;
              _error = null;
            case PinWrong(:final attemptsLeft):
              _error = 'PIN incorreto. Restam $attemptsLeft tentativas.';
            case PinLocked():
              _error = 'Muitas tentativas. Aguarde 30 s.';
          }
        });
      case _Step.fresh:
        setState(() {
          _newPin = pin;
          _step = _Step.confirm;
          _error = null;
        });
      case _Step.confirm:
        if (pin != _newPin) {
          setState(() {
            _step = _Step.fresh;
            _newPin = null;
            _error = 'Os PINs não conferem. Tente de novo.';
          });
          return;
        }
        await service.setPin(pin);
        if (!mounted) return;
        showMessage(context, 'PIN alterado.', icon: Icons.lock);
        context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _Step.current => ('PIN atual', 'Digite o PIN que você usa hoje'),
      _Step.fresh => ('Novo PIN', 'De 4 a 6 dígitos'),
      _Step.confirm => ('Confirme', 'Digite o novo PIN de novo'),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('TROCAR PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PinPad(
            key: ValueKey(_step),
            title: title,
            subtitle: subtitle,
            error: _error,
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

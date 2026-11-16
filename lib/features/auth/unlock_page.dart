// Tela de desbloqueio com PIN (abertura e volta do segundo plano).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import 'lock_controller.dart';
import 'pin_pad.dart';
import 'pin_service.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  String? _error;
  DateTime? _lockedUntil;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkLock() async {
    final until = await ref.read(pinServiceProvider).lockedUntil();
    if (until != null && mounted) _startCountdown(until);
  }

  void _startCountdown(DateTime until) {
    _timer?.cancel();
    setState(() => _lockedUntil = until);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!DateTime.now().isBefore(until)) {
        _timer?.cancel();
        setState(() {
          _lockedUntil = null;
          _error = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _submit(String pin) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await ref.read(pinServiceProvider).verify(pin);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case PinOk():
        ref.read(lockControllerProvider.notifier).unlock();
      case PinWrong(:final attemptsLeft):
        setState(() => _error = attemptsLeft == 1
            ? 'PIN incorreto. Resta 1 tentativa.'
            : 'PIN incorreto. Restam $attemptsLeft tentativas.');
      case PinLocked(:final until):
        _startCountdown(until);
    }
  }

  @override
  Widget build(BuildContext context) {
    final until = _lockedUntil;
    final seconds = until == null
        ? 0
        : until.difference(DateTime.now()).inSeconds.clamp(0, 30) + 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, size: 48, color: FolegoColors.lime),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PinPad(
                      title: 'Fôlego',
                      subtitle: 'Digite seu PIN',
                      enabled: until == null && !_busy,
                      error: until != null
                          ? 'Muitas tentativas. Aguarde $seconds s.'
                          : _error,
                      onSubmit: _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

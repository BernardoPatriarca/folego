// Estado de bloqueio do app: onboarding, PIN ou liberado.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

enum AppLockState { loading, onboarding, locked, unlocked }

/// Tempo em segundo plano que exige o PIN de novo.
const relockAfter = Duration(minutes: 2);

class LockController extends Notifier<AppLockState> {
  DateTime? _backgroundedAt;

  @override
  AppLockState build() => AppLockState.loading;

  Future<void> init() async {
    final hasPin = await ref.read(pinServiceProvider).hasPin();
    final onboarded = await ref.read(configRepositoryProvider).onboarded();
    state = (hasPin && onboarded) ? AppLockState.locked : AppLockState.onboarding;
  }

  void unlock() => state = AppLockState.unlocked;

  void lock() {
    if (state == AppLockState.unlocked) state = AppLockState.locked;
  }

  void onBackground() {
    _backgroundedAt ??= ref.read(clockProvider)();
  }

  void onForeground() {
    final at = _backgroundedAt;
    _backgroundedAt = null;
    if (at == null) return;
    if (ref.read(clockProvider)().difference(at) >= relockAfter) lock();
  }
}

final lockControllerProvider =
    NotifierProvider<LockController, AppLockState>(LockController.new);

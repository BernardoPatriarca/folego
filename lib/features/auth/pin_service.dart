// PIN do app: hash SHA-256 com salt aleatório, guardado no cofre seguro.
//
// Depois de 5 erros seguidos, o PIN fica bloqueado por 30 s (o bloqueio é
// persistido, então fechar e abrir o app não zera a espera).
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Armazenamento chave/valor do PIN. Abstraído para os testes.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore();
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemorySecureStore implements SecureStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

sealed class PinCheck {
  const PinCheck();
}

class PinOk extends PinCheck {
  const PinOk();
}

class PinWrong extends PinCheck {
  const PinWrong(this.attemptsLeft);
  final int attemptsLeft;
}

class PinLocked extends PinCheck {
  const PinLocked(this.until);
  final DateTime until;
}

class PinService {
  PinService(this.store, {DateTime Function()? clock, Random? random})
      : _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure();

  final SecureStore store;
  final DateTime Function() _clock;
  final Random _random;

  static const maxAttempts = 5;
  static const lockDuration = Duration(seconds: 30);

  static const _kHash = 'pin_hash';
  static const _kSalt = 'pin_salt';
  static const _kFails = 'pin_erros';
  static const _kLockedUntil = 'pin_bloqueado_ate';

  Future<bool> hasPin() async => (await store.read(_kHash)) != null;

  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final salt = base64Url
        .encode(List<int>.generate(16, (_) => _random.nextInt(256)));
    await store.write(_kSalt, salt);
    await store.write(_kHash, hashPin(pin, salt));
    await store.delete(_kFails);
    await store.delete(_kLockedUntil);
  }

  /// Bloqueio ativo agora, se houver.
  Future<DateTime?> lockedUntil() async {
    final v = await store.read(_kLockedUntil);
    if (v == null) return null;
    final until = DateTime.tryParse(v);
    if (until == null || !until.isAfter(_clock())) return null;
    return until;
  }

  Future<PinCheck> verify(String pin) async {
    final locked = await lockedUntil();
    if (locked != null) return PinLocked(locked);
    final salt = await store.read(_kSalt);
    final hash = await store.read(_kHash);
    if (salt != null && hash != null && hashPin(pin, salt) == hash) {
      await store.delete(_kFails);
      await store.delete(_kLockedUntil);
      return const PinOk();
    }
    final fails = (int.tryParse(await store.read(_kFails) ?? '') ?? 0) + 1;
    if (fails >= maxAttempts) {
      final until = _clock().add(lockDuration);
      await store.write(_kLockedUntil, until.toIso8601String());
      await store.delete(_kFails);
      return PinLocked(until);
    }
    await store.write(_kFails, '$fails');
    return PinWrong(maxAttempts - fails);
  }
}

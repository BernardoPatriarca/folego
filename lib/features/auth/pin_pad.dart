// Teclado numérico próprio para o PIN (4 a 6 dígitos).
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.enabled = true,
    this.error,
  });

  final String title;
  final String? subtitle;

  /// Chamado ao tocar em OK com 4 a 6 dígitos.
  final ValueChanged<String> onSubmit;
  final bool enabled;
  final String? error;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  static const maxLength = 6;
  static const minLength = 4;
  String _pin = '';

  void clear() => setState(() => _pin = '');

  void _tap(String d) {
    if (!widget.enabled || _pin.length >= maxLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _ok() {
    if (!widget.enabled || _pin.length < minLength) return;
    final pin = _pin;
    setState(() => _pin = '');
    widget.onSubmit(pin);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, c) {
      final keySize = ((c.maxWidth - 64) / 3).clamp(56.0, 84.0);
      return SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.title.toUpperCase(),
                textAlign: TextAlign.center, style: t.headlineSmall),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(widget.subtitle!,
                  textAlign: TextAlign.center, style: t.bodyMedium),
            ],
            const SizedBox(height: 24),
            Semantics(
              label: '${_pin.length} de $maxLength dígitos digitados',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < maxLength; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? FolegoColors.lime
                            : Colors.transparent,
                        border: Border.all(
                            color: i < minLength
                                ? FolegoColors.textSecondary
                                : FolegoColors.border,
                            width: 2),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: Center(
                child: widget.error == null
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: FolegoColors.bold, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(widget.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: FolegoColors.bold)),
                          ),
                        ],
                      ),
              ),
            ),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['<', '0', 'ok'],
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (final k in row) _key(k, keySize)],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _key(String k, double size) {
    Widget child;
    VoidCallback? onTap;
    String label;
    Color bg = FolegoColors.surface;
    Color fg = FolegoColors.text;
    if (k == '<') {
      child = const Icon(Icons.backspace_outlined);
      onTap = _back;
      label = 'Apagar';
    } else if (k == 'ok') {
      final ready = _pin.length >= minLength && widget.enabled;
      child = const Icon(Icons.check);
      onTap = ready ? _ok : null;
      label = 'Confirmar';
      bg = ready ? FolegoColors.lime : FolegoColors.surface;
      fg = ready ? FolegoColors.onLime : FolegoColors.textSecondary;
    } else {
      child = Text(k, style: numberStyle(28));
      onTap = () => _tap(k);
      label = k;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                  child: IconTheme(
                      data: IconThemeData(color: fg), child: child)),
            ),
          ),
        ),
      ),
    );
  }
}

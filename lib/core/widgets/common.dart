// Widgets reutilizados por várias telas.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../utils/format.dart';

/// Título de seção em Oswald caixa-alta.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: const TextStyle(
                  fontFamily: headingFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: FolegoColors.textSecondary,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Cartão padrão (superfície com borda e cantos de 20 px).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Número grande com rótulo, lido por inteiro pelo leitor de tela.
class BigStat extends StatelessWidget {
  const BigStat({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.semanticsLabel,
    this.size = 32,
    this.color = FolegoColors.text,
    this.footer,
  });

  final String label;
  final String value;
  final String? unit;
  final String? semanticsLabel;
  final double size;
  final Color color;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? '$label, $value ${unit ?? ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: numberStyle(size, color: color)),
              if (unit != null && unit!.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: numberStyle(size * 0.5,
                      color: FolegoColors.textSecondary,
                      weight: FontWeight.w400),
                ),
            ]),
          ),
          if (footer != null) ...[const SizedBox(height: 4), footer!],
        ],
      ),
    );
  }
}

/// Barra de progresso arredondada.
class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.height = 8, this.color});
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color ?? FolegoColors.lime,
        backgroundColor: FolegoColors.surfaceHigh,
      ),
    );
  }
}

/// Selo de meta ousada: cor + ícone + texto (nunca só a cor).
class BoldTag extends StatelessWidget {
  const BoldTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: FolegoColors.bold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FolegoColors.bold),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 14, color: FolegoColors.bold),
          SizedBox(width: 4),
          Text('OUSADA',
              style: TextStyle(
                  fontFamily: headingFont,
                  fontSize: 12,
                  letterSpacing: 1,
                  color: FolegoColors.bold)),
        ],
      ),
    );
  }
}

/// Aviso laranja com ícone (meta ousada etc.).
class WarningLine extends StatelessWidget {
  const WarningLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded,
            color: FolegoColors.bold, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: FolegoColors.bold, fontSize: 14)),
        ),
      ],
    );
  }
}

/// Estado vazio amigável.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: FolegoColors.textSecondary),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FolegoColors.textSecondary)),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Aviso discreto dos cálculos corporais.
class HealthDisclaimer extends StatelessWidget {
  const HealthDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: FolegoColors.textSecondary),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Valores informativos, não substituem avaliação profissional.',
              style: TextStyle(fontSize: 12, color: FolegoColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Variação com sinal e unidade: "−0,6 kg desde a anterior".
class VariationText extends StatelessWidget {
  const VariationText({
    super.key,
    required this.delta,
    required this.unit,
    this.suffix = '',
    this.decimals = 1,
  });

  final double? delta;
  final String unit;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    if (delta == null) return const SizedBox.shrink();
    final u = unit.isEmpty ? '' : ' $unit';
    final icon = delta! > 0
        ? Icons.arrow_upward
        : delta! < 0
            ? Icons.arrow_downward
            : Icons.remove;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: FolegoColors.textSecondary),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            '${fmtSigned(delta!, decimals: decimals)}$u$suffix',
            style: const TextStyle(
                fontSize: 12,
                color: FolegoColors.textSecondary,
                fontFeatures: tabular),
          ),
        ),
      ],
    );
  }
}

/// Campo numérico com teclado decimal e vírgula.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.validator,
    this.decimal = true,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? Function(String?)? validator;
  final bool decimal;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: textInputAction,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
      ],
      style: const TextStyle(fontFeatures: tabular),
      decoration: InputDecoration(
          labelText: label, suffixText: suffix, helperText: helper),
      validator: validator,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}

/// Botão que mostra uma data e abre o seletor.
class DateButton extends StatelessWidget {
  const DateButton({
    super.key,
    required this.date,
    required this.onChanged,
    this.label = 'Data',
    this.firstDate,
    this.lastDate,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 18),
      label: Text('$label: ${fmtDate(date)}'),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate ?? DateTime(1900),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Diálogo de confirmação. Devolve `true` se o usuário confirmar.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Excluir',
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: FolegoColors.bold,
                  foregroundColor: FolegoColors.onLime)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// SnackBar com "Desfazer".
void showUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(label: 'Desfazer', onPressed: onUndo),
  ));
}

void showMessage(BuildContext context, String message, {IconData? icon}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: FolegoColors.lime),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(message)),
      ],
    ),
  ));
}

/// Carregamento e erro padrão para `AsyncValue`.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key});
  final Object error;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Algo deu errado: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: FolegoColors.error)),
        ),
      );
}

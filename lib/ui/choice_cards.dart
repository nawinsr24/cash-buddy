import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// One option shown as a card.
class Choice<T> {
  final T value;
  final String label;
  final IconData? icon;
  const Choice(this.value, this.label, [this.icon]);
}

/// Tap cards in place of a dropdown: every option is visible at once.
class ChoiceCards<T> extends StatelessWidget {
  final String? label;
  final List<Choice<T>> choices;
  final T? value;
  final ValueChanged<T> onChanged;
  const ChoiceCards({
    super.key,
    this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.x2),
          child: Text(
            label!,
            style: context.text.labelLarge?.copyWith(
              color: context.cash.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      Wrap(
        spacing: Sp.x2,
        runSpacing: Sp.x2,
        children: [for (final c in choices) _card(context, c)],
      ),
    ],
  );

  Widget _card(BuildContext context, Choice<T> c) {
    final on = c.value == value;
    final color = on ? context.scheme.primary : context.scheme.onSurface;
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sp.rChip),
        onTap: () {
          haptic();
          onChanged(c.value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x3,
          ),
          decoration: BoxDecoration(
            color: on
                ? context.scheme.primaryContainer
                : context.cash.surfaceRaised,
            borderRadius: BorderRadius.circular(Sp.rChip),
            border: Border.all(
              width: 1.5,
              color: on
                  ? context.scheme.primary
                  : context.scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (c.icon != null) ...[
                Icon(c.icon, size: 20, color: color),
                const SizedBox(width: Sp.x2),
              ],
              Flexible(
                child: Text(
                  c.label,
                  style: context.text.titleSmall?.copyWith(
                    color: color,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

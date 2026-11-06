import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/money.dart';
import 'art.dart';
import 'motion.dart';
import 'theme.dart';

class MoneyText extends StatelessWidget {
  final int minor;
  final TextStyle? style;
  final Color? color;
  final bool signed;
  final bool compact;
  const MoneyText(
    this.minor, {
    super.key,
    this.style,
    this.color,
    this.signed = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = (style ?? context.text.titleMedium)!.copyWith(
      fontFeatures: moneyFeatures,
      color: color,
    );
    return Text(
      compact ? Money.compact(minor) : Money.format(minor, signed: signed),
      style: s,
    );
  }
}

/// Money in a list tile's trailing slot: never wider than ~40% of the screen
/// and shrinks to fit, so huge amounts / large text can't break the layout.
class TrailingMoney extends StatelessWidget {
  final int minor;
  final TextStyle? style;
  final Color? color;
  final bool signed;
  const TrailingMoney(
    this.minor, {
    super.key,
    this.style,
    this.color,
    this.signed = false,
  });
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width * 0.4,
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: MoneyText(minor, style: style, color: color, signed: signed),
    ),
  );
}

/// Small-caps label above a block, in the muted ink colour.
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: context.text.labelSmall?.copyWith(
      color: context.cash.textMuted,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
      fontSize: 11,
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.x1, Sp.x6, Sp.x1, Sp.x3),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(-16 * (1 - t), 0), child: c),
      ),
      child: Row(
        children: [
          Expanded(child: Eyebrow(text)),
          ?trailing,
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  final Art? art;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.art,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // Scrolls when text is large or the screen is small, instead of overflowing.
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: box.hasBoundedHeight ? box.maxHeight : 0,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Sp.x8),
            child: Reveal(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (art != null)
                    Illustration(art!, height: 170)
                  else
                    Icon(icon, size: 48, color: context.cash.textMuted),
                  const SizedBox(height: Sp.x3),
                  Text(
                    title,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (body != null) ...[
                    const SizedBox(height: Sp.x2),
                    Text(
                      body!,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.cash.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: Sp.x4),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  final Object error;
  const ErrorState(this.error, {super.key});
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.error_outline,
    title: 'Something went wrong',
    body: '$error',
  );
}

void haptic() => HapticFeedback.selectionClick();

void toast(BuildContext context, String msg, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), action: action));
}

Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: builder(c),
      ),
    );

/// Amount field that accepts only valid money input.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Amount',
    this.autofocus = false,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
    ],
    style: context.text.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: moneyFeatures,
    ),
    decoration: InputDecoration(labelText: label, prefixText: '₹ '),
  );
}

Color colorOf(int v) => Color(v);

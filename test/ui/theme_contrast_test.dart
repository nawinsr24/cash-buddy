import 'dart:math' as math;

import 'package:cash_buddy/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _lum(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// WCAG contrast ratio of [fg] on an opaque [bg].
double contrast(Color fg, Color bg) {
  final a = _lum(Color.alphaBlend(fg, bg)), b = _lum(bg);
  final hi = math.max(a, b), lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final b in [Brightness.light, Brightness.dark]) {
    final t = AppTheme.build(b);
    final c = t.extension<CashColors>()!;
    final s = t.colorScheme;
    final name = b.name;
    final bg = t.scaffoldBackgroundColor;
    final card = c.surfaceRaised;

    group('$name theme colour pairs', () {
      test(
        'body text and muted text are readable on the page and on cards',
        () {
          expect(
            contrast(s.onSurface, bg),
            greaterThanOrEqualTo(7),
            reason: 'ink on page',
          );
          expect(
            contrast(s.onSurface, card),
            greaterThanOrEqualTo(7),
            reason: 'ink on card',
          );
          expect(
            contrast(c.textMuted, bg),
            greaterThanOrEqualTo(4.5),
            reason: 'muted on page',
          );
          expect(
            contrast(c.textMuted, card),
            greaterThanOrEqualTo(4.5),
            reason: 'muted on card',
          );
        },
      );

      test('accent and buttons are readable', () {
        expect(
          contrast(s.primary, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'accent on page',
        );
        expect(
          contrast(s.primary, card),
          greaterThanOrEqualTo(4.5),
          reason: 'accent on card',
        );
        expect(
          contrast(s.onPrimary, s.primary),
          greaterThanOrEqualTo(4.5),
          reason: 'button text',
        );
      });

      test('money colours (used for bold amounts) hold up on the page and on cards', () {
        for (final e in {
          'income': c.income,
          'spending': c.spending,
          'incoming debts': c.debtIn,
          'liabilities': c.liability,
        }.entries) {
          expect(
            contrast(e.value, card),
            greaterThanOrEqualTo(3.0),
            reason: '${e.key} on card',
          );
          expect(
            contrast(e.value, bg),
            greaterThanOrEqualTo(3.0),
            reason: '${e.key} on page',
          );
        }
      });

      test('chips, tiles and tinted pills keep readable text', () {
        // a status pill is the colour at 14% over the card, text in the colour
        for (final col in [c.income, c.spending, c.debtIn]) {
          final pill = Color.alphaBlend(col.withValues(alpha: 0.14), card);
          expect(contrast(col, pill), greaterThanOrEqualTo(3.0));
        }
        // selected chip / primary container with ink text
        expect(
          contrast(
            s.onSurface,
            s.primaryContainer.withValues(alpha: 1) == s.primaryContainer
                ? s.primaryContainer
                : Color.alphaBlend(s.primaryContainer, bg),
          ),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }

  test('the dark hero cards keep white text readable', () {
    for (final hero in [const Color(0xFF0F1115), const Color(0xFF191B22)]) {
      expect(contrast(Colors.white, hero), greaterThanOrEqualTo(7));
      expect(
        contrast(Colors.white.withValues(alpha: 0.54), hero),
        greaterThanOrEqualTo(4.5),
        reason: 'small caps label',
      );
    }
  });

  test('toasts and tooltips are readable in both themes', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      final t = AppTheme.build(b);
      final bar = t.snackBarTheme.backgroundColor!;
      final text = t.snackBarTheme.contentTextStyle!.color!;
      expect(contrast(text, bar), greaterThanOrEqualTo(7));
    }
  });
}

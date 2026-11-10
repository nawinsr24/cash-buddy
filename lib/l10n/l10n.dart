import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'strings_hi.dart';
import 'strings_ta.dart';

/// A language the app can show. English is first. [beta] languages are drafts
/// until a fluent speaker has checked them.
class AppLanguage {
  final String code, native, english;
  final bool beta;
  const AppLanguage(this.code, this.native, this.english, {this.beta = false});
}

const appLanguages = [
  AppLanguage('en', 'English', 'English'),
  AppLanguage('hi', 'हिन्दी', 'Hindi', beta: true),
  AppLanguage('ta', 'தமிழ்', 'Tamil', beta: true),
];

/// The app's current language. Text that has no translation yet shows in
/// English, so a half-translated screen never shows an empty or broken label.
class L10n {
  L10n._();
  static String _lang = 'en';
  static Map<String, String> _map = const {};

  static String get lang => _lang;
  static Locale get locale => Locale(_lang);

  static void use(String code) {
    _lang = appLanguages.any((l) => l.code == code) ? code : 'en';
    _map = switch (_lang) {
      'hi' => stringsHi,
      'ta' => stringsTa,
      _ => const {},
    };
    Intl.defaultLocale = _lang == 'en' ? null : _lang;
  }

  static String t(String english) => _map[english] ?? english;
}

/// Translate a fixed piece of text. Pass the English text exactly.
String tr(String english) => L10n.t(english);

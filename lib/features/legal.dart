import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';

/// The one agreement in the app: a single tick, with the full text a tap away.
Future<bool> hasAgreed(Repo repo) async =>
    await repo.getSetting('serverNotice') == '1';

Future<void> recordAgreement(Repo repo) => repo.setSetting('serverNotice', '1');

const termsText = <(String, String)>[
  (
    'Using Cash++',
    'Cash++ helps you record your money. Its figures, including loan and interest estimates, are only as good as what you enter, and are not financial advice. Check important figures with your bank.',
  ),
  (
    'Access',
    'We can turn off access to the app for an account or a phone, for example to stop misuse or unapproved copies. Your data stays on your phone.',
  ),
  (
    'Sharing a home',
    'If you share a home, your partner sees the spending you do not mark "Don\'t count this", from the date you choose, and your balance only if you both switch that on. What they have already received stays on their phone.',
  ),
  ('No guarantee', 'The app is provided as it is.'),
];

const privacyText = <(String, String)>[
  (
    'On your phone',
    'Your entries, balances, loans and investments are kept in an encrypted database on this phone.',
  ),
  (
    'Our server',
    'It keeps a random ID for this phone and when it last connected. If you sign in, also your Google email. For a shared home it carries your shared entries locked with a key only your two phones have, so we cannot read them, and keeps an address for notifications.',
  ),
  (
    'Your Google Drive',
    'If you switch on backup, your data is copied to a private app folder in your own Google Drive.',
  ),
  (
    'Permissions',
    'The camera is used only to scan a partner\'s QR. Bank notifications are read only if you switch that on, and stay on your phone.',
  ),
  (
    'Your choices',
    'You can sign out, leave a shared home, or uninstall at any time. To have your server records removed, contact the developer.',
  ),
];

class LegalPage extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;
  const LegalPage({super.key, required this.title, required this.sections});

  static void open(BuildContext context, {required bool privacy}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LegalPage(
            title: privacy ? 'Privacy Policy' : 'Terms and Conditions',
            sections: privacy ? privacyText : termsText,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(title))),
    body: ListView(
      padding: const EdgeInsets.all(Sp.x5),
      children: [
        for (final (head, body) in sections) ...[
          Text(
            head,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Sp.x2),
          Text(body),
          const SizedBox(height: Sp.x5),
        ],
      ],
    ),
  );
}

/// "I agree to the Terms and Conditions and Privacy Policy."
class ConsentCheck extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ConsentCheck({super.key, required this.value, required this.onChanged});

  @override
  State<ConsentCheck> createState() => _ConsentCheckState();
}

class _ConsentCheckState extends State<ConsentCheck> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => LegalPage.open(context, privacy: false);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => LegalPage.open(context, privacy: true);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = TextStyle(
      color: context.scheme.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    return Row(
      children: [
        Checkbox(
          value: widget.value,
          onChanged: (v) => widget.onChanged(v ?? false),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${tr('I agree to the')} '),
                TextSpan(
                  text: tr('Terms and Conditions'),
                  style: link,
                  recognizer: _terms,
                ),
                TextSpan(text: ' ${tr('and')} '),
                TextSpan(
                  text: tr('Privacy Policy'),
                  style: link,
                  recognizer: _privacy,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

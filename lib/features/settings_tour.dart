import 'package:flutter/material.dart';

import '../ui/motion.dart';
import '../ui/theme.dart';

class _Step {
  final String emoji, title, body;
  const _Step(this.emoji, this.title, this.body);
}

const _steps = <_Step>[
  _Step(
    '👋',
    'Welcome to Settings',
    'This is a quick tour. Each step explains one part of this page in simple words. You can skip any time.',
  ),
  _Step(
    '☁️',
    'Data: Online or Offline',
    'Offline: your data stays only on this phone. Online: it is also saved safely in your own Google Drive, so you can restore it on a new phone. Only you can see it.',
  ),
  _Step(
    '⚖️',
    'Balance rules',
    'Decide if money you lend or invest should reduce your balance. Example: if you lend ₹1,000 and this is on, your balance goes down by ₹1,000.',
  ),
  _Step(
    '🏦',
    'Accounts',
    'Keep Cash and your Bank separate, or together as one. Use this to set your opening balance and add more accounts.',
  ),
  _Step(
    '💬',
    'SMS assistant',
    'Reads bank SMS on this phone and suggests entries for you. You approve each one. SMS never leaves your phone.',
  ),
  _Step(
    '🔔',
    'Notifications',
    'Reminders for dues, SIPs and your daily spending note. Use the test button to check they reach you.',
  ),
  _Step(
    '🔒',
    'Security',
    'Lock the app with your fingerprint, face or phone PIN. Nobody else can open your money details.',
  ),
  _Step(
    '🏆',
    'Monthly title',
    'At month end you get a fun title based on how you spent. You can switch the funny roast lines on or off here.',
  ),
  _Step(
    '🎨',
    'Appearance',
    'Choose light or dark mode, or let the phone decide.',
  ),
  _Step(
    '🛠️',
    'Diagnostics',
    'If something is not working, this shows what went wrong so it can be fixed. You can ignore it normally.',
  ),
  _Step(
    '✅',
    'That is it!',
    'You can open this tour again any time from the top of Settings.',
  ),
];

/// A friendly step-by-step walkthrough of the Settings page.
Future<void> showSettingsTour(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _Tour(),
    );

class _Tour extends StatefulWidget {
  const _Tour();
  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int i) => _page.animateToPage(
    i,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final last = _i == _steps.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x5, 0, Sp.x5, Sp.x5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 250,
            child: PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _i = i),
              children: [
                for (final s in _steps)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.emoji, style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: Sp.x3),
                      Text(
                        s.title,
                        textAlign: TextAlign.center,
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: Sp.x2),
                      Text(
                        s.body,
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge?.copyWith(height: 1.45),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: Sp.x3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var k = 0; k < _steps.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: k == _i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: k == _i
                        ? context.scheme.primary
                        : context.scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.x4),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip'),
              ),
              const Spacer(),
              if (_i > 0)
                OutlinedButton(
                  onPressed: () => _go(_i - 1),
                  child: const Text('Back'),
                ),
              const SizedBox(width: Sp.x2),
              Pressable(
                child: FilledButton(
                  onPressed: () => last ? Navigator.pop(context) : _go(_i + 1),
                  child: Text(last ? 'Done' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

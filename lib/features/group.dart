import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db_key.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../sync/group/group_service.dart';
import '../sync/group/replica.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'account_tile.dart';
import '../data/home_repo.dart';
import 'group_keeper.dart';
import 'pair_screens.dart';
import 'partner_balance.dart';

/// Null in builds without a server: then nothing about groups is shown.
final groupServiceProvider = Provider<GroupService?>((ref) {
  final account = ref.watch(accountProvider);
  if (account == null) return null;
  return GroupService(
    ref.watch(repoProvider),
    secrets: const SecureSecretStore(),
    server: Uri.parse(account.access.config.url),
  );
});

/// The one way into the group, in Settings.
class GroupCard extends ConsumerWidget {
  const GroupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(groupServiceProvider) == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.group_outlined),
        title: Text(tr('Home sharing')),
        subtitle: Text(tr('Share house spending with your partner')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const GroupPage())),
      ),
    );
  }
}

class GroupPage extends ConsumerStatefulWidget {
  const GroupPage({super.key});
  @override
  ConsumerState<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends ConsumerState<GroupPage> {
  Replica? _group;
  var _loading = true;
  String? _problem;
  Timer? _poll;

  GroupService get _service => ref.read(groupServiceProvider)!;

  @override
  void initState() {
    super.initState();
    // While this screen is open, keep looking for the other phone.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_group != null) _sync();
    });
    groupSynced.addListener(_redraw);
    _open();
  }

  @override
  void dispose() {
    _poll?.cancel();
    groupSynced.removeListener(_redraw);
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  Future<void> _open() async {
    final g = await _service.open();
    if (!mounted) return;
    setState(() {
      _group = g;
      _loading = false;
    });
    if (g != null) await _sync();
  }

  /// Offline is normal: changes are kept and sent later.
  Future<void> _sync() async {
    String? problem;
    try {
      final token = await ref.read(pushProvider).token();
      if (token != null) await _service.registerPush(token);
      await updateGroup(_service, ref.read(repoProvider));
    } on GroupProblem catch (e) {
      problem = e.message;
    }
    final g = await _service.open();
    if (mounted) {
      setState(() {
        _group = g;
        _problem = problem;
      });
    }
  }

  Future<void> _attempt(Future<void> Function() work) async {
    try {
      await work();
    } on GroupProblem catch (e) {
      if (mounted) toast(context, tr(e.message));
    }
  }

  Future<String?> _ask(
    String title, {
    String initial = '',
    bool number = false,
  }) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr(title)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: Text(tr('OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _start({required bool joining}) async {
    final account = ref.read(accountProvider)!;
    if ((await account.email ?? '').isEmpty) {
      if (!mounted || !await signInWithConsent(context, account)) return;
    }
    if (!mounted) return;
    String? code;
    if (joining) {
      code = await ref.read(scanCodeProvider)(context);
      // empty: they would rather type it
      if (code == '' && mounted) code = await _ask('Invite code');
      if (code == null || !mounted) return;
    }
    final name = await _ask('Your name');
    if (name == null) return;
    await _attempt(() async {
      if (!mounted) return;
      final earlier = await _askEarlier();
      if (earlier == null) return;
      final repo = ref.read(repoProvider);
      joining ? await _service.join(code!, name) : await _service.create(name);
      await repo.chooseSharing(earlierToo: earlier);
      await _open();
    });
    // just created: go straight to the QR for the partner to scan
    if (!joining && _group != null && mounted) await _invite();
  }

  /// Null when the dialog is dismissed: nothing is set up then.
  Future<bool?> _askEarlier() => showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(tr('Share your earlier spending too?')),
      content: Text(
        tr('Your partner will see what you spend. Choose how far back.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(tr('Only from today')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(tr('Include earlier')),
        ),
      ],
    ),
  );

  Future<void> _invite() => _attempt(() async {
    final code = await _service.inviteCode();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShowCodePage(code: code, partner: _partnerName),
      ),
    );
  });

  Future<String?> _partnerName() async {
    final g = await _service.open();
    if (g == null) return null;
    for (final e in GroupService.ofKind(g, 'member')) {
      if (e.id != 'member:${g.disk.member}') return e.data['name'] as String;
    }
    return null;
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Stop home sharing?')),
        content: Text(
          tr(
            'It is removed from this phone. Others keep what they already have.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Leave')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _attempt(() async {
      await _service.leave();
      ref.invalidate(budgetStatusProvider);
      if (mounted) setState(() => _group = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Home sharing')),
        actions: [
          if (g != null)
            IconButton(
              tooltip: tr('Invite'),
              icon: const Icon(Icons.person_add_alt),
              onPressed: _invite,
            ),
          if (g != null)
            IconButton(
              tooltip: tr('Leave'),
              icon: const Icon(Icons.logout),
              onPressed: _leave,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : g == null
          ? _welcome()
          : RefreshIndicator(onRefresh: _sync, child: _members(g)),
    );
  }

  Widget _welcome() => ListView(
    padding: const EdgeInsets.all(Sp.x5),
    children: [
      Text(
        tr(
          'One budget and one spending list for you and your partner. One of you shows a QR, the other scans it.',
        ),
      ),
      const SizedBox(height: Sp.x5),
      _choice(
        Icons.qr_code_2_rounded,
        tr('Show my QR'),
        tr('Start here, then let your partner scan'),
        () => _start(joining: false),
      ),
      const SizedBox(height: Sp.x3),
      _choice(
        Icons.qr_code_scanner_rounded,
        tr('Scan partner\'s QR'),
        tr('Your partner already shows one'),
        () => _start(joining: true),
      ),
    ],
  );

  Widget _choice(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Sp.x5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Sp.x3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF17B03), Color(0xFFF3AD3D)],
                ),
              ),
              child: Icon(icon, size: 36, color: Colors.white),
            ),
            const SizedBox(width: Sp.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.cash.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );

  Widget _members(Replica g) => ListView(
    padding: const EdgeInsets.all(Sp.x5),
    children: [
      if (_problem != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.x3),
          child: Text(tr(_problem!)),
        ),
      if (g.needsUpdate) Text(tr('Update the app to see newer home entries.')),
      Text(tr('What you both spend counts in one budget.')),
      const SizedBox(height: Sp.x4),
      for (final e in GroupService.ofKind(g, 'member'))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(e.data['name'] as String),
        ),
      FutureBuilder<bool>(
        future: ref.read(repoProvider).showsMyBalance,
        builder: (context, snap) => SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Show my balance to my partner')),
          subtitle: Text(tr('Both must switch it on.')),
          value: snap.data ?? false,
          onChanged: (v) async {
            await setBalanceSharing(ref, v);
            if (mounted) setState(() {});
          },
        ),
      ),
      const SizedBox(height: Sp.x4),
      FilledButton.icon(
        icon: const Icon(Icons.qr_code_2_rounded),
        label: Text(tr('Invite your partner')),
        onPressed: _invite,
      ),
    ],
  );
}

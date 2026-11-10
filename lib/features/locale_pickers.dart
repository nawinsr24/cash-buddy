import 'package:flutter/material.dart';

import '../domain/currency.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Language list: English first, then the rest. Beta languages are marked.
Future<String?> pickLanguageCode(BuildContext context, String current) =>
    showSheet<String>(
      context,
      (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x5),
          children: [
            for (final l in appLanguages)
              ListTile(
                title: Text(l.native),
                subtitle: Text(l.beta ? '${l.english} · beta' : l.english),
                trailing: l.code == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(c, l.code),
              ),
          ],
        ),
      ),
    );

/// Searchable currency list: INR first, then the rest.
Future<String?> pickCurrencyCode(BuildContext context) =>
    showSheet<String>(context, (c) => const _CurrencyPicker());

/// Searchable currency list; INR is first.
class _CurrencyPicker extends StatefulWidget {
  const _CurrencyPicker();
  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = [
      for (final c in allCurrencies)
        if (q.isEmpty ||
            c.code.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q))
          c,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x2),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr('Search'),
                ),
                onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  leading: SizedBox(
                    width: 44,
                    child: Text(
                      list[i].symbol,
                      style: context.text.titleMedium,
                    ),
                  ),
                  title: Text(list[i].name),
                  subtitle: Text(list[i].code),
                  onTap: () => Navigator.pop(context, list[i].code),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

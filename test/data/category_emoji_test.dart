import 'package:cash_buddy/ui/emoji.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test(
    'every default category and sub-category has its own specific emoji',
    () async {
      final e = await newEnv();
      final all = [
        ...await e.repo.categories(kind: 'debit'),
        ...await e.repo.categories(kind: 'credit'),
      ];
      final byId = {for (final c in all) c.id: c};
      expect(all.length, greaterThan(150));
      final missing = <String>[];
      for (final c in all) {
        final parent = c.parentId == null ? null : byId[c.parentId]?.name;
        if (emojiForCategory(c.name, parent) == '🏷️') missing.add(c.name);
      }
      expect(missing, isEmpty);
    },
  );

  test('new subs exist and old ids are kept', () async {
    final e = await newEnv();
    final ids = (await e.repo.categories(kind: 'debit'))
        .map((c) => c.id)
        .toSet();
    for (final id in [
      'cat_food_groceries',
      'cat_food_meat_fish',
      'cat_food_snacks',
      'cat_health_medicines',
      'cat_health_kids_health',
      'cat_personal_care_hair_care',
      'cat_kids_toys',
      'cat_gifts_celebrations_gift_to_lover',
      'cat_home_kitchen_kitchen_utensils',
    ]) {
      expect(ids, contains(id));
    }
    expect(
      (await e.repo.categories(kind: 'credit')).map((c) => c.id),
      contains('cat_dividend'),
    );
  });
}

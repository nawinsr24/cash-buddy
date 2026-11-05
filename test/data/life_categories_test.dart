import 'package:cash_buddy/data/insights_repo.dart';
import 'package:cash_buddy/domain/dates.dart';
import 'package:cash_buddy/domain/grade.dart';
import 'package:cash_buddy/ui/emoji.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

MonthStats base({
  int income = 4000000,
  int spending = 3400000,
  int smoke = 0,
  int liquor = 0,
  int friends = 0,
  int hobby = 0,
  int trip = 0,
  int home = 0,
}) => MonthStats(
  income: income,
  spending: spending,
  txnCount: 30,
  activeDays: 10,
  smokeSpending: smoke,
  liquorSpending: liquor,
  friendsSpending: friends,
  hobbySpending: hobby,
  tripSpending: trip,
  homeSent: home,
);

void main() {
  test(
    'new default categories exist for new installs and have subcategories',
    () async {
      final e = await newEnv();
      final ids = (await e.repo.categories(kind: 'debit'))
          .map((c) => c.id)
          .toSet();
      for (final id in [
        'cat_cigarettes',
        'cat_liquor',
        'cat_hobbies',
        'cat_hobbies_cycling',
        'cat_hobbies_jogging',
        'cat_friends',
        'cat_friends_food_treats',
        'cat_friends_movies_outings',
        'cat_friends_clothes',
        'cat_friends_gifts',
        'cat_tours_trips',
        'cat_tours_trips_stay',
        'cat_sent_home',
        'cat_sent_home_parents',
      ]) {
        expect(ids, contains(id));
      }
    },
  );

  test('existing installs get the new categories added once, nothing duplicated or undone', () async {
    final e = await newEnv();
    final r = e.repo;
    // simulate an older install: remove the new categories
    await e.db.customStatement(
      "DELETE FROM categories WHERE id IN ('cat_cigarettes','cat_liquor','cat_sent_home','cat_sent_home_parents','cat_sent_home_family')",
    );
    await r.ensureDefaultCategories();
    var ids = (await r.categories(kind: 'debit')).map((c) => c.id).toList();
    expect(ids, contains('cat_cigarettes'));
    expect(ids, contains('cat_sent_home_parents'));
    // a user who renames or deletes one keeps their choice
    await r.updateCategory('cat_liquor', name: 'Drinks');
    await r.ensureDefaultCategories();
    await r.ensureDefaultCategories();
    final liquor = (await r.categories(kind: 'debit'))
        .where((c) => c.id == 'cat_liquor');
    expect(liquor.single.name, 'Drinks');
    ids = (await r.categories(kind: 'debit')).map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test(
    'emojis: specific words win, subcategories fall back to their parent',
    () {
      expect(emojiForCategory('Cigarettes'), '🚬');
      expect(emojiForCategory('Liquor'), '🍺');
      expect(emojiForCategory('Cycling', 'Hobbies'), '🚴');
      expect(emojiForCategory('Jogging', 'Hobbies'), '🏃');
      expect(emojiForCategory('Gym & Fitness', 'Hobbies'), '🏋️');
      expect(emojiForCategory('Friends'), '👯');
      expect(emojiForCategory('Gifts', 'Friends'), '🎁');
      expect(emojiForCategory('Food & Treats', 'Friends'), '🍻');
      expect(emojiForCategory('Movies & Outings', 'Friends'), '🍿');
      expect(emojiForCategory('Clothes', 'Friends'), '👕');
      expect(emojiForCategory('Tours & Trips'), '🧳');
      expect(emojiForCategory('Stay', 'Tours & Trips'), '🏨');
      expect(emojiForCategory('Food on Trip', 'Tours & Trips'), '🍜');
      expect(emojiForCategory('Sent Home'), '🏡');
      expect(emojiForCategory('Parents', 'Sent Home'), '👪');
      // older ones still work
      expect(emojiForCategory('Groceries', 'Food'), '🛒');
      expect(emojiForCategory('Movies', 'Entertainment'), '🎬');
      expect(emojiForCategory('Something odd'), '🏷️');
    },
  );

  test('titles: lifestyle spending is called out, in priority order', () {
    expect(pickTitle(base(smoke: 250000, liquor: 250000)), TitleId.smokeSignal);
    expect(pickTitle(base(friends: 800000)), TitleId.socialButterfly);
    expect(pickTitle(base(trip: 1200000)), TitleId.wanderlust);
    expect(pickTitle(base(hobby: 600000)), TitleId.gearAddict);
    expect(pickTitle(base(home: 700000)), TitleId.homeHero);
    // overspending still comes first
    expect(
      pickTitle(base(spending: 6000000, smoke: 3000000)),
      TitleId.overdraftArtist,
    );
    // small amounts do not trigger anything
    expect(pickTitle(base(smoke: 10000)), isNot(TitleId.smokeSignal));
  });

  test(
    'every new title has roast and kind lines, filled with the real amounts',
    () {
      final s = base(
        smoke: 250000,
        liquor: 250000,
        friends: 800000,
        hobby: 600000,
        trip: 1200000,
        home: 700000,
      );
      for (final t in [
        TitleId.smokeSignal,
        TitleId.socialButterfly,
        TitleId.wanderlust,
        TitleId.gearAddict,
        TitleId.homeHero,
      ]) {
        for (final roast in [true, false]) {
          final lines = titleLines(t, s, roast: roast);
          expect(lines, isNotEmpty, reason: '$t');
          for (final l in lines) {
            expect(l.contains('\$'), isFalse, reason: l);
            expect(l.contains('null'), isFalse, reason: l);
          }
        }
      }
      expect(
        titleLines(TitleId.smokeSignal, s, roast: true).first,
        contains('₹5,000.00'),
      );
      expect(
        titleLines(TitleId.socialButterfly, s, roast: true).first,
        contains('₹8,000.00'),
      );
    },
  );

  test('money sent home is never roasted, even in roast mode', () {
    final s = base(spending: 3000000, home: 1500000, friends: 700000);
    expect(s.homeDriven, isTrue);
    expect(
      titleLines(TitleId.socialButterfly, s, roast: true),
      titleLines(TitleId.socialButterfly, s, roast: false),
    );
    expect(nextStep(s, roast: true), nextStep(s, roast: false));
    // Home Hero is warm in both tones
    for (final roast in [true, false]) {
      for (final l in titleLines(TitleId.homeHero, s, roast: roast)) {
        expect(l.toLowerCase(), isNot(contains('coward')));
      }
    }
  });

  test('monthStats picks the new categories up, subcategories rolled into the main one', () async {
    final e = await newEnv(opening: 100000000);
    final r = e.repo;
    final d = Dates.day(2026, 10, 5);
    await r.addTransaction(
      type: 'debit',
      amountMinor: 30000,
      categoryId: 'cat_cigarettes',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 70000,
      categoryId: 'cat_liquor',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 20000,
      categoryId: 'cat_friends_gifts',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 15000,
      categoryId: 'cat_friends_food_treats',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 50000,
      categoryId: 'cat_hobbies_cycling',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 90000,
      categoryId: 'cat_tours_trips_stay',
      date: d,
    );
    await r.addTransaction(
      type: 'debit',
      amountMinor: 120000,
      categoryId: 'cat_sent_home_parents',
      date: d,
    );
    final s = await r.monthStats(2026, 10);
    expect(s.smokeSpending, 30000);
    expect(s.liquorSpending, 70000);
    expect(s.viceSpending, 100000);
    expect(s.friendsSpending, 35000);
    expect(s.hobbySpending, 50000);
    expect(s.tripSpending, 90000);
    expect(s.homeSent, 120000);
    expect(s.spending, 30000 + 70000 + 35000 + 50000 + 90000 + 120000);
  });
}

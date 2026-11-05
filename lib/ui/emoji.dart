/// Friendly emoji for categories, chosen from the category's own name first,
/// then from its parent's (so "Friends › Gifts" is a gift, "Friends" a pair).
String emojiForCategory(String name, [String? parent]) =>
    _lookup(name) ?? (parent == null ? null : _lookup(parent)) ?? '🏷️';

/// Specific words come before general ones: the first match wins.
const _emojiTable = <String, String>{
  // vices
  'cigar': '🚬',
  'smok': '🚬',
  'liquor': '🍺',
  'beer': '🍺',
  'alcohol': '🍷',
  'bar ': '🍸',
  // hobbies & fitness
  'cycl': '🚴',
  'jog': '🏃',
  'running': '🏃',
  'gym': '🏋️',
  'fitness': '💪',
  'sport': '⚽',
  'hobb': '🎨',
  // friends
  'treat': '🍻',
  'outing': '🍿',
  'clothes': '👕',
  'friend': '👯',
  // trips
  'souvenir': '🧸',
  'food on trip': '🍜',
  'stay': '🏨',
  'tickets': '🎟️',
  'activit': '🧗',
  'trip': '🧳',
  'tour': '🧳',
  // home & family
  'sent home': '🏡',
  'parent': '👪',
  'family': '👨‍👩‍👧',
  // original set
  'grocer': '🛒',
  'coffee': '☕',
  'dining': '🍽️',
  'food': '🍔',
  'fuel': '⛽',
  'cab': '🚕',
  'public': '🚌',
  'transport': '🚗',
  'rent': '🏠',
  'electric': '💡',
  'internet': '🌐',
  'bill': '🧾',
  'movie': '🎬',
  'stream': '📺',
  'game': '🎮',
  'entertain': '🎉',
  'shop': '🛍️',
  'health': '💊',
  'medic': '💊',
  'educat': '🎓',
  'travel': '✈️',
  'salary': '💼',
  'cash received': '💵',
  'cash': '💵',
  'interest': '💹',
  'refund': '↩️',
  'gift': '🎁',
  'invest': '📈',
  'insurance': '🛡️',
  'other income': '💰',
};

String? _lookup(String name) {
  final n = '${name.toLowerCase()} ';
  for (final e in _emojiTable.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return null;
}

String emojiForInvestment(String kind) => switch (kind) {
  'mutual_fund' => '📊',
  'stock' => '📈',
  'custom' => '🎯',
  _ => '💰',
};

String investKindLabel(String kind) => switch (kind) {
  'mutual_fund' => 'Mutual fund',
  'stock' => 'Stock',
  'custom' => 'Custom investment',
  _ => 'Investment',
};

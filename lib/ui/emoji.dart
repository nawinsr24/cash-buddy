/// Friendly emoji for categories, chosen from the category's name.
String emojiForCategory(String name, [String? parent]) {
  final n = '${parent ?? ''} $name'.toLowerCase();
  const table = <String, String>{
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
  for (final e in table.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return '🏷️';
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

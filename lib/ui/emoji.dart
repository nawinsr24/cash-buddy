/// Friendly emoji for categories, chosen from the category's own name first,
/// then from its parent's (so "Friends › Gifts" is a gift, "Friends" a pair).
String emojiForCategory(String name, [String? parent]) =>
    _exact['${parent?.toLowerCase()}|${name.toLowerCase()}'] ??
    _exact[name.toLowerCase()] ??
    _lookup(name) ??
    (parent == null ? null : _lookup(parent)) ??
    '🏷️';

/// One specific emoji per category and sub-category (exact names first).
const _exact = <String, String>{
  // food
  'food': '🍱',
  'groceries': '🛒',
  'veggies & fruits': '🥬',
  'meat & fish': '🍗',
  'hotel & restaurant': '🍽️',
  'dining': '🍽️',
  'snacks': '🍿',
  'sweets & bakery': '🧁',
  'milk & dairy': '🥛',
  'food delivery': '🛵',
  'canteen meals': '🥡',
  'coffee': '☕',
  // home & kitchen
  'home & kitchen': '🏠',
  'kitchen utensils': '🍳',
  'home appliances': '🧺',
  'furniture': '🛋️',
  'cleaning & household': '🧹',
  'gas cylinder': '🔥',
  'repairs & maintenance': '🔧',
  'decor & curtains': '🖼️',
  'garden & plants': '🪴',
  // bills
  'bills': '🧾',
  'rent': '🔑',
  'electricity': '💡',
  'internet': '📶',
  'water': '🚰',
  'mobile recharge': '📱',
  'dth & cable': '📡',
  'gas bill': '🛢️',
  'society maintenance': '🏢',
  'house tax': '🏛️',
  'insurance premium': '🛡️',
  // transport
  'transport': '🚗',
  'fuel': '⛽',
  'cab': '🚕',
  'public': '🚌',
  'bus, train & metro': '🚆',
  'parking & toll': '🅿️',
  'vehicle service': '🛠️',
  'vehicle insurance': '📋',
  'vehicle emi': '🏍️',
  // health
  'health': '🩺',
  'medicines': '💊',
  'doctor visit': '👨‍⚕️',
  'scans & lab tests': '🩻',
  'health check-up': '❤️‍🩹',
  'kids health': '🧒',
  'dental': '🦷',
  'eye care & glasses': '👓',
  'hospital & surgery': '🏥',
  'health insurance': '🛡️',
  'vitamins & supplements': '🧴',
  // personal care
  'personal care': '🧖',
  'hair care': '💇',
  'skin care': '🧴',
  'salon & parlour': '💅',
  'cosmetics & makeup': '💄',
  'perfume & deodorant': '🌸',
  'spa & massage': '💆',
  // kids
  'kids': '🧒',
  'kids dress': '👗',
  'toys': '🧸',
  'school fees': '🏫',
  'kids books & stationery': '✏️',
  'tuition & classes': '👩‍🏫',
  'baby care': '🍼',
  'kids games & activities': '🎠',
  'pocket money': '🪙',
  // shopping
  'shopping': '🛍️',
  'shopping|clothes': '👕',
  'footwear': '👟',
  'bags & accessories': '👜',
  'jewellery': '💍',
  'watches': '⌚',
  'electronics & gadgets': '🎧',
  'mobile & accessories': '📲',
  'online shopping': '📦',
  // education
  'education': '🎓',
  'college & course fees': '🏫',
  'books': '📚',
  'online courses': '💻',
  'exam fees': '📝',
  'coaching': '🧑‍🏫',
  // entertainment
  'entertainment': '🎉',
  'movies': '🎬',
  'streaming': '📺',
  'games': '🎮',
  'music & concerts': '🎵',
  'events & shows': '🎭',
  'books & magazines': '📖',
  // trips
  'tours & trips': '🧳',
  'travel': '✈️',
  'stay': '🏨',
  'tickets & transport': '🎟️',
  'food on trip': '🍜',
  'activities': '🧗',
  'souvenirs': '🎁',
  // gifts & celebrations
  'gifts & celebrations': '🎊',
  'gift to lover': '💝',
  'gift to family': '🎁',
  'gift to friends': '🎀',
  'birthday & anniversary': '🎂',
  'wedding & function': '💒',
  'festival expenses': '🪔',
  'donations & temple': '🛕',
  // friends / partner
  'friends': '👯',
  'food & treats': '🍻',
  'movies & outings': '🍿',
  'gifts': '🎁',
  'partner': '💑',
  'dates & outings': '🌹',
  'partner gifts': '💝',
  'shopping together': '🛒',
  'surprises': '🎈',
  // hobbies
  'hobbies': '🎨',
  'cycling': '🚴',
  'jogging': '🏃',
  'gym & fitness': '🏋️',
  'sports': '⚽',
  'other hobbies': '🎯',
  // home
  'sent home': '🏡',
  'family support': '🏡',
  'parents': '👪',
  'family': '👨‍👩‍👧',
  // work
  'work & business': '💼',
  'office supplies': '🖇️',
  'software & subscriptions': '🖥️',
  'work travel': '🧑‍💼',
  'client meals': '🥂',
  'tools & equipment': '🧰',
  // finance
  'finance & fees': '🏦',
  'loan emi': '📆',
  'credit card bill': '💳',
  'bank charges': '🏧',
  'taxes': '🧮',
  'late fees': '⏰',
  'fines': '🚨',
  'interest paid': '💸',
  // pets
  'pets': '🐶',
  'pet food': '🦴',
  'vet': '🩺',
  'pet grooming': '🛁',
  'pet accessories': '🐾',
  // vices
  'cigarettes': '🚬',
  'liquor': '🍺',
  // other
  'other': '🧩',
  // income
  'salary': '💼',
  'cash received': '💵',
  'interest income': '💹',
  'refund': '↩️',
  'gift': '🎁',
  'other income': '💰',
  'business income': '🏪',
  'freelance': '🧑‍💻',
  'bonus': '🎯',
  'dividend': '📈',
  'rent received': '🏘️',
};

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
  'family support': '🏡',
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

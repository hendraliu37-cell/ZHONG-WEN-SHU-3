import 'dart:convert';

/// A deck (group of cards). Mirrors the prototype `DECKS` plus the backend
/// handoff `decks` table shape.
class Deck {
  final String id;
  String displayIdx; // "01", "02" … shown as "№ 01"
  String name;
  final String standard; // 'hsk' | 'tocfl' | 'mixed'
  final String levelTag; // "HSK 2", "TOCFL Band A"
  final bool isPack; // ready-made downloadable pack
  final List<int> cardIds; // stable card ids in this deck

  Deck({
    required this.id,
    required this.displayIdx,
    required this.name,
    this.standard = 'mixed',
    this.levelTag = '',
    this.isPack = false,
    List<int>? cardIds,
  }) : cardIds = cardIds ?? <int>[];

  Map<String, dynamic> toJson() => {
    'id': id,
    'idx': displayIdx,
    'name': name,
    'standard': standard,
    'levelTag': levelTag,
    'isPack': isPack,
    'cardIds': cardIds,
  };

  factory Deck.fromJson(Map<String, dynamic> j) => Deck(
    id: j['id']?.toString() ?? '',
    displayIdx: j['idx']?.toString() ?? '01',
    name: j['name']?.toString() ?? 'Deck',
    standard: j['standard']?.toString() ?? 'mixed',
    levelTag: j['levelTag']?.toString() ?? '',
    isPack: _boolish(j['isPack']),
    cardIds: _jsonIntList(j['cardIds'] ?? j['card_ids']),
  );
}

int? _jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

List<int> _jsonIntList(Object? value) {
  Object? list = value;
  if (list is String) {
    final text = list.trim();
    if (!text.startsWith('[')) return const [];
    try {
      list = jsonDecode(text);
    } catch (_) {
      return const [];
    }
  }
  if (list is! List) return const [];
  return list.map(_jsonInt).nonNulls.toList();
}

bool _boolish(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

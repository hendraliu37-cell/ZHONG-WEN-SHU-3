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
        id: j['id'] as String,
        displayIdx: j['idx'] as String,
        name: j['name'] as String,
        standard: (j['standard'] ?? 'mixed') as String,
        levelTag: (j['levelTag'] ?? '') as String,
        isPack: (j['isPack'] ?? false) as bool,
        cardIds: (j['cardIds'] as List).map((e) => e as int).toList(),
      );
}

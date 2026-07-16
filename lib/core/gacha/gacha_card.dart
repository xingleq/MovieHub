import 'dart:math';

enum GachaRarity {
  c('C', 'C级', 45),
  b('B', 'B级', 30),
  a('A', 'A级', 16),
  s('S', 'S级', 8),
  ssr('SSR', 'SSR', 1);

  const GachaRarity(this.code, this.label, this.defaultWeight);

  final String code;
  final String label;
  final int defaultWeight;

  static GachaRarity fromCode(String code) {
    return GachaRarity.values.firstWhere(
      (rarity) => rarity.code == code,
      orElse: () => GachaRarity.c,
    );
  }
}

class GachaCard {
  const GachaCard({
    required this.id,
    required this.name,
    required this.series,
    required this.rarity,
    required this.attack,
    required this.defense,
    required this.skillName,
    required this.skillDescription,
    required this.imageAsset,
    required this.weight,
  });

  final String id;
  final String name;
  final String series;
  final GachaRarity rarity;
  final int attack;
  final int defense;
  final String skillName;
  final String skillDescription;
  final String? imageAsset;
  final int weight;
}

class OwnedGachaCard {
  const OwnedGachaCard({required this.card, required this.count});

  final GachaCard card;
  final int count;
}

class GachaDrawResult {
  const GachaDrawResult({
    required this.card,
    required this.isNew,
    required this.guaranteed,
  });

  final GachaCard card;
  final bool isNew;
  final bool guaranteed;
}

class GachaDrawPick {
  const GachaDrawPick({required this.card, required this.guaranteed});

  final GachaCard card;
  final bool guaranteed;
}

GachaCard weightedDraw(List<GachaCard> cards, Random random) {
  final totalWeight = cards.fold<int>(0, (sum, card) => sum + card.weight);
  var ticket = random.nextInt(totalWeight);
  for (final card in cards) {
    ticket -= card.weight;
    if (ticket < 0) {
      return card;
    }
  }
  return cards.last;
}

GachaDrawPick drawWithSsrPity(
  List<GachaCard> cards,
  Random random, {
  required int pitySinceSsr,
  int guaranteedAt = 7,
}) {
  final ssrCards = cards
      .where((card) => card.rarity == GachaRarity.ssr)
      .toList(growable: false);
  if (ssrCards.isNotEmpty && pitySinceSsr >= guaranteedAt - 1) {
    return GachaDrawPick(
      card: weightedDraw(ssrCards, random),
      guaranteed: true,
    );
  }
  return GachaDrawPick(card: weightedDraw(cards, random), guaranteed: false);
}

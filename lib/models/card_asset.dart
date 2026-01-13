class CardAsset {
  final int id;
  final String section;
  final String name;
  final String? description;
  final String rarity;
  final String availability;
  final int priceHurra;
  final bool owned;
  final String? imageUrl;

  const CardAsset({
    required this.id,
    required this.section,
    required this.name,
    required this.description,
    required this.rarity,
    required this.availability,
    required this.priceHurra,
    required this.owned,
    required this.imageUrl,
  });

  factory CardAsset.fromJson(Map<String, dynamic> json) {
    return CardAsset(
      id: _parseInt(json['id']),
      section: (json['section'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      rarity: (json['rarity'] ?? '').toString(),
      availability: (json['availability'] ?? '').toString(),
      priceHurra: _parseInt(json['price_hurra']),
      owned: _parseBool(json['owned']),
      imageUrl: json['image_url']?.toString(),
    );
  }

  CardAsset copyWith({bool? owned, String? imageUrl}) {
    return CardAsset(
      id: id,
      section: section,
      name: name,
      description: description,
      rarity: rarity,
      availability: availability,
      priceHurra: priceHurra,
      owned: owned ?? this.owned,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

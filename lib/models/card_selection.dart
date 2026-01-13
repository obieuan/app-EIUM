import 'card_asset.dart';

class CardSelection {
  final Map<String, CardAsset?> sections;
  final Map<int, CardAsset> medals;

  const CardSelection({
    required this.sections,
    required this.medals,
  });

  factory CardSelection.fromJson(Map<String, dynamic> json) {
    final sections = <String, CardAsset?>{};
    for (final entry in json.entries) {
      if (entry.key == 'medals') {
        continue;
      }
      if (entry.value is Map<String, dynamic>) {
        sections[entry.key] = CardAsset.fromJson(
          entry.value as Map<String, dynamic>,
        );
      } else {
        sections[entry.key] = null;
      }
    }

    final medals = <int, CardAsset>{};
    final medalList = json['medals'];
    if (medalList is List) {
      for (final item in medalList) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final slot = _parseInt(item['slot']);
        final asset = item['asset'];
        if (slot > 0 && asset is Map<String, dynamic>) {
          medals[slot] = CardAsset.fromJson(asset);
        }
      }
    }

    return CardSelection(
      sections: sections,
      medals: medals,
    );
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

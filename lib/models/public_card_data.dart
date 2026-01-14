import 'card_selection.dart';

class PublicCardData {
  final String name;
  final String career;
  final String matricula;
  final String? photoUrl;
  final CardSelection? cardSelection;

  const PublicCardData({
    required this.name,
    required this.career,
    required this.matricula,
    this.photoUrl,
    this.cardSelection,
  });

  factory PublicCardData.fromJson(Map<String, dynamic> json) {
    CardSelection? selection;
    final selectionData = json['card_selection'];
    if (selectionData is Map<String, dynamic>) {
      selection = CardSelection.fromJson(selectionData);
    }

    return PublicCardData(
      name: (json['name'] ?? '').toString(),
      career: (json['career'] ?? '').toString(),
      matricula: (json['matricula'] ?? '').toString(),
      photoUrl: json['photo_url']?.toString(),
      cardSelection: selection,
    );
  }
}

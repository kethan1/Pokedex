class PokemonInfo {
  final String description;
  final List<String> types;
  final String glowColor;

  PokemonInfo({
    required this.description,
    required this.types,
    required this.glowColor,
  });

  factory PokemonInfo.fromJson(Map<String, dynamic> json) {
    try {
      return PokemonInfo(
        description: json['description'] as String,
        types: List<String>.from(json['types'] as List<dynamic>),
        glowColor: json['glowColor'] as String,
      );
    } catch (e) {
      throw FormatException('Invalid JSON format for PokemonInfo');
    }
  }
}

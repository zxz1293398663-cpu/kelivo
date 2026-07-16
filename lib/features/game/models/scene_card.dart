class SceneCard {
  const SceneCard({
    required this.type,
    required this.timeParts,
    required this.characterName,
    required this.items,
  });

  final String type;
  final List<String> timeParts;
  final String characterName;
  final List<String> items;

  String get title {
    if (items.isNotEmpty) return items.first;
    if (characterName.isNotEmpty) return characterName;
    return type;
  }

  String get sceneDescription => items.isEmpty ? '' : items.last;

  String toInstructions({
    required String typeLabel,
    required String timeLabel,
    required String characterLabel,
    required String itemsLabel,
  }) {
    final buffer = StringBuffer()
      ..writeln('$typeLabel$type')
      ..writeln('$timeLabel${timeParts.join(' / ')}')
      ..writeln('$characterLabel$characterName');

    if (items.isNotEmpty) {
      buffer.writeln(itemsLabel);
      for (final item in items) {
        buffer.writeln('- $item');
      }
    }

    return buffer.toString().trim();
  }
}

class SceneCardParser {
  const SceneCardParser._();

  static SceneCard? parse(String input) {
    final text = input.trim();
    if (!text.startsWith(':::')) return null;

    final body = text.substring(3).trim();
    final firstSpace = body.indexOf(RegExp(r'\s'));
    if (firstSpace <= 0) return null;

    final type = body.substring(0, firstSpace).trim();
    final rest = body.substring(firstSpace).trim();
    if (type.isEmpty || rest.isEmpty) return null;

    final slashMatch = RegExp(r'\s*/\s*').firstMatch(rest);
    if (slashMatch == null) return null;

    final timePart = rest.substring(0, slashMatch.start).trim();
    final characterAndItems = rest.substring(slashMatch.end).trim();
    if (timePart.isEmpty || characterAndItems.isEmpty) return null;

    final parts = characterAndItems
        .split(RegExp(r'\s*#\s*'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    final timeParts = timePart
        .split('|')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (timeParts.isEmpty) return null;

    return SceneCard(
      type: type,
      timeParts: timeParts,
      characterName: parts.first,
      items: parts.skip(1).toList(),
    );
  }
}

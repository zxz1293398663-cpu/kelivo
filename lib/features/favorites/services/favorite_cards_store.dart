import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/chat_message.dart';

class FavoriteCard {
  const FavoriteCard({
    required this.id,
    required this.title,
    required this.note,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.sourceMessageId,
    this.assistantId,
    this.conversationId,
    this.autoSaved = false,
  });

  final String id;
  final String title;
  final String note;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourceMessageId;
  final String? assistantId;
  final String? conversationId;
  final bool autoSaved;

  String get referenceText {
    final buffer = StringBuffer()
      ..writeln('## $title')
      ..writeln(content);
    if (note.isNotEmpty) buffer.writeln(note);
    return buffer.toString().trim();
  }

  factory FavoriteCard.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return FavoriteCard(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      sourceMessageId: json['sourceMessageId'] as String?,
      assistantId: json['assistantId'] as String?,
      conversationId: json['conversationId'] as String?,
      autoSaved: json['autoSaved'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'sourceMessageId': sourceMessageId,
    'assistantId': assistantId,
    'conversationId': conversationId,
    'autoSaved': autoSaved,
  };
}

class FavoriteScope {
  const FavoriteScope({
    required this.assistantId,
    required this.conversationId,
  });

  final String? assistantId;
  final String conversationId;
}

class FavoriteCardReference {
  const FavoriteCardReference({
    required this.id,
    required this.title,
    required this.text,
  });

  final String id;
  final String title;
  final String text;
}

class FavoriteCardsStore {
  FavoriteCardsStore._();

  static const String _storageKey = 'kelivo_favorite_cards_v1';

  static Future<List<FavoriteCard>> load({FavoriteScope? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final cards = <FavoriteCard>[];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            cards.add(FavoriteCard.fromJson(Map<String, Object?>.from(item)));
          }
        }
      }
    }
    if (scope == null) return cards;
    return cards.where((card) => _isInScope(card, scope)).toList();
  }

  static Future<void> save(
    List<FavoriteCard> cards, {
    FavoriteScope? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final allCards = scope == null
        ? cards
        : [...await load()]
              .where((card) => !_isInScope(card, scope))
              .followedBy(cards)
              .toList();
    await prefs.setString(
      _storageKey,
      jsonEncode(allCards.map((card) => card.toJson()).toList()),
    );
  }

  static Future<void> upsert(FavoriteCard card, {FavoriteScope? scope}) async {
    final cards = await load(scope: scope);
    final index = cards.indexWhere((item) => item.id == card.id);
    if (index == -1) {
      cards.insert(0, card);
    } else {
      cards[index] = card;
    }
    await save(cards, scope: scope);
  }

  static Future<void> delete(String id, {FavoriteScope? scope}) async {
    final cards = await load(scope: scope);
    await save(cards.where((card) => card.id != id).toList(), scope: scope);
  }

  static Future<bool> addManualFromMessage(
    ChatMessage message, {
    required FavoriteScope scope,
  }) async {
    final content = message.content.trim();
    if (content.isEmpty) return false;
    final now = DateTime.now();
    final cards = await load(scope: scope);
    final existingIndex = cards.indexWhere(
      (card) => card.sourceMessageId == message.id,
    );
    final existing = existingIndex == -1 ? null : cards[existingIndex];
    final card = FavoriteCard(
      id: existing?.id ?? 'manual-${now.microsecondsSinceEpoch}',
      title: _titleFromContent(content, fallback: message.id),
      note: existing?.note ?? '',
      content: content,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      sourceMessageId: message.id,
      assistantId: scope.assistantId,
      conversationId: scope.conversationId,
      autoSaved: existing?.autoSaved ?? false,
    );
    if (existingIndex == -1) {
      cards.insert(0, card);
    } else {
      cards[existingIndex] = card;
    }
    await save(cards, scope: scope);
    return true;
  }

  static bool _isInScope(FavoriteCard card, FavoriteScope scope) {
    if (scope.conversationId.isEmpty) return true;
    return card.assistantId == scope.assistantId &&
        card.conversationId == scope.conversationId;
  }

  static String _titleFromContent(String content, {required String fallback}) {
    final plain = content
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[#>*_`\[\]()]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.isEmpty) return fallback;
    return plain.length > 18 ? '${plain.substring(0, 18)}...' : plain;
  }
}

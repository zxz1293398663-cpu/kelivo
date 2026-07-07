import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/favorites/services/favorite_cards_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const scope = FavoriteScope(assistantId: 'a1', conversationId: 'c1');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('manual favorite saves message content', () async {
    final message = ChatMessage(
      role: 'assistant',
      content: '番外：雨夜的便利店',
      conversationId: 'c1',
      isStreaming: false,
    );

    final saved = await FavoriteCardsStore.addManualFromMessage(
      message,
      scope: scope,
    );
    final cards = await FavoriteCardsStore.load(scope: scope);

    expect(saved, isTrue);
    expect(cards, hasLength(1));
    expect(cards.single.content, message.content);
    expect(cards.single.sourceMessageId, message.id);
    expect(cards.single.assistantId, 'a1');
    expect(cards.single.conversationId, 'c1');
    expect(cards.single.autoSaved, isFalse);
  });

  test('manual favorite rejects empty message content', () async {
    final message = ChatMessage(
      role: 'assistant',
      content: '   ',
      conversationId: 'c1',
      isStreaming: false,
    );

    final saved = await FavoriteCardsStore.addManualFromMessage(
      message,
      scope: scope,
    );

    expect(saved, isFalse);
    expect(await FavoriteCardsStore.load(scope: scope), isEmpty);
  });

  test(
    'manual favorite keeps html fences without auto-save metadata',
    () async {
      final message = ChatMessage(
        role: 'assistant',
        content: '```html\n<div><h1>Card</h1></div>\n```',
        conversationId: 'c1',
        isStreaming: false,
      );

      final saved = await FavoriteCardsStore.addManualFromMessage(
        message,
        scope: scope,
      );
      final cards = await FavoriteCardsStore.load(scope: scope);

      expect(saved, isTrue);
      expect(cards, hasLength(1));
      expect(cards.single.content, contains('```html'));
      expect(cards.single.sourceMessageId, message.id);
      expect(cards.single.autoSaved, isFalse);
    },
  );

  test('manual favorite deduplicates same message within scope', () async {
    final message = ChatMessage(
      id: 'm1',
      role: 'assistant',
      content: 'first',
      conversationId: 'c1',
      isStreaming: false,
    );

    await FavoriteCardsStore.addManualFromMessage(message, scope: scope);
    await FavoriteCardsStore.addManualFromMessage(
      message.copyWith(content: 'updated'),
      scope: scope,
    );
    final cards = await FavoriteCardsStore.load(scope: scope);

    expect(cards, hasLength(1));
    expect(cards.single.content, 'updated');
  });

  test('favorites are isolated by assistant and conversation', () async {
    final message = ChatMessage(
      id: 'm1',
      role: 'assistant',
      content: 'scoped',
      conversationId: 'c1',
      isStreaming: false,
    );
    const otherAssistant = FavoriteScope(
      assistantId: 'a2',
      conversationId: 'c1',
    );
    const otherConversation = FavoriteScope(
      assistantId: 'a1',
      conversationId: 'c2',
    );

    await FavoriteCardsStore.addManualFromMessage(message, scope: scope);

    expect(await FavoriteCardsStore.load(scope: scope), hasLength(1));
    expect(await FavoriteCardsStore.load(scope: otherAssistant), isEmpty);
    expect(await FavoriteCardsStore.load(scope: otherConversation), isEmpty);
  });
}

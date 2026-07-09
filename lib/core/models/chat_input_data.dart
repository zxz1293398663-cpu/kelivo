import 'package:Kelivo/features/favorites/services/favorite_cards_store.dart';

class DocumentAttachment {
  final String path; // absolute file path
  final String fileName;
  final String mime; // e.g. application/pdf, text/plain

  const DocumentAttachment({
    required this.path,
    required this.fileName,
    required this.mime,
  });
}

class ChatInputData {
  final String text;
  final List<String> imagePaths; // absolute file paths or data URLs
  final List<DocumentAttachment> documents; // selected files
  final List<FavoriteCardReference> favoriteCards;
  final bool allowImagesApiRouting;

  const ChatInputData({
    required this.text,
    this.imagePaths = const [],
    this.documents = const [],
    this.favoriteCards = const [],
    this.allowImagesApiRouting = true,
  });
}

enum ChatInputSubmissionResult { sent, queued, rejected }

class QueuedChatInput {
  final String conversationId;
  final ChatInputData input;

  const QueuedChatInput({required this.conversationId, required this.input});
}

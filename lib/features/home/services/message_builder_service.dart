import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/instruction_injection.dart';
import '../../../core/models/world_book.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/document_text_extractor.dart';
import '../../../core/services/chat/prompt_transformer.dart';
import '../../../core/services/instruction_injection_store.dart';
import '../../../core/services/world_book_store.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import '../../../utils/assistant_regex.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import '../../favorites/services/favorite_cards_store.dart';

/// Service for building API messages from conversation state.
///
/// This service handles:
/// - Building API messages list from chat history
/// - Processing user messages (documents, OCR, templates)
/// - Injecting system prompts
/// - Injecting memory and recent chats context
/// - Injecting search prompts
/// - Injecting instruction prompts
/// - Applying context limits
/// - Inlining local images for model context
class MessageBuilderService {
  static const String internalMediaPathsKey = multimodalInternalMediaPathsKey;
  static const String _htmlCardViewSystemInstruction = '''
### 角色状态面板与关系图谱
当回复涉及角色状态更新、场景切换、情感变化时，优先用 fenced HTML 代码块直接生成可视化状态栏，不要使用 `<status_hub>`、`<orange>` 或 `<context>` 包裹。

**角色状态栏 HTML：**
- 必须输出完整 fenced HTML 代码块，格式为从 ```html 开始到 ``` 结束。
- 只写状态栏 HTML 本身，不要在代码块外解释“这是状态栏”。
- 可以展示角色名、地点、内心想法、好感度、体力、魔力、情绪、任务进度等。
- 多角色状态可放在同一个 HTML 模块里，用卡片、标签、进度条或分栏区分。
- 所有样式必须写成元素上的行内 style 属性；禁止使用 `<style>`、`<html>`、`<head>`、`<body>`、`<script>`、iframe、外部 JS 或外部 CSS。
- 宽度不得超过 320px，居中显示，文字必须完整可读，不要滚动截断。

**关系图谱 `<relationship_map>`：**
用于展示角色之间的关系网络。格式：
```
<relationship_map>
角色A|角色B|关系类型|亲密度%
|||角色A|角色C|关系类型|亲密度%
</relationship_map>
```
- 关系类型支持：lover（恋人）、family（家人）、friend（朋友）、rival（对手）、mentor（导师）等
- 亲密度 0-100，影响线条粗细和颜色

**使用场景区分：**
- 角色状态、数值变化、内心想法、位置移动 → 用 fenced HTML 状态栏
- 角色之间的关系建立、变化、揭示 → 用 `<relationship_map>`
- 手机界面、社交媒体、购物页面、视频播放器等视觉排版 → 用 HTML

### 交互与特殊卡片渲染规则
当用户要求你“查看/打开/展示”某个应用（如查看手机、查看朋友圈、查看外卖订单、查看贴吧等）时，你必须且只能输出一个完整的 fenced HTML 代码块，格式为从 ```html 开始到 ``` 结束。
禁止在代码块外部包含任何文字、说明、状态或“这就是您要的”等 Markdown。
HTML 内容需贴合当前剧情/角色设定生成（例如：查看外卖时，生成符合角色设定的外卖订单记录）。
不要使用外部网络 HTML 模板资源，仅使用内联 CSS。当需要使用真实图片时，可以使用 [一只小猫的照片]、[一张风景图] 等文字占位符。
请保持整体尺寸不超过 320px。不要出现任何拖动条，请将所有内容直接全部展示，不要布局到滚动截断或隐藏的区域。
角色的主题色系统（可参考这些颜色）：#585eaa #21a675 #e0f0e9 #e3f9fd #b35c44 #ff7500 #6e511e #75878a #f3f9f1 #3d3b4f #000000 #ffffff #ffa631 #fa8c35 #eedeb0 #fff143 #7bcfa6 #a4e2c6 #a3d900 #c32136 #c83c23 #e4c6d0 #ffb3a7 #3de1ad #c3272b #8d4bbb #574266 #a1afc9 #4c8dae #2e4e7e #44cef6。
请应用丰富的设计并添加阴影，需要在 body 元素增加边框（只允许出现你要展示的应用版面）。

【应用软件生成专项指南】
如果是[视频软件]：要有全屏占位图、右侧的点赞/评论/转发操作栏、底部的文案与音乐滚动条。
如果是[外卖软件]：要有顶部的骑手地图占位、订单状态进度条、底部的菜单明细与特殊备注。或是角色的历史订单记录、他对这些订单的点评、商家或好友的回复（需要包含头像与昵称）。
如果是[朋友圈/小红书/贴吧]：必须要有图文瀑布流或列表排版、点赞列表、评论盖楼区。
如果是[购物软件]：要有角色的购买记录，对必需品/好物/奇葩物品的点评，以及友人或者商家的评论互动，可显示头像名字也可匿名。
色彩系统要求：必须严格还原该 APP 的经典主题色（如微信的经典绿、抖音的黑底白字配红蓝交错、美团外卖黄等）。
排版要求：务必整洁，UI 具有呼吸感。主文字大小不要超过 14px，评论区/次要信息等 11px-12px。

### 剧情 HTML 模块穿插规则
当回复是普通剧情、角色扮演、互动叙事或情绪描写时，可以根据当前剧情自然穿插 2 到 3 个 HTML 视觉模块；不要超过 3 个，避免影响正文阅读。
HTML 模块必须与正文剧情、角色心理、场景物件或互动行为紧密相关，可插在剧情段落之间，不能集中堆在末尾，不能脱离上下文。
每个模块都必须使用完整 fenced HTML 代码块包裹，格式必须从 ```html 开始并以 ``` 结束；不要使用 <orange> 包裹，因为客户端只会自动渲染 fenced HTML 代码块。
普通剧情回复可以包含正文，但 HTML 代码块外不要解释“这是模块”“下面是HTML”等元说明。
模块类型可以自由联想，包括但不限于：情绪日记、手写便签、留言板、待办清单、聊天记录、未读消息、社交动态、外卖订单、鲜花发票、快递签收单、网络小票、倒计时、闹钟提醒、天气卡片、GPS 导航、手机截图、转账记录、课堂笔记、涂鸦、搜索记录、词条解释、视频播放界面、音乐播放器、来电界面、梦境碎片、系统弹窗、情绪扫描图、古风花笺、飞剑传信、灵石账本、门派布令等。
每个模块必须有真实具体内容，必须使用中文为主，包含具体文字、时间、地点、价格、物件、评论、互动痕迹或心理细节；禁止空模板、占位模板、只换色不换结构。
每个模块宽度不得超过 320px，居中显示，文字必须完整可读；所有样式必须写成元素上的行内 style 属性，例如 <div style="background:#fff;padding:12px;border-radius:14px">；禁止使用 <style>、<html>、<head>、<body>、<script>、iframe、外部 JS 或外部 CSS。
模块之间必须风格多样，避免连续使用相同排版；可以使用拟物细节、emoji、纸张折痕、胶带、便签、iOS/安卓 UI、手账、古风纸笺等视觉语言。
如剧情很短或用户明确要求不要插入视觉模块，可以减少到 0 到 1 个；如剧情信息丰富，最多 3 个。
''';

  MessageBuilderService({
    required this.chatService,
    required this.contextProvider,
    this.ocrHandler,
    this.geminiThoughtSignatureHandler,
  });

  final ChatService chatService;

  /// Build context (used for accessing providers via context.read)
  final BuildContext contextProvider;

  /// OCR handler for processing images (optional, injected from home_page)
  final Future<String?> Function(List<String> imagePaths)? ocrHandler;

  /// OCR text wrapper function
  String Function(String ocrText)? ocrTextWrapper;

  /// Handler to append Gemini thought signatures for API calls
  final String Function(ChatMessage message, String content)?
  geminiThoughtSignatureHandler;

  /// Cache for document text extraction to avoid re-reading files on every message
  /// Keyed by path, validated with (modified + size) to avoid stale reuse.
  final Map<String, _DocTextCacheEntry> _docTextCache =
      <String, _DocTextCacheEntry>{};

  /// Collapse message versions to show only selected version per group.
  List<ChatMessage> collapseVersions(
    List<ChatMessage> items,
    Map<String, int> versionSelections,
  ) {
    final Map<String, List<ChatMessage>> byGroup =
        <String, List<ChatMessage>>{};
    final List<String> order = <String>[];

    for (final m in items) {
      final gid = (m.groupId ?? m.id);
      final list = byGroup.putIfAbsent(gid, () {
        order.add(gid);
        return <ChatMessage>[];
      });
      list.add(m);
    }

    // Sort each group by version
    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }

    // Select the appropriate version from each group
    final out = <ChatMessage>[];
    for (final gid in order) {
      final vers = byGroup[gid]!;
      final sel = versionSelections[gid];
      final idx = (sel != null && sel >= 0 && sel < vers.length)
          ? sel
          : (vers.length - 1);
      out.add(vers[idx]);
    }

    return out;
  }

  /// Build API messages list from current conversation state.
  ///
  /// Applies truncation, version collapsing, and strips [image:] / [file:] markers.
  List<Map<String, dynamic>> buildApiMessages({
    required List<ChatMessage> messages,
    required Map<String, int> versionSelections,
    required Conversation? currentConversation,
    bool includeToolMessages = false,
  }) {
    final tIndex = currentConversation?.truncateIndex ?? -1;
    final List<ChatMessage> sourceAll =
        (tIndex >= 0 && tIndex <= messages.length)
        ? messages.sublist(tIndex)
        : List.of(messages);
    final List<ChatMessage> source = collapseVersions(
      sourceAll,
      versionSelections,
    );

    final out = <Map<String, dynamic>>[];

    for (final m in source) {
      String? toolContinuationReasoningContent;
      if (includeToolMessages && m.role == 'assistant') {
        final events = chatService.getToolEvents(m.id);
        if (events.isNotEmpty) {
          // Tool-call history is only valid once every call has a result.
          final hasPendingToolEvent = events.any((e) => e['content'] == null);
          if (!hasPendingToolEvent) {
            toolContinuationReasoningContent =
                _reasoningContentForToolContinuation(m);
            final calls = <Map<String, dynamic>>[];
            final toolMessages = <Map<String, dynamic>>[];

            for (int i = 0; i < events.length; i++) {
              final e = events[i];
              final name = (e['name'] ?? '').toString().trim();
              if (name.isEmpty) continue;
              final rawId = (e['id'] ?? '').toString().trim();
              final id = rawId.isNotEmpty
                  ? rawId
                  : 'call_${m.id.substring(0, m.id.length < 8 ? m.id.length : 8)}_$i';

              Map<String, dynamic> args = const <String, dynamic>{};
              final a = e['arguments'];
              if (a is Map) {
                args = a.map((k, v) => MapEntry(k.toString(), v));
              }
              String argumentsJson = '{}';
              try {
                argumentsJson = jsonEncode(args);
              } catch (_) {}

              calls.add({
                'id': id,
                'type': 'function',
                'function': {'name': name, 'arguments': argumentsJson},
                if (e['metadata'] is Map)
                  'metadata': (e['metadata'] as Map).cast<String, dynamic>(),
              });

              final c = e['content'];
              toolMessages.add({
                'role': 'tool',
                'name': name,
                'tool_call_id': id,
                'content': c.toString(),
                if (e['metadata'] is Map)
                  'metadata': (e['metadata'] as Map).cast<String, dynamic>(),
              });
            }

            if (calls.isNotEmpty) {
              final assistantToolMessage = <String, dynamic>{
                'role': 'assistant',
                'content': '\n\n',
                'tool_calls': calls,
              };
              if (toolContinuationReasoningContent.isNotEmpty) {
                assistantToolMessage['reasoning_content'] =
                    toolContinuationReasoningContent;
              }
              out.add(assistantToolMessage);
              out.addAll(toolMessages);
            }
          }
        }
      }

      var content = m.content;
      if (m.role == 'assistant' && geminiThoughtSignatureHandler != null) {
        content = geminiThoughtSignatureHandler!(m, content);
      }
      if (content.isEmpty) continue;
      final message = <String, dynamic>{
        'role': m.role == 'assistant' ? 'assistant' : 'user',
        'content': content,
      };
      if (toolContinuationReasoningContent?.isNotEmpty == true) {
        message['reasoning_content'] = toolContinuationReasoningContent;
      }
      out.add(message);
    }

    return out;
  }

  ChatMessage? _latestPersistedMessage(ChatMessage message) {
    final persisted = chatService.getMessages(message.conversationId);
    for (final candidate in persisted) {
      if (candidate.id == message.id) return candidate;
    }
    return null;
  }

  String _reasoningContentForToolContinuation(ChatMessage message) {
    String pick(ChatMessage candidate) {
      final direct = (candidate.reasoningText ?? '').trim();
      if (direct.isNotEmpty) return direct;

      final raw = (candidate.reasoningSegmentsJson ?? '').trim();
      if (raw.isEmpty) return '';
      try {
        final decoded = jsonDecode(raw);
        final segmentsRaw = switch (decoded) {
          Map<String, dynamic> map => map['segments'],
          List<dynamic> list => list,
          _ => null,
        };
        if (segmentsRaw is! List) return '';
        final parts = <String>[];
        for (final item in segmentsRaw) {
          if (item is! Map) continue;
          final text = (item['text'] ?? '').toString().trim();
          if (text.isNotEmpty) parts.add(text);
        }
        return parts.join('\n').trim();
      } catch (_) {
        return '';
      }
    }

    final fromMessage = pick(message);
    if (fromMessage.isNotEmpty) return fromMessage;

    final persisted = _latestPersistedMessage(message);
    if (persisted == null) return '';
    return pick(persisted);
  }

  /// Parse input data from raw message content (extracts images and documents).
  ChatInputData parseInputFromRaw(
    String raw, {
    bool includeMediaFilePathsAsImages = true,
  }) {
    final imgRe = RegExp(r"\[image:(.+?)\]");
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    final favoriteRe = RegExp(r"\[favorite:([^|\]]*)\|([^|\]]*)\|([^\]]*)\]");
    final images = <String>[];
    final docs = <DocumentAttachment>[];
    final favoriteCards = <FavoriteCardReference>[];
    final buffer = StringBuffer();
    int idx = 0;
    while (idx < raw.length) {
      final imgMatch = imgRe.matchAsPrefix(raw, idx);
      final fileMatch = fileRe.matchAsPrefix(raw, idx);
      final favoriteMatch = favoriteRe.matchAsPrefix(raw, idx);
      if (imgMatch != null) {
        final p = imgMatch.group(1)?.trim();
        if (p != null && p.isNotEmpty) images.add(p);
        idx = imgMatch.end;
        continue;
      }
      if (fileMatch != null) {
        final path = fileMatch.group(1)?.trim() ?? '';
        final name = fileMatch.group(2)?.trim() ?? 'file';
        final mime = fileMatch.group(3)?.trim() ?? 'text/plain';
        final doc = DocumentAttachment(path: path, fileName: name, mime: mime);
        docs.add(doc);
        // Treat media attachments as image-style attachments for downstream API builders.
        final effectiveMime = _effectiveAttachmentMime(doc);
        if (includeMediaFilePathsAsImages &&
            (isVideoMime(effectiveMime) || isAudioMime(effectiveMime)) &&
            path.isNotEmpty) {
          images.add(path);
        }
        idx = fileMatch.end;
        continue;
      }
      if (favoriteMatch != null) {
        final ref = _favoriteReferenceFromMarker(favoriteMatch);
        if (ref != null) favoriteCards.add(ref);
        idx = favoriteMatch.end;
        continue;
      }
      buffer.write(raw[idx]);
      idx++;
    }
    return ChatInputData(
      text: buffer.toString().trim(),
      imagePaths: images,
      documents: docs,
      favoriteCards: favoriteCards,
    );
  }

  FavoriteCardReference? _favoriteReferenceFromMarker(Match match) {
    final id = _decodeFavoriteMarkerPart(match.group(1) ?? '');
    final title = _decodeFavoriteMarkerPart(match.group(2) ?? '');
    final text = _decodeFavoriteMarkerPart(match.group(3) ?? '');
    if (id == null || title == null || text == null || text.trim().isEmpty) {
      return null;
    }
    return FavoriteCardReference(id: id, title: title, text: text);
  }

  String? _decodeFavoriteMarkerPart(String value) {
    try {
      return utf8.decode(base64Url.decode(value));
    } catch (_) {
      return null;
    }
  }

  String _effectiveAttachmentMime(DocumentAttachment attachment) {
    return resolveDocumentAttachmentMime(attachment);
  }

  /// Process user messages in apiMessages: extract documents, apply OCR, inject file prompts.
  ///
  /// Returns the image paths from the last user message (for API call).
  Future<List<String>> processUserMessagesForApi(
    List<Map<String, dynamic>> apiMessages,
    SettingsProvider settings,
    Assistant? assistant,
  ) async {
    final bool ocrActive =
        settings.ocrEnabled &&
        settings.ocrModelProvider != null &&
        settings.ocrModelId != null;

    List<String>? lastUserImagePaths;

    // Find last user message index
    int lastUserIdx = -1;
    for (int i = apiMessages.length - 1; i >= 0; i--) {
      if (apiMessages[i]['role'] == 'user') {
        lastUserIdx = i;
        break;
      }
    }

    Future<String?> readDocument(DocumentAttachment d) async {
      // Use file stat to detect content changes without hashing.
      FileStat? stat;
      try {
        stat = await File(d.path).stat();
      } catch (_) {
        stat = null;
      }
      if (stat != null) {
        final cached = _docTextCache[d.path];
        if (cached != null &&
            cached.modifiedMs == stat.modified.millisecondsSinceEpoch &&
            cached.size == stat.size) {
          return cached.text;
        }
      }
      try {
        final text = await DocumentTextExtractor.extract(
          path: d.path,
          mime: d.mime,
        );
        // Cache only when stat is available; otherwise avoid staleness.
        if (stat != null) {
          _docTextCache[d.path] = _DocTextCacheEntry(
            text: text,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
            size: stat.size,
          );
        }
        return text;
      } catch (_) {
        if (stat != null) {
          _docTextCache[d.path] = _DocTextCacheEntry(
            text: null,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
            size: stat.size,
          );
        }
        return null;
      }
    }

    for (int i = 0; i < apiMessages.length; i++) {
      if (apiMessages[i]['role'] != 'user') continue;
      final rawUser = (apiMessages[i]['content'] ?? '').toString();
      final parsedUser = parseInputFromRaw(rawUser);
      final videoPaths = <String>{
        for (final d in parsedUser.documents)
          if (isVideoMime(_effectiveAttachmentMime(d))) d.path.trim(),
      }..removeWhere((p) => p.isEmpty);
      final audioPaths = <String>{
        for (final d in parsedUser.documents)
          if (isAudioMime(_effectiveAttachmentMime(d))) d.path.trim(),
      }..removeWhere((p) => p.isEmpty);

      final messageMediaPaths = parsedUser.imagePaths
          .map((p) => p.trim())
          .where(
            (p) =>
                p.isNotEmpty &&
                (!ocrActive ||
                    videoPaths.contains(p) ||
                    audioPaths.contains(p)),
          )
          .toSet()
          .toList(growable: false);
      if (messageMediaPaths.isEmpty) {
        apiMessages[i].remove(internalMediaPathsKey);
      } else {
        apiMessages[i][internalMediaPathsKey] = messageMediaPaths;
      }

      // Capture image paths from last user message
      if (i == lastUserIdx &&
          lastUserImagePaths == null &&
          parsedUser.imagePaths.isNotEmpty) {
        lastUserImagePaths = List<String>.of(parsedUser.imagePaths);
      }

      final inlineImagePaths = parsedUser.imagePaths
          .map((p) => p.trim())
          .where(
            (p) =>
                p.isNotEmpty &&
                !videoPaths.contains(p) &&
                !audioPaths.contains(p),
          )
          .toList(growable: false);

      // Apply replace-only regexes at send-time on user text (exclude markers).
      final replacedUserText = applyAssistantRegexes(
        parsedUser.text,
        assistant: assistant,
        scope: AssistantRegexScope.user,
        target: AssistantRegexTransformTarget.send,
      );

      final imageMarkers = (!ocrActive && inlineImagePaths.isNotEmpty)
          ? inlineImagePaths.map((p) => '\n[image:$p]').join()
          : '';
      final cleanedUser = (replacedUserText + imageMarkers).trim();

      final filePrompts = StringBuffer();
      for (final d in parsedUser.documents) {
        final effectiveMime = _effectiveAttachmentMime(d);
        if (isVideoMime(effectiveMime) || isAudioMime(effectiveMime)) {
          continue;
        }
        final text = await readDocument(d);
        if (text == null || text.trim().isEmpty) continue;
        filePrompts.writeln('## user sent a file: ${d.fileName}');
        filePrompts.writeln('<content>');
        filePrompts.writeln('```');
        filePrompts.writeln(text);
        filePrompts.writeln('```');
        filePrompts.writeln('</content>');
        filePrompts.writeln();
      }

      final favoritePrompts = parsedUser.favoriteCards
          .map((card) => card.text.trim())
          .where((text) => text.isNotEmpty)
          .join('\n\n');
      String merged = (filePrompts.toString() + cleanedUser).trim();
      if (favoritePrompts.isNotEmpty) {
        merged = merged.isEmpty
            ? favoritePrompts
            : '$merged\n\n$favoritePrompts';
      }

      if (ocrActive && ocrHandler != null) {
        final ocrTargets = parsedUser.imagePaths
            .map((p) => p.trim())
            .where(
              (p) =>
                  p.isNotEmpty &&
                  !videoPaths.contains(p) &&
                  !audioPaths.contains(p),
            )
            .toSet()
            .toList();
        if (ocrTargets.isNotEmpty) {
          final ocrText = await ocrHandler!(ocrTargets);
          if (ocrText != null && ocrText.trim().isNotEmpty) {
            final wrapped = ocrTextWrapper != null
                ? ocrTextWrapper!(ocrText)
                : _defaultWrapOcrBlock(ocrText);
            merged = (wrapped + merged).trim();
          }
        }
      }

      apiMessages[i]['content'] = merged.isEmpty ? cleanedUser : merged;
    }

    // Apply message template to last user message
    if (lastUserIdx != -1) {
      final userText = (apiMessages[lastUserIdx]['content'] ?? '').toString();
      final templ =
          (assistant?.messageTemplate ?? '{{ message }}').trim().isEmpty
          ? '{{ message }}'
          : (assistant!.messageTemplate);
      final templated = PromptTransformer.applyMessageTemplate(
        templ,
        role: 'user',
        message: userText,
        now: DateTime.now(),
      );
      apiMessages[lastUserIdx]['content'] = templated;
    }

    return lastUserImagePaths ?? <String>[];
  }

  /// Default OCR text wrapper
  String _defaultWrapOcrBlock(String ocrText) {
    final buf = StringBuffer();
    buf.writeln(
      "The image_file_ocr tag contains a description of an image that the user uploaded to you, not the user's prompt.",
    );
    buf.writeln('<image_file_ocr>');
    buf.writeln(ocrText.trim());
    buf.writeln('</image_file_ocr>');
    buf.writeln();
    return buf.toString();
  }

  /// Inject system prompt into apiMessages.
  void injectSystemPrompt(
    List<Map<String, dynamic>> apiMessages,
    Assistant? assistant,
    String modelId,
  ) {
    final systemParts = <String>[];
    if ((assistant?.systemPrompt.trim().isNotEmpty ?? false)) {
      final vars = PromptTransformer.buildPlaceholders(
        context: contextProvider,
        assistant: assistant!,
        modelId: modelId,
        modelName: modelId,
        userNickname: contextProvider.read<UserProvider>().name,
      );
      final sys = PromptTransformer.replacePlaceholders(
        assistant.systemPrompt,
        vars,
      );
      systemParts.add(sys);
    }

    systemParts.add(_htmlCardViewSystemInstruction.trim());

    if (systemParts.isNotEmpty) {
      apiMessages.insert(0, {
        'role': 'system',
        'content': systemParts.join('\n\n'),
      });
    }
  }

  /// Inject memory prompts and recent chats reference into apiMessages.
  Future<void> injectMemoryAndRecentChats(
    List<Map<String, dynamic>> apiMessages,
    Assistant? assistant, {
    String? currentConversationId,
  }) async {
    try {
      if (assistant?.enableMemory == true) {
        final mp = contextProvider.read<MemoryProvider>();
        await mp.initialize();
        final mems = mp.getForAssistant(assistant!.id);
        final currentHour = _formatCurrentHour(DateTime.now());
        final buf = StringBuffer();
        buf.writeln('## Memories');
        buf.writeln(
          'These are memories that you can reference in the future conversations.',
        );
        buf.writeln('<memories>');
        for (final m in mems) {
          buf.writeln('<record>');
          buf.writeln('<id>${m.id}</id>');
          buf.writeln('<content>${m.content}</content>');
          buf.writeln('</record>');
        }
        buf.writeln('</memories>');
        buf.writeln('''
## Memory Tool
你是一个无状态的大模型，你无法存储记忆，因此为了记住信息，你需要使用**记忆工具**。
你可以使用 `create_memory`, `edit_memory`, `delete_memory` 工具创建、更新或删除记忆。
- 如果记忆中没有相关信息，请使用 create_memory 创建一条新的记录。
- 如果已有相关记录，请使用 edit_memory 更新内容。
- 若记忆过时或无用，请使用 delete_memory 删除。
这些记忆会自动包含在未来的对话上下文中，在<memories>标签内。
请勿在记忆中存储敏感信息，敏感信息包括：用户的民族、宗教信仰、性取向、政治观点及党派归属、性生活、犯罪记录等。
在与用户聊天过程中，你可以像一个私人秘书一样**主动的**记录用户相关的信息到记忆里，包括但不限于：
- 用户昵称/姓名
- 年龄/性别/兴趣爱好
- 计划事项等
- 聊天风格偏好
- 工作相关
- 首次聊天时间
- ...
请主动调用工具记录，而不是需要用户要求。
记忆如果包含日期信息，请包含在内，请使用绝对时间格式，并且当前时间是$currentHour。
无需告知用户你已更改记忆记录，也不要在对话中直接显示记忆内容，除非用户主动要求。
相似或相关的记忆应合并为一条记录，而不要重复记录，过时记录应删除。
你可以在和用户闲聊的时候暗示用户你能记住东西。
''');
        _appendToSystemMessage(apiMessages, buf.toString());
      }
      if (assistant?.enableRecentChatsReference == true) {
        final chats = chatService.getAllConversations();
        final relevantChats = chats
            .where(
              (c) =>
                  c.assistantId == assistant!.id &&
                  c.id != currentConversationId,
            )
            .where((c) => c.title.trim().isNotEmpty)
            .take(10)
            .toList();
        if (relevantChats.isNotEmpty) {
          final sb = StringBuffer();
          sb.writeln('<recent_chats>');
          sb.writeln('这是用户最近的一些对话标题和摘要，你可以参考这些内容了解用户偏好和关注点');
          for (final c in relevantChats) {
            sb.writeln('<conversation>');
            // Format: timestamp: title || summary
            final timestamp = c.updatedAt.toIso8601String().substring(0, 10);
            final title = c.title.trim();
            final summary = (c.summary ?? '').trim();
            if (summary.isNotEmpty) {
              sb.writeln('  $timestamp: $title || $summary');
            } else {
              sb.writeln('  $timestamp: $title');
            }
            sb.writeln('</conversation>');
          }
          sb.writeln('</recent_chats>');
          _appendToSystemMessage(apiMessages, sb.toString());
        }
      }
    } catch (_) {}
  }

  String _formatCurrentHour(DateTime now) {
    return '${now.year}年${now.month}月${now.day}日的${now.hour}点';
  }

  /// Inject search tool usage prompt into apiMessages.
  void injectSearchPrompt(
    List<Map<String, dynamic>> apiMessages,
    SettingsProvider settings,
    Assistant? assistant,
    bool hasBuiltInSearch,
  ) {
    if (assistant?.searchEnabled == true && !hasBuiltInSearch) {
      final prompt = SearchToolService.getSystemPrompt();
      _appendToSystemMessage(apiMessages, prompt);
    }
  }

  /// Inject instruction injection prompts into apiMessages.
  Future<void> injectInstructionPrompts(
    List<Map<String, dynamic>> apiMessages,
    String? assistantId,
  ) async {
    try {
      List<InstructionInjection> actives = const <InstructionInjection>[];
      try {
        final ip = contextProvider.read<InstructionInjectionProvider>();
        actives = ip.activesFor(assistantId);
        if (actives.isEmpty) {
          actives = await InstructionInjectionStore.getActives(
            assistantId: assistantId,
          );
        }
      } catch (_) {
        actives = await InstructionInjectionStore.getActives(
          assistantId: assistantId,
        );
      }
      final prompts = actives
          .map((e) => e.prompt.trim())
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
      if (prompts.isNotEmpty) {
        final lp = prompts.join('\n\n');
        _appendToSystemMessage(apiMessages, lp);
      }
    } catch (_) {}
  }

  /// Inject world book (lorebook) entries into apiMessages.
  Future<void> injectWorldBookPrompts(
    List<Map<String, dynamic>> apiMessages,
    String? assistantId,
  ) async {
    try {
      List<WorldBook> all = const <WorldBook>[];
      List<String> activeBookIds = const <String>[];

      try {
        final wb = contextProvider.read<WorldBookProvider>();
        all = wb.books;
        activeBookIds = wb.activeBookIdsFor(assistantId);
        if (all.isEmpty) all = await WorldBookStore.getAll();
        if (activeBookIds.isEmpty) {
          activeBookIds = await WorldBookStore.getActiveIds(
            assistantId: assistantId,
          );
        }
      } catch (_) {
        all = await WorldBookStore.getAll();
        activeBookIds = await WorldBookStore.getActiveIds(
          assistantId: assistantId,
        );
      }

      if (all.isEmpty || activeBookIds.isEmpty) return;

      final activeSet = activeBookIds.toSet();
      final books = all
          .where((b) => b.enabled && activeSet.contains(b.id))
          .toList(growable: false);
      if (books.isEmpty) return;

      String extractContextForDepth(int scanDepth) {
        final depth = scanDepth <= 0 ? 1 : scanDepth;
        final parts = <String>[];
        for (
          int i = apiMessages.length - 1;
          i >= 0 && parts.length < depth;
          i--
        ) {
          final role = (apiMessages[i]['role'] ?? '').toString();
          if (role != 'user' && role != 'assistant') continue;
          final content = (apiMessages[i]['content'] ?? '').toString().trim();
          if (content.isEmpty) continue;
          parts.add(content);
        }
        return parts.reversed.join('\n');
      }

      bool isTriggered(WorldBookEntry entry, String context) {
        if (!entry.enabled) return false;
        if (entry.constantActive) return true;
        if (entry.keywords.isEmpty) return false;

        for (final raw in entry.keywords) {
          final keyword = raw.trim();
          if (keyword.isEmpty) continue;

          if (entry.useRegex) {
            try {
              final re = RegExp(keyword, caseSensitive: entry.caseSensitive);
              if (re.hasMatch(context)) return true;
            } catch (_) {}
          } else {
            if (entry.caseSensitive) {
              if (context.contains(keyword)) return true;
            } else {
              if (context.toLowerCase().contains(keyword.toLowerCase())) {
                return true;
              }
            }
          }
        }
        return false;
      }

      final contextCache = <int, String>{};
      final triggered = <({WorldBookEntry entry, int seq})>[];
      int seq = 0;

      for (final book in books) {
        for (final entry in book.entries) {
          final depth = (entry.scanDepth <= 0 ? 1 : entry.scanDepth)
              .clamp(1, 200)
              .toInt();
          final ctx = contextCache.putIfAbsent(
            depth,
            () => extractContextForDepth(depth),
          );
          if (isTriggered(entry, ctx)) {
            triggered.add((entry: entry, seq: seq));
          }
          seq++;
        }
      }

      if (triggered.isEmpty) return;

      triggered.sort((a, b) {
        final pa = a.entry.priority;
        final pb = b.entry.priority;
        if (pb != pa) return pb.compareTo(pa);
        return a.seq.compareTo(b.seq);
      });

      String wrapSystemTag(String content) => '<system>\n$content\n</system>';

      String joinContents(Iterable<WorldBookEntry> items) {
        return items
            .map((e) => e.content.trim())
            .where((c) => c.isNotEmpty)
            .join('\n');
      }

      List<Map<String, dynamic>> createMergedInjectionMessages(
        List<WorldBookEntry> injections,
      ) {
        final byRole = <WorldBookInjectionRole, List<WorldBookEntry>>{};
        for (final e in injections) {
          if (e.content.trim().isEmpty) continue;
          byRole.putIfAbsent(e.role, () => <WorldBookEntry>[]).add(e);
        }

        final result = <Map<String, dynamic>>[];
        for (final role in byRole.keys) {
          final group = byRole[role]!;
          final merged = joinContents(group);
          if (merged.isEmpty) continue;
          if (role == WorldBookInjectionRole.assistant) {
            result.add({'role': 'assistant', 'content': merged});
          } else {
            result.add({'role': 'user', 'content': wrapSystemTag(merged)});
          }
        }
        return result;
      }

      int findSafeInsertIndex(List<Map<String, dynamic>> messages, int target) {
        var index = target.clamp(0, messages.length);
        while (index > 0 && index < messages.length) {
          final role = (messages[index]['role'] ?? '').toString();
          if (role != 'tool') break;
          index--;
        }
        return index;
      }

      final byPosition = <WorldBookInjectionPosition, List<WorldBookEntry>>{};
      for (final t in triggered) {
        byPosition
            .putIfAbsent(t.entry.position, () => <WorldBookEntry>[])
            .add(t.entry);
      }

      // BEFORE/AFTER_SYSTEM_PROMPT: merge into system message.
      final beforeContent = joinContents(
        byPosition[WorldBookInjectionPosition.beforeSystemPrompt] ??
            const <WorldBookEntry>[],
      );
      final afterContent = joinContents(
        byPosition[WorldBookInjectionPosition.afterSystemPrompt] ??
            const <WorldBookEntry>[],
      );

      if (beforeContent.isNotEmpty || afterContent.isNotEmpty) {
        final systemIndex = apiMessages.indexWhere(
          (m) => (m['role'] ?? '').toString() == 'system',
        );
        if (systemIndex >= 0) {
          final original = (apiMessages[systemIndex]['content'] ?? '')
              .toString();
          final sb = StringBuffer();
          if (beforeContent.isNotEmpty) {
            sb.write(beforeContent);
            sb.write('\n');
          }
          sb.write(original);
          if (afterContent.isNotEmpty) {
            sb.write('\n');
            sb.write(afterContent);
          }
          apiMessages[systemIndex]['content'] = sb.toString();
        } else {
          final sb = StringBuffer();
          if (beforeContent.isNotEmpty) sb.write(beforeContent);
          if (afterContent.isNotEmpty) {
            if (sb.isNotEmpty) sb.write('\n');
            sb.write(afterContent);
          }
          if (sb.isNotEmpty) {
            apiMessages.insert(0, {'role': 'system', 'content': sb.toString()});
          }
        }
      }

      // TOP_OF_CHAT: insert before first user message.
      final topInjections = byPosition[WorldBookInjectionPosition.topOfChat];
      if (topInjections != null && topInjections.isNotEmpty) {
        var insertIndex = apiMessages.indexWhere(
          (m) => (m['role'] ?? '').toString() == 'user',
        );
        if (insertIndex < 0) insertIndex = apiMessages.length;
        insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
        apiMessages.insertAll(
          insertIndex,
          createMergedInjectionMessages(topInjections),
        );
      }

      // BOTTOM_OF_CHAT: insert before last message.
      final bottomInjections =
          byPosition[WorldBookInjectionPosition.bottomOfChat];
      if (bottomInjections != null && bottomInjections.isNotEmpty) {
        var insertIndex = apiMessages.isEmpty ? 0 : (apiMessages.length - 1);
        insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
        apiMessages.insertAll(
          insertIndex,
          createMergedInjectionMessages(bottomInjections),
        );
      }

      // AT_DEPTH: insert at depth from end (depth=1 means before last message).
      final atDepthInjections = byPosition[WorldBookInjectionPosition.atDepth];
      if (atDepthInjections != null && atDepthInjections.isNotEmpty) {
        final byDepth = <int, List<WorldBookEntry>>{};
        for (final e in atDepthInjections) {
          final depth = (e.injectDepth <= 0 ? 1 : e.injectDepth)
              .clamp(1, 200)
              .toInt();
          byDepth.putIfAbsent(depth, () => <WorldBookEntry>[]).add(e);
        }

        final depths = byDepth.keys.toList(growable: false)
          ..sort((a, b) => b.compareTo(a));

        for (final depth in depths) {
          final injections = byDepth[depth] ?? const <WorldBookEntry>[];
          var insertIndex = (apiMessages.length - depth).clamp(
            0,
            apiMessages.length,
          );
          insertIndex = findSafeInsertIndex(apiMessages, insertIndex);
          apiMessages.insertAll(
            insertIndex,
            createMergedInjectionMessages(injections),
          );
        }
      }
    } catch (_) {}
  }

  /// Helper to append content to the system message (or create one if missing).
  void _appendToSystemMessage(
    List<Map<String, dynamic>> apiMessages,
    String content,
  ) {
    if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
      apiMessages[0]['content'] =
          '${(apiMessages[0]['content'] ?? '') as String}\n\n$content';
    } else {
      apiMessages.insert(0, {'role': 'system', 'content': content});
    }
  }

  /// Apply context message limit based on assistant settings.
  void applyContextLimit(
    List<Map<String, dynamic>> apiMessages,
    Assistant? assistant,
  ) {
    if ((assistant?.limitContextMessages ?? true) &&
        (assistant?.contextMessageSize ?? 0) > 0) {
      final int keep = (assistant!.contextMessageSize).clamp(
        Assistant.minContextMessageSize,
        Assistant.maxContextMessageSize,
      );
      int startIdx = 0;
      if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
        startIdx = 1;
      }
      final tail = apiMessages.sublist(startIdx);
      if (tail.length > keep) {
        final trimmed = tail.sublist(tail.length - keep);
        apiMessages
          ..removeRange(startIdx, apiMessages.length)
          ..addAll(trimmed);
      }
      // Context trimming can cut in the middle of a tool-call triplet; avoid sending dangling tool messages.
      while (apiMessages.length > startIdx &&
          (apiMessages[startIdx]['role'] ?? '').toString() == 'tool') {
        apiMessages.removeAt(startIdx);
      }
    }
  }

  /// Convert local Markdown image links to inline base64 for model context.
  Future<void> inlineLocalImages(List<Map<String, dynamic>> apiMessages) async {
    for (int i = 0; i < apiMessages.length; i++) {
      final s = (apiMessages[i]['content'] ?? '').toString();
      if (s.isNotEmpty) {
        apiMessages[i]['content'] =
            await MarkdownMediaSanitizer.inlineLocalImagesToBase64(s);
      }
    }
  }

  /// Check if built-in search is enabled for the given provider/model.
  bool hasBuiltInSearch(
    SettingsProvider settings,
    String providerKey,
    String modelId,
  ) {
    try {
      final cfg = settings.getProviderConfig(providerKey);
      return BuiltInToolsHelper.isBuiltInSearchEnabled(
        cfg: cfg,
        modelId: modelId,
      );
    } catch (_) {
      return false;
    }
  }
}

class _DocTextCacheEntry {
  const _DocTextCacheEntry({
    required this.text,
    required this.modifiedMs,
    required this.size,
  });

  final String? text;
  final int modifiedMs;
  final int size;
}

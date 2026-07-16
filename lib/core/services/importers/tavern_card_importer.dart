import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../models/assistant_regex.dart';
import '../../models/assistant.dart';
import '../../models/assistant_play_mode.dart';
import '../../models/preset_message.dart';
import '../../models/world_book.dart';

class TavernCardImportResult {
  const TavernCardImportResult({required this.assistant, this.worldBook});

  final Assistant assistant;
  final WorldBook? worldBook;
}

class TavernCardImporter {
  static const List<int> _pngSignature = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  static Assistant? parseV2Json(String jsonString) {
    return parseV2JsonWithWorldBook(jsonString)?.assistant;
  }

  static TavernCardImportResult? parseFileBytes(
    List<int> bytes, {
    String? fileName,
    bool includeWorldBook = true,
  }) {
    final lowerName = (fileName ?? '').toLowerCase();
    if (lowerName.endsWith('.png') || _looksLikePng(bytes)) {
      final jsonString = _extractJsonFromPng(bytes);
      if (jsonString == null) return null;
      return parseV2JsonWithWorldBook(
        jsonString,
        includeWorldBook: includeWorldBook,
      );
    }

    try {
      final text = utf8.decode(bytes);
      if (lowerName.endsWith('.html') || _looksLikeHtmlDocument(text)) {
        return _parseHtmlOpening(text, fileName: fileName);
      }
      return parseV2JsonWithWorldBook(text, includeWorldBook: includeWorldBook);
    } catch (_) {
      return null;
    }
  }

  static TavernCardImportResult? parseV2JsonWithWorldBook(
    String jsonString, {
    bool includeWorldBook = true,
  }) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final spec = data['spec'] ?? '';

      Map<String, dynamic> charData;
      if (spec == 'chara_card_v2' || data.containsKey('data')) {
        charData = data['data'] as Map<String, dynamic>? ?? {};
      } else {
        // Fallback for V1 or flat JSON
        charData = data;
      }

      final String name = charData['name'] ?? 'Unnamed Character';
      final String description = charData['description'] ?? '';
      final String personality = charData['personality'] ?? '';
      final String scenario = charData['scenario'] ?? '';
      final String firstMessage = charData['first_mes'] ?? '';
      final String mesExample = charData['mes_example'] ?? '';
      final String systemPrompt = charData['system_prompt'] ?? '';
      final String postHistoryInstructions =
          charData['post_history_instructions'] ?? '';

      final StringBuffer sb = StringBuffer();

      if (systemPrompt.isNotEmpty) {
        sb.writeln(systemPrompt);
        sb.writeln('\n---');
      }

      if (description.isNotEmpty) {
        sb.writeln('\n[Character Description]');
        sb.writeln(description);
      }

      if (personality.isNotEmpty) {
        sb.writeln('\n[Personality Traits]');
        sb.writeln(personality);
      }

      if (scenario.isNotEmpty) {
        sb.writeln('\n[Scenario Context]');
        sb.writeln(scenario);
      }

      if (mesExample.isNotEmpty) {
        sb.writeln('\n[Dialogue Examples]');
        sb.writeln(mesExample);
      }

      if (postHistoryInstructions.isNotEmpty) {
        sb.writeln('\n[Final Instructions / Post History]');
        sb.writeln(postHistoryInstructions);
      }

      // Also look for group or extra prompts from the file you provided
      if (data.containsKey('prompts')) {
        final prompts = data['prompts'] as List?;
        if (prompts != null) {
          sb.writeln('\n[Extensions & Rules]');
          for (final p in prompts) {
            if (p is Map && p['enabled'] == true) {
              final pContent = p['content'];
              if (pContent != null && pContent.toString().trim().isNotEmpty) {
                final pName = p['name'] ?? 'Unknown Rule';
                sb.writeln('\n### Rule: $pName');
                sb.writeln(pContent.toString());
              }
            }
          }
        }
      }

      final List<PresetMessage> presets = [];
      if (_isValidGreeting(firstMessage)) {
        presets.add(
          PresetMessage(
            id: const Uuid().v4(),
            role: 'assistant',
            content: firstMessage.trim(),
          ),
        );
      }

      final alternateGreetings = charData['alternate_greetings'];
      if (alternateGreetings is List) {
        for (final item in alternateGreetings) {
          final content = item?.toString().trim() ?? '';
          if (!_isValidGreeting(content)) continue;
          presets.add(
            PresetMessage(
              id: const Uuid().v4(),
              role: 'assistant',
              content: content,
            ),
          );
        }
      }

      final assistant = Assistant(
        id: const Uuid().v4(),
        name: name,
        systemPrompt: sb.toString().trim(),
        presetMessages: presets,
        regexRules: _parseRegexRules(charData),
        playMode: AssistantPlayMode.game,
      );
      return TavernCardImportResult(
        assistant: assistant,
        worldBook: includeWorldBook
            ? _parseCharacterBook(data, charData, assistant.name)
            : null,
      );
    } catch (e) {
      return null;
    }
  }

  static TavernCardImportResult? _parseHtmlOpening(
    String html, {
    String? fileName,
  }) {
    final content = html.trim();
    if (!_looksLikeHtmlDocument(content)) return null;
    final title = _extractHtmlTitle(content) ?? _fileStem(fileName) ?? 'HTML';
    final assistant = Assistant(
      id: const Uuid().v4(),
      name: title,
      presetMessages: [
        PresetMessage(
          id: const Uuid().v4(),
          role: 'assistant',
          content: content,
        ),
      ],
      playMode: AssistantPlayMode.game,
    );
    return TavernCardImportResult(assistant: assistant);
  }

  static bool _looksLikeHtmlDocument(String text) {
    final lower = text.trimLeft().toLowerCase();
    return lower.startsWith('<!doctype html') || lower.startsWith('<html');
  }

  static String? _extractHtmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    final title = match?.group(1)?.trim();
    if (title == null || title.isEmpty) return null;
    return title.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _fileStem(String? fileName) {
    final name = fileName?.trim();
    if (name == null || name.isEmpty) return null;
    final slash = name.lastIndexOf(RegExp(r'[\\/]'));
    final base = slash == -1 ? name : name.substring(slash + 1);
    final dot = base.lastIndexOf('.');
    final stem = dot <= 0 ? base : base.substring(0, dot);
    return stem.trim().isEmpty ? null : stem.trim();
  }

  static List<AssistantRegex> _parseRegexRules(Map<String, dynamic> charData) {
    final extensions = charData['extensions'];
    if (extensions is! Map) return const <AssistantRegex>[];
    final rawScripts = extensions['regex_scripts'];
    if (rawScripts is! List) return const <AssistantRegex>[];

    final rules = <AssistantRegex>[];
    for (final raw in rawScripts) {
      if (raw is! Map) continue;
      if (raw['disabled'] == true) continue;
      final pattern = _normalizeRegexPattern(
        raw['findRegex']?.toString() ?? '',
      );
      final replacement = raw['replaceString']?.toString() ?? '';
      if (pattern.trim().isEmpty) continue;

      final scopes = <AssistantRegexScope>{};
      final placement = raw['placement'];
      if (placement is List) {
        if (placement.contains(1)) scopes.add(AssistantRegexScope.user);
        if (placement.contains(2)) scopes.add(AssistantRegexScope.assistant);
      }
      if (scopes.isEmpty) scopes.add(AssistantRegexScope.assistant);

      rules.add(
        AssistantRegex(
          id: raw['id']?.toString() ?? const Uuid().v4(),
          name: raw['scriptName']?.toString() ?? 'Tavern Regex',
          pattern: pattern,
          replacement: replacement,
          scopes: scopes.toList(growable: false),
          visualOnly: true,
        ),
      );
    }
    return rules;
  }

  static bool _isValidGreeting(String content) {
    final text = content.trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return !(lower.startsWith('error: cannot read ') &&
        lower.contains('this model does not support image input'));
  }

  static String _normalizeRegexPattern(String pattern) {
    final trimmed = pattern.trim();
    if (!trimmed.startsWith('/')) return trimmed;
    final lastSlash = trimmed.lastIndexOf('/');
    if (lastSlash <= 0) return trimmed;
    return trimmed.substring(1, lastSlash);
  }

  static WorldBook? _parseCharacterBook(
    Map<String, dynamic> data,
    Map<String, dynamic> charData,
    String characterName,
  ) {
    final rawBook = charData['character_book'] ?? data['character_book'];
    if (rawBook is! Map) return null;

    final entriesRaw = rawBook['entries'];
    final entriesList = entriesRaw is List
        ? entriesRaw
        : entriesRaw is Map
        ? entriesRaw.values.toList(growable: false)
        : const <dynamic>[];
    if (entriesList.isEmpty) return null;

    final entries = <WorldBookEntry>[];
    for (final rawEntry in entriesList) {
      if (rawEntry is! Map) continue;
      final content = rawEntry['content']?.toString() ?? '';
      if (content.trim().isEmpty) continue;

      final keys = <String>[
        ..._stringList(rawEntry['keys'] ?? rawEntry['key']),
        ..._stringList(rawEntry['secondary_keys'] ?? rawEntry['keysecondary']),
      ];
      final extensions = rawEntry['extensions'];
      final ext = extensions is Map ? extensions : const <dynamic, dynamic>{};
      final constant =
          _boolValue(rawEntry['constant']) ||
          (keys.isEmpty && !_boolValue(rawEntry['selective']));
      final depth = _intValue(ext['depth'] ?? rawEntry['depth'], 4);

      entries.add(
        WorldBookEntry(
          id: const Uuid().v4(),
          name: rawEntry['comment']?.toString() ?? '',
          enabled:
              !_boolValue(rawEntry['disable']) &&
              !_boolValue(rawEntry['disabled']) &&
              rawEntry['enabled'] != false,
          priority: _intValue(
            rawEntry['insertion_order'] ?? rawEntry['order'],
            100,
          ),
          position: _mapWorldBookPosition(
            ext['position'] ?? rawEntry['position'],
          ),
          content: content,
          injectDepth: depth,
          role: _mapWorldBookRole(ext['role'] ?? rawEntry['role']),
          keywords: keys,
          useRegex: _boolValue(rawEntry['use_regex'] ?? rawEntry['useRegex']),
          caseSensitive: _boolValue(
            rawEntry['case_sensitive'] ?? rawEntry['caseSensitive'],
          ),
          scanDepth: _intValue(
            rawEntry['scanDepth'] ?? rawEntry['scan_depth'],
            depth,
          ),
          constantActive: constant,
        ),
      );
    }

    if (entries.isEmpty) return null;
    final name = rawBook['name']?.toString().trim();
    return WorldBook(
      id: const Uuid().v4(),
      name: name?.isNotEmpty == true ? name! : '$characterName World Book',
      description: 'Imported from Tavern character_book.',
      entries: entries,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1';
  }

  static int _intValue(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static WorldBookInjectionPosition _mapWorldBookPosition(dynamic value) {
    if (value is num) {
      switch (value.toInt()) {
        case 0:
          return WorldBookInjectionPosition.beforeSystemPrompt;
        case 2:
          return WorldBookInjectionPosition.topOfChat;
        case 3:
          return WorldBookInjectionPosition.bottomOfChat;
        case 4:
          return WorldBookInjectionPosition.atDepth;
        case 1:
        default:
          return WorldBookInjectionPosition.afterSystemPrompt;
      }
    }
    return WorldBookInjectionPositionJson.fromJson(value);
  }

  static WorldBookInjectionRole _mapWorldBookRole(dynamic value) {
    if (value is num) {
      return value.toInt() == 1
          ? WorldBookInjectionRole.assistant
          : WorldBookInjectionRole.user;
    }
    return WorldBookInjectionRoleJson.fromJson(value);
  }

  static bool _looksLikePng(List<int> bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  static String? _extractJsonFromPng(List<int> bytes) {
    if (!_looksLikePng(bytes)) return null;
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    var offset = _pngSignature.length;

    while (offset + 12 <= data.length) {
      final length = _readUint32(data, offset);
      final typeStart = offset + 4;
      final dataStart = offset + 8;
      final dataEnd = dataStart + length;
      final nextOffset = dataEnd + 4;
      if (length < 0 || dataEnd > data.length || nextOffset > data.length) {
        return null;
      }

      final type = ascii.decode(data.sublist(typeStart, typeStart + 4));
      final chunk = data.sublist(dataStart, dataEnd);
      final extracted = switch (type) {
        'tEXt' => _extractTextChunk(chunk),
        'iTXt' => _extractInternationalTextChunk(chunk),
        _ => null,
      };
      if (extracted != null) return extracted;
      if (type == 'IEND') break;
      offset = nextOffset;
    }

    return null;
  }

  static String? _extractTextChunk(Uint8List chunk) {
    final separator = chunk.indexOf(0);
    if (separator <= 0 || separator >= chunk.length - 1) return null;
    final key = latin1.decode(chunk.sublist(0, separator));
    final value = latin1.decode(chunk.sublist(separator + 1));
    return _decodeTavernPngValue(key, value);
  }

  static String? _extractInternationalTextChunk(Uint8List chunk) {
    final keyEnd = chunk.indexOf(0);
    if (keyEnd <= 0 || keyEnd + 3 >= chunk.length) return null;
    final key = utf8.decode(chunk.sublist(0, keyEnd), allowMalformed: true);
    final compressionFlag = chunk[keyEnd + 1];
    if (compressionFlag != 0) return null;

    var cursor = keyEnd + 3;
    final languageEnd = _indexOfZero(chunk, cursor);
    if (languageEnd == -1) return null;
    cursor = languageEnd + 1;
    final translatedKeyEnd = _indexOfZero(chunk, cursor);
    if (translatedKeyEnd == -1) return null;
    cursor = translatedKeyEnd + 1;
    if (cursor >= chunk.length) return null;

    final value = utf8.decode(chunk.sublist(cursor), allowMalformed: true);
    return _decodeTavernPngValue(key, value);
  }

  static String? _decodeTavernPngValue(String key, String value) {
    final normalizedKey = key.trim().toLowerCase();
    if (normalizedKey != 'chara' &&
        normalizedKey != 'character' &&
        normalizedKey != 'ccv3') {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.startsWith('{')) return trimmed;

    try {
      return utf8.decode(base64.decode(trimmed));
    } catch (_) {
      try {
        return utf8.decode(base64Url.decode(trimmed));
      } catch (_) {
        return null;
      }
    }
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static int _indexOfZero(Uint8List bytes, int start) {
    for (var i = start; i < bytes.length; i++) {
      if (bytes[i] == 0) return i;
    }
    return -1;
  }
}

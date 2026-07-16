import 'dart:convert';

import 'package:Kelivo/core/services/importers/tavern_card_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Tavern character data from PNG chara text chunk', () {
    final cardJson = jsonEncode({
      'spec': 'chara_card_v2',
      'data': {
        'name': '方亦楷',
        'first_mes': '开场白',
        'alternate_greetings': ['第二开场'],
      },
    });

    final png = _pngWithTextChunk('chara', base64Encode(utf8.encode(cardJson)));
    final result = TavernCardImporter.parseFileBytes(
      png,
      fileName: 'fang_yikai.png',
    );

    expect(result, isNotNull);
    expect(result!.assistant.name, '方亦楷');
    expect(result.assistant.presetMessages.map((m) => m.content), [
      '开场白',
      '第二开场',
    ]);
  });

  test('ignores image reader error text in greetings', () {
    final cardJson = jsonEncode({
      'spec': 'chara_card_v2',
      'data': {
        'name': '方亦楷',
        'first_mes':
            'ERROR: Cannot read "C:\\Users\\zxz12\\Downloads/16c2f7714827eb99.png" (this model does not support image input). Inform the user.',
        'alternate_greetings': ['第二开场'],
      },
    });

    final result = TavernCardImporter.parseV2JsonWithWorldBook(cardJson);

    expect(result, isNotNull);
    expect(result!.assistant.presetMessages.map((m) => m.content), ['第二开场']);
  });

  test('keeps regex-backed opening trigger greeting', () {
    final cardJson = jsonEncode({
      'spec': 'chara_card_v3',
      'data': {
        'name': '方亦楷2.0',
        'first_mes': '【开场】\r\n',
        'alternate_greetings': ['普通开场'],
        'extensions': {
          'regex_scripts': [
            {
              'scriptName': '开局美化',
              'findRegex': '【开场】',
              'replaceString': '```html\n<div>选择开场白</div>\n```',
              'placement': [2],
              'disabled': false,
            },
          ],
        },
      },
    });

    final result = TavernCardImporter.parseV2JsonWithWorldBook(cardJson);

    expect(result, isNotNull);
    expect(result!.assistant.presetMessages.map((m) => m.content), [
      '【开场】',
      '普通开场',
    ]);
    expect(result.assistant.regexRules, hasLength(1));
    expect(result.assistant.regexRules.single.pattern, '【开场】');
  });

  test('parses full html document as game opening', () {
    const html = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <title>桃色欲都 · 简介生成器</title>
</head>
<body><button>开始欲都之旅</button></body>
</html>''';

    final result = TavernCardImporter.parseFileBytes(
      utf8.encode(html),
      fileName: 'intro.html',
    );

    expect(result, isNotNull);
    expect(result!.assistant.name, '桃色欲都 · 简介生成器');
    expect(result.assistant.presetMessages, hasLength(1));
    expect(result.assistant.presetMessages.single.role, 'assistant');
    expect(result.assistant.presetMessages.single.content, html);
    expect(result.worldBook, isNull);
  });

  test('can skip embedded character book for game import', () {
    final cardJson = jsonEncode({
      'spec': 'chara_card_v2',
      'data': {
        'name': '方亦楷',
        'first_mes': '开场白',
        'character_book': {
          'name': '角色卡内嵌世界书',
          'entries': [
            {'comment': '规则', 'content': '这条规则应由 Kelivo 世界书功能单独管理。'},
          ],
        },
      },
    });

    final result = TavernCardImporter.parseFileBytes(
      utf8.encode(cardJson),
      fileName: 'card.json',
      includeWorldBook: false,
    );

    expect(result, isNotNull);
    expect(result!.assistant.name, '方亦楷');
    expect(result.worldBook, isNull);
  });
}

List<int> _pngWithTextChunk(String key, String value) {
  final signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  return <int>[
    ...signature,
    ..._chunk('tEXt', <int>[...latin1.encode(key), 0, ...latin1.encode(value)]),
    ..._chunk('IEND', const <int>[]),
  ];
}

List<int> _chunk(String type, List<int> data) {
  return <int>[
    ..._uint32(data.length),
    ...ascii.encode(type),
    ...data,
    0,
    0,
    0,
    0,
  ];
}

List<int> _uint32(int value) {
  return <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

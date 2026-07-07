import 'package:flutter/foundation.dart';

import '../../features/home/widgets/mini_map_status_hub.dart';
import '../models/chat_message.dart';

/// Reactive store for parsed `<status_hub>` data.
/// Updated during streaming BEFORE the content reaches UI, so the chat
/// never shows raw tags and the status panel updates independently.
class StatusDataStore {
  StatusDataStore._();

  static final _entries = ValueNotifier<List<CharacterData>>([]);
  static ValueNotifier<List<CharacterData>> get entries => _entries;

  static void update(List<CharacterData> data) {
    _entries.value = data;
  }

  static void clear() {
    _entries.value = [];
  }

  /// Re-parse all stored messages to rebuild state (used on app restart).
  static void rebuildFromMessages(List<ChatMessage> messages) {
    final parsed = parseMiniMapStatusHub(messages);
    if (parsed.isNotEmpty) {
      _entries.value = parsed.map(_toCharacterData).toList();
    }
  }

  static CharacterData _toCharacterData(MiniMapStatusEntry entry) {
    String? location;
    String? gender;
    String? age;
    String? height;
    String? birthday;
    String? appearanceFace;
    String? appearanceBody;
    String? likes;
    String? dislikes;
    String? monologue;
    final tags = <String>[];

    for (final f in entry.infoFields) {
      switch (f.key) {
        case '地点':
        case 'location':
          location = f.value;
          break;
        case '性别':
        case 'gender':
          gender = f.value;
          break;
        case '年龄':
        case 'age':
          age = f.value;
          break;
        case '身高':
        case 'height':
          height = f.value;
          break;
        case '生日':
        case 'birthday':
          birthday = f.value;
          break;
        case '长相':
        case 'appearance':
          appearanceFace = f.value;
          break;
        case '身材':
        case 'body':
          appearanceBody = f.value;
          break;
        case '喜欢':
        case '喜欢与爱好':
        case 'likes':
        case 'hobbies':
          likes = f.value;
          break;
        case '讨厌':
        case 'dislikes':
          dislikes = f.value;
          break;
        case '想法':
        case '内心独白':
        case 'thought':
        case 'monologue':
          monologue = f.value;
          break;
        default:
          tags.add(f.value);
      }
    }

    for (final mod in entry.modules) {
      switch (mod.key) {
        case '长相':
        case 'appearance':
          appearanceFace = mod.value;
          break;
        case '身材':
        case 'body':
          appearanceBody = mod.value;
          break;
        case '喜欢':
        case '喜欢与爱好':
        case 'likes':
        case 'hobbies':
          likes = mod.value;
          break;
        case '讨厌':
        case 'dislikes':
          dislikes = mod.value;
          break;
        case '内心独白':
        case '想法':
          monologue ??= mod.value;
          break;
      }
    }

    return CharacterData(
      name: entry.name,
      location: location,
      gender: gender,
      age: age,
      height: height,
      birthday: birthday,
      tags: tags,
      appearanceFace: appearanceFace,
      appearanceBody: appearanceBody,
      likes: likes,
      dislikes: dislikes,
      innerMonologue: monologue,
      meters: entry.meters,
      modules: entry.modules,
    );
  }
}

/// Structured character data matching the HTML layout's sections.
class CharacterData {
  const CharacterData({
    required this.name,
    this.location,
    this.gender,
    this.age,
    this.height,
    this.birthday,
    this.tags = const [],
    this.appearanceFace,
    this.appearanceBody,
    this.likes,
    this.dislikes,
    this.innerMonologue,
    this.meters = const [],
    this.modules = const [],
  });

  final String name;
  final String? location;
  final String? gender;
  final String? age;
  final String? height;
  final String? birthday;
  final List<String> tags;
  final String? appearanceFace;
  final String? appearanceBody;
  final String? likes;
  final String? dislikes;
  final String? innerMonologue;
  final List<MeterField> meters;
  final List<ModuleField> modules;

  bool get hasInfo =>
      gender != null ||
      age != null ||
      height != null ||
      birthday != null ||
      location != null;

  bool get hasAppearance => appearanceFace != null || appearanceBody != null;

  bool get hasMindset => likes != null || dislikes != null;

  /// Tags that represent personality traits (short values).
  List<String> get personalityTags => tags.where((t) => t.length <= 8).toList();
}

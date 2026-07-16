import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../models/assistant.dart';
import '../../models/assistant_play_mode.dart';
import '../../models/saved_preset.dart';

class TavernPresetImporter {
  static Assistant? parsePresetJson(String jsonString) {
    final preset = parseToSavedPreset(jsonString);
    if (preset == null) return null;
    return Assistant(
      id: const Uuid().v4(),
      name: preset.name,
      systemPrompt: preset.systemPrompt,
      mainPrompt: preset.mainPrompt,
      rules: List<PresetRule>.from(preset.rules),
      playMode: AssistantPlayMode.game,
    );
  }

  static SavedPreset? parseToSavedPreset(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (!data.containsKey('prompts') &&
          data['format'] != 'ai-phone-toolbox') {
        return null;
      }

      final prompts = data['prompts'] as List?;
      if (prompts == null || prompts.isEmpty) return null;

      final mainEntry = prompts.firstWhere(
        (p) =>
            (p is Map &&
            (p['identifier'] == 'main' ||
                p['name'] == 'main' ||
                p['name'] == '汪🐶')),
        orElse: () => null,
      );

      String presetName = '导入预设';
      String mainPrompt = '';
      final rules = <PresetRule>[];

      if (mainEntry is Map && mainEntry['enabled'] == true) {
        presetName = (mainEntry['name'] as String?) ?? presetName;
        mainPrompt = (mainEntry['content'] as String?) ?? '';
      }

      for (final p in prompts) {
        if (p is Map && p['identifier'] != 'main') {
          final pName = p['name']?.toString() ?? 'Unknown Rule';
          final pContent = p['content']?.toString() ?? '';
          if (pContent.trim().isNotEmpty) {
            rules.add(
              PresetRule(
                name: pName,
                content: pContent,
                enabled: p['enabled'] == true,
              ),
            );
          }
        }
      }

      return SavedPreset(
        name: presetName,
        mainPrompt: mainPrompt,
        rules: rules,
      );
    } catch (e) {
      return null;
    }
  }
}

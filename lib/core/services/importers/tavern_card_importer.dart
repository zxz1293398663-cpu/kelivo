import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../models/assistant.dart';
import '../../models/assistant_play_mode.dart';
import '../../models/preset_message.dart';

class TavernCardImporter {
  static Assistant? parseV2Json(String jsonString) {
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
      final String postHistoryInstructions = charData['post_history_instructions'] ?? '';

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
      if (firstMessage.isNotEmpty) {
        presets.add(PresetMessage(
          id: const Uuid().v4(),
          role: 'assistant',
          content: firstMessage,
        ));
      }

      return Assistant(
        id: const Uuid().v4(),
        name: name,
        systemPrompt: sb.toString().trim(),
        presetMessages: presets,
        playMode: AssistantPlayMode.game,
      );
    } catch (e) {
      return null;
    }
  }
}

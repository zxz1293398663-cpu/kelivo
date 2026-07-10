import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../models/assistant.dart';
import '../../models/assistant_play_mode.dart';

class TavernPresetImporter {
  static Assistant? parsePresetJson(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      // Check if it's a SillyTavern or compatible Prompt/Preset format
      if (!data.containsKey('prompts') && data['format'] != 'ai-phone-toolbox') {
        return null;
      }

      final prompts = data['prompts'] as List?;
      if (prompts == null || prompts.isEmpty) return null;

      final StringBuffer sb = StringBuffer();
      
      final mainPrompt = prompts.firstWhere(
        (p) => (p['identifier'] == 'main' || p['name'] == 'main' || p['name'] == '汪🐶'), 
        orElse: () => null
      );
      
      if (mainPrompt != null && mainPrompt['enabled'] == true) {
        sb.writeln(mainPrompt['content'] ?? '');
      }

      sb.writeln('\n[Extensions & Rules]');
      for (final p in prompts) {
          if (p is Map && p['enabled'] == true && p['identifier'] != 'main') {
            final pName = p['name'] ?? 'Unknown Rule';
            final pContent = p['content'];
            if (pContent != null && pContent.toString().trim().isNotEmpty) {
               sb.writeln('\n### Rule: $pName');
               sb.writeln(pContent.toString());
            }
          }
      }
      
      String presetName = '导入预设';
      if (mainPrompt != null && mainPrompt['name'] != null) {
          presetName = mainPrompt['name'].toString();
      }

      return Assistant(
        id: const Uuid().v4(),
        name: presetName,
        systemPrompt: sb.toString().trim(),
        playMode: AssistantPlayMode.game,
      );
    } catch (e) {
      return null;
    }
  }
}

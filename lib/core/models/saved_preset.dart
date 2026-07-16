import 'package:uuid/uuid.dart';

class PresetRule {
  final String id;
  String name;
  String content;
  bool enabled;

  PresetRule({
    String? id,
    required this.name,
    required this.content,
    this.enabled = true,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'enabled': enabled,
  };

  factory PresetRule.fromJson(Map<String, dynamic> json) => PresetRule(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    content: json['content'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
  );
}

class SavedPreset {
  final String id;
  String name;
  String mainPrompt;
  List<PresetRule> rules;

  SavedPreset({
    String? id,
    required this.name,
    this.mainPrompt = '',
    List<PresetRule>? rules,
  }) : id = id ?? const Uuid().v4(),
       rules = rules ?? [];

  String get systemPrompt {
    final sb = StringBuffer();
    if (mainPrompt.isNotEmpty) {
      sb.writeln(mainPrompt);
    }
    for (final rule in rules.where((r) => r.enabled)) {
      sb.writeln('\n### Rule: ${rule.name}');
      sb.writeln(rule.content);
    }
    return sb.toString().trim();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mainPrompt': mainPrompt,
    'rules': rules.map((r) => r.toJson()).toList(),
  };

  factory SavedPreset.fromJson(Map<String, dynamic> json) => SavedPreset(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    mainPrompt: json['mainPrompt'] as String? ?? '',
    rules:
        (json['rules'] as List?)
            ?.map((e) => PresetRule.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  /// Parse a flat systemPrompt string (with ### Rule: markers) back
  /// into structured fields. Used when loading presets saved with the old format.
  factory SavedPreset.fromPromptString({
    required String id,
    required String name,
    required String systemPrompt,
  }) {
    final ruleRegex = RegExp(r'^### Rule:\s*(.+)$', multiLine: true);
    final matches = ruleRegex.allMatches(systemPrompt).toList();
    if (matches.isEmpty) {
      return SavedPreset(id: id, name: name, mainPrompt: systemPrompt);
    }
    final sb = StringBuffer();
    int lastEnd = 0;
    final rules = <PresetRule>[];
    for (final m in matches) {
      sb.write(systemPrompt.substring(lastEnd, m.start).trim());
      lastEnd = m.end;
      final ruleName = m.group(1)?.trim() ?? '';
      final nextStart = m.end;
      final nextMatchIndex = matches.indexOf(m) + 1;
      final ruleEnd = nextMatchIndex < matches.length
          ? matches[nextMatchIndex].start
          : systemPrompt.length;
      final content = systemPrompt.substring(nextStart, ruleEnd).trim();
      rules.add(PresetRule(name: ruleName, content: content));
    }
    sb.write(systemPrompt.substring(lastEnd).trim());
    return SavedPreset(
      id: id,
      name: name,
      mainPrompt: sb.toString().trim(),
      rules: rules,
    );
  }
}

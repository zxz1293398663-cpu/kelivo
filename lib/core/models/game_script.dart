/// 叙事分类 / 基调
enum ScriptStyle {
  dailyHealing,
  epicAdventure,
  suspenseMystery,
  romanceEnsemble,
  urbanWeird,
  ancientPower,
  romanceDrama,
}

/// 自定义属性定义
class GameAttribute {
  final String id;
  String name;
  double value;
  double min;
  double max;

  GameAttribute({
    String? id,
    required this.name,
    this.value = 100,
    this.min = 0,
    this.max = 100,
  }) : id = id ?? name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    'min': min,
    'max': max,
  };

  factory GameAttribute.fromJson(Map<String, dynamic> json) => GameAttribute(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    value: (json['value'] as num?)?.toDouble() ?? 100,
    min: (json['min'] as num?)?.toDouble() ?? 0,
    max: (json['max'] as num?)?.toDouble() ?? 100,
  );
}

/// 金钱/资源
class GameResource {
  final String id;
  String name;
  double value;

  GameResource({String? id, required this.name, this.value = 0})
    : id = id ?? name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'value': value};

  factory GameResource.fromJson(Map<String, dynamic> json) => GameResource(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    value: (json['value'] as num?)?.toDouble() ?? 0,
  );
}

/// 玩家角色信息
class PlayerInfo {
  String name;
  String gender;
  String? avatar;
  String description;

  PlayerInfo({
    this.name = '旅人',
    this.gender = '其他',
    this.avatar,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'avatar': avatar,
    'description': description,
  };

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
    name: json['name'] as String? ?? '旅人',
    gender: json['gender'] as String? ?? '其他',
    avatar: json['avatar'] as String?,
    description: json['description'] as String? ?? '',
  );
}

/// 游戏剧本
class GameScript {
  final String id;
  String title;
  String instructions;
  ScriptStyle style;
  PlayerInfo? player;
  List<GameAttribute> attributes;
  List<GameResource> resources;
  List<NpcTemplate> npcTemplates;

  GameScript({
    String? id,
    required this.title,
    this.instructions = '',
    this.style = ScriptStyle.epicAdventure,
    PlayerInfo? player,
    List<GameAttribute>? attributes,
    List<GameResource>? resources,
    List<NpcTemplate>? npcTemplates,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       player = player ?? PlayerInfo(),
       attributes = attributes ?? _defaultAttributes(),
       resources = resources ?? _defaultResources(),
       npcTemplates = npcTemplates ?? [];

  static List<GameAttribute> _defaultAttributes() => [
    GameAttribute(name: '体力', value: 100, min: 0, max: 100),
    GameAttribute(name: '理智', value: 100, min: 0, max: 100),
    GameAttribute(name: '警觉', value: 50, min: 0, max: 100),
    GameAttribute(name: '魅力', value: 50, min: 0, max: 100),
  ];

  static List<GameResource> _defaultResources() => [
    GameResource(name: '金钱', value: 100),
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'instructions': instructions,
    'style': style.name,
    'player': player?.toJson(),
    'attributes': attributes.map((a) => a.toJson()).toList(),
    'resources': resources.map((r) => r.toJson()).toList(),
    'npcTemplates': npcTemplates.map((n) => n.toJson()).toList(),
  };

  factory GameScript.fromJson(Map<String, dynamic> json) => GameScript(
    id: json['id'] as String?,
    title: json['title'] as String? ?? '',
    instructions: json['instructions'] as String? ?? '',
    style: ScriptStyle.values.firstWhere(
      (s) => s.name == json['style'],
      orElse: () => ScriptStyle.epicAdventure,
    ),
    player: json['player'] != null
        ? PlayerInfo.fromJson(json['player'] as Map<String, dynamic>)
        : PlayerInfo(),
    attributes:
        (json['attributes'] as List?)
            ?.map((e) => GameAttribute.fromJson(e as Map<String, dynamic>))
            .toList() ??
        _defaultAttributes(),
    resources:
        (json['resources'] as List?)
            ?.map((e) => GameResource.fromJson(e as Map<String, dynamic>))
            .toList() ??
        _defaultResources(),
    npcTemplates:
        (json['npcTemplates'] as List?)
            ?.map((e) => NpcTemplate.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

/// NPC 模板（剧本预设）
class NpcTemplate {
  final String id;
  String name;
  String? avatar;
  String identity;
  String location;
  String description;
  String? stSource;

  NpcTemplate({
    String? id,
    required this.name,
    this.avatar,
    this.identity = '',
    this.location = '',
    this.description = '',
    this.stSource,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'identity': identity,
    'location': location,
    'description': description,
    'stSource': stSource,
  };

  factory NpcTemplate.fromJson(Map<String, dynamic> json) => NpcTemplate(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    avatar: json['avatar'] as String?,
    identity: json['identity'] as String? ?? '',
    location: json['location'] as String? ?? '',
    description: json['description'] as String? ?? '',
    stSource: json['stSource'] as String?,
  );
}

/// 游戏会话状态
class GameState {
  String currentScene;
  String gameTime;
  List<GameNpc> npcs;
  List<GameEvent> activeEvents;
  List<GameEvent> completedEvents;
  String currentNarrative;
  String attributeChanges;

  GameState({
    this.currentScene = '初始之地',
    this.gameTime = '第1年·1月',
    List<GameNpc>? npcs,
    List<GameEvent>? activeEvents,
    List<GameEvent>? completedEvents,
    this.currentNarrative = '',
    this.attributeChanges = '',
  }) : npcs = npcs ?? [],
       activeEvents = activeEvents ?? [],
       completedEvents = completedEvents ?? [];

  Map<String, dynamic> toJson() => {
    'currentScene': currentScene,
    'gameTime': gameTime,
    'npcs': npcs.map((n) => n.toJson()).toList(),
    'activeEvents': activeEvents.map((e) => e.toJson()).toList(),
    'completedEvents': completedEvents.map((e) => e.toJson()).toList(),
    'currentNarrative': currentNarrative,
    'attributeChanges': attributeChanges,
  };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    currentScene: json['currentScene'] as String? ?? '初始之地',
    gameTime: json['gameTime'] as String? ?? '第1年·1月',
    npcs:
        (json['npcs'] as List?)
            ?.map((e) => GameNpc.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    activeEvents:
        (json['activeEvents'] as List?)
            ?.map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    completedEvents:
        (json['completedEvents'] as List?)
            ?.map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    currentNarrative: json['currentNarrative'] as String? ?? '',
    attributeChanges: json['attributeChanges'] as String? ?? '',
  );
}

/// 已登场 NPC
class GameNpc {
  final String id;
  String name;
  String? avatar;
  String identity;
  String location;
  String description;
  String relation;
  String notes;
  DateTime firstMet;

  GameNpc({
    String? id,
    required this.name,
    this.avatar,
    this.identity = '',
    this.location = '',
    this.description = '',
    this.relation = '',
    this.notes = '',
    DateTime? firstMet,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       firstMet = firstMet ?? DateTime.now();

  factory GameNpc.fromTemplate(NpcTemplate template) => GameNpc(
    name: template.name,
    avatar: template.avatar,
    identity: template.identity,
    location: template.location,
    description: template.description,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'identity': identity,
    'location': location,
    'description': description,
    'relation': relation,
    'notes': notes,
    'firstMet': firstMet.toIso8601String(),
  };

  factory GameNpc.fromJson(Map<String, dynamic> json) => GameNpc(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    avatar: json['avatar'] as String?,
    identity: json['identity'] as String? ?? '',
    location: json['location'] as String? ?? '',
    description: json['description'] as String? ?? '',
    relation: json['relation'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    firstMet: json['firstMet'] != null
        ? DateTime.parse(json['firstMet'] as String)
        : DateTime.now(),
  );
}

/// 事件
class GameEvent {
  final String id;
  String title;
  String description;
  bool completed;
  DateTime createdAt;

  GameEvent({
    String? id,
    required this.title,
    this.description = '',
    this.completed = false,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'completed': completed,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
    id: json['id'] as String?,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    completed: json['completed'] as bool? ?? false,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}

enum AssistantPlayMode {
  novel,
  game,
}

extension AssistantPlayModeExt on AssistantPlayMode {
  String get name {
    switch (this) {
      case AssistantPlayMode.novel:
        return 'novel';
      case AssistantPlayMode.game:
        return 'game';
    }
  }

  static AssistantPlayMode fromName(String? name) {
    if (name == 'game') return AssistantPlayMode.game;
    return AssistantPlayMode.novel;
  }
}

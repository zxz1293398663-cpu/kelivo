import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/game_script.dart';
import '../services/game_storage_service.dart';

class GameProvider extends ChangeNotifier {
  GameScript? _script;
  GameState? _state;
  String? _playerName;
  final _storage = GameStorageService();
  bool _loaded = false;
  Future<void>? _loadFuture;
  String? _scopeId;

  GameScript? get script => _script;
  GameState? get state => _state;
  bool get hasScript => _script != null;
  bool get loaded => _loaded;
  String? get scopeId => _scopeId;
  String? get playerName {
    final scripted = _script?.player?.name.trim() ?? '';
    if (scripted.isNotEmpty) return scripted;
    final saved = _playerName?.trim() ?? '';
    return saved.isEmpty ? null : saved;
  }

  /// Eagerly start loading. Call from constructor or early lifecycle.
  GameProvider() {
    init();
  }

  Future<void> _load() async {
    if (_loaded) return;
    final scriptJson = await _storage.loadScriptJson(scopeId: _scopeId);
    final stateJson = await _storage.loadStateJson(scopeId: _scopeId);
    _playerName = await _storage.loadPlayerName();
    if (scriptJson != null && scriptJson.isNotEmpty) {
      _script = GameScript.fromJson(
        jsonDecode(scriptJson) as Map<String, dynamic>,
      );
    }
    if (stateJson != null && stateJson.isNotEmpty) {
      _state = GameState.fromJson(
        jsonDecode(stateJson) as Map<String, dynamic>,
      );
    }
    _loaded = true;
    notifyListeners();
  }

  /// Alias kept for explicit call sites; safe to call multiple times.
  Future<void> init() => _loadFuture ??= _load();

  Future<void> useScope(String? scopeId) async {
    final next = scopeId?.trim();
    if (_scopeId == next && _loaded) return;
    _scopeId = next == null || next.isEmpty ? null : next;
    _script = null;
    _state = null;
    _loaded = false;
    _loadFuture = null;
    notifyListeners();
    await init();
  }

  Future<void> _persist() async {
    await _storage.saveScriptJson(
      _script != null ? jsonEncode(_script!.toJson()) : null,
      scopeId: _scopeId,
    );
    await _storage.saveStateJson(
      _state != null ? jsonEncode(_state!.toJson()) : null,
      scopeId: _scopeId,
    );
  }

  Future<void> setScript(GameScript script) async {
    final savedName = _playerName?.trim() ?? '';
    if (savedName.isNotEmpty) {
      script.player ??= PlayerInfo();
      script.player!.name = savedName;
    }
    _script = script;
    _state = GameState(
      currentScene: '初始之地',
      gameTime: '第1年·1月',
      npcs: _script!.npcTemplates.map((t) => GameNpc.fromTemplate(t)).toList(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> updatePlayerName(String name) async {
    final value = name.trim();
    if (value.isEmpty) return;
    _playerName = value;
    if (_script != null) {
      _script!.player ??= PlayerInfo();
      _script!.player!.name = value;
      await _persist();
    }
    await _storage.savePlayerName(value);
    notifyListeners();
  }

  Future<void> updatePlayerAvatar(String? avatar) async {
    if (_script == null) return;
    _script!.player ??= PlayerInfo();
    final value = avatar?.trim();
    _script!.player!.avatar = value == null || value.isEmpty ? null : value;
    await _persist();
    notifyListeners();
  }

  Future<void> updateState(GameState Function(GameState) updater) async {
    if (_state == null) return;
    _state = updater(_state!);
    await _persist();
    notifyListeners();
  }

  void updateAttribute(String id, double delta) {
    if (_script == null) return;
    final idx = _script!.attributes.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    _script!.attributes[idx].value = (_script!.attributes[idx].value + delta)
        .clamp(_script!.attributes[idx].min, _script!.attributes[idx].max);
    notifyListeners();
  }

  void updateResource(String id, double delta) {
    if (_script == null) return;
    final idx = _script!.resources.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _script!.resources[idx].value += delta;
    notifyListeners();
  }

  Future<void> addEvent(GameEvent event) async {
    if (_state == null) return;
    _state!.activeEvents.add(event);
    notifyListeners();
  }

  Future<void> completeEvent(String eventId) async {
    if (_state == null) return;
    final idx = _state!.activeEvents.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;
    final event = _state!.activeEvents.removeAt(idx);
    event.completed = true;
    _state!.completedEvents.add(event);
    notifyListeners();
  }

  Future<void> addNpc(GameNpc npc) async {
    if (_state == null) return;
    _state!.npcs.add(npc);
    notifyListeners();
  }

  Future<void> clear() async {
    _script = null;
    _state = null;
    _playerName = null;
    await _persist();
    await _storage.savePlayerName(null);
    notifyListeners();
  }

  Future<void> deleteScript() async {
    _script = null;
    _state = null;
    _playerName = null;
    await _persist();
    await _storage.savePlayerName(null);
    notifyListeners();
  }
}

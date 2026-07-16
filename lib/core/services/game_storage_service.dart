import 'package:shared_preferences/shared_preferences.dart';

class GameStorageService {
  static const _scriptKey = 'game_current_script';
  static const _stateKey = 'game_current_state';
  static const _playerNameKey = 'game_player_name';
  static const _modelProviderKey = 'game_model_provider';
  static const _modelIdKey = 'game_model_id';

  String _scopedKey(String key, String? scopeId) {
    final scope = scopeId?.trim();
    if (scope == null || scope.isEmpty) return key;
    return '${key}_$scope';
  }

  Future<String?> loadScriptJson({String? scopeId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_scriptKey, scopeId));
  }

  Future<String?> loadStateJson({String? scopeId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_stateKey, scopeId));
  }

  Future<void> saveScriptJson(String? json, {String? scopeId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_scriptKey, scopeId);
    if (json != null) {
      await prefs.setString(key, json);
    } else {
      await prefs.remove(key);
    }
  }

  Future<void> saveStateJson(String? json, {String? scopeId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_stateKey, scopeId);
    if (json != null) {
      await prefs.setString(key, json);
    } else {
      await prefs.remove(key);
    }
  }

  Future<String?> loadPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_playerNameKey);
  }

  Future<void> savePlayerName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    final value = name?.trim();
    if (value != null && value.isNotEmpty) {
      await prefs.setString(_playerNameKey, value);
    } else {
      await prefs.remove(_playerNameKey);
    }
  }

  String? getModelProvider() {
    // Sync read - caller should await if needed
    return null; // placeholder
  }

  String? getModelId() {
    return null; // placeholder
  }

  Future<void> setModel(String? provider, String? modelId) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider != null) {
      await prefs.setString(_modelProviderKey, provider);
    } else {
      await prefs.remove(_modelProviderKey);
    }
    if (modelId != null) {
      await prefs.setString(_modelIdKey, modelId);
    } else {
      await prefs.remove(_modelIdKey);
    }
  }

  Future<String?> loadModelProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelProviderKey);
  }

  Future<String?> loadModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelIdKey);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scriptKey);
    await prefs.remove(_stateKey);
    await prefs.remove(_playerNameKey);
  }
}

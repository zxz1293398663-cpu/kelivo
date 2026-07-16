import 'package:Kelivo/core/models/game_script.dart';
import 'package:Kelivo/core/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists game player name before script creation', () async {
    SharedPreferences.setMockInitialValues(const {});

    final provider = GameProvider();
    await provider.init();

    await provider.updatePlayerName('  游戏名  ');

    expect(provider.playerName, '游戏名');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('game_player_name'), '游戏名');
  });

  test('applies saved game player name to created script', () async {
    SharedPreferences.setMockInitialValues(const {'game_player_name': '江湖名'});

    final provider = GameProvider();
    await provider.init();

    await provider.setScript(GameScript(title: '测试游戏'));

    expect(provider.playerName, '江湖名');
    expect(provider.script!.player!.name, '江湖名');
  });
}

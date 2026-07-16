import 'package:Kelivo/features/game/models/scene_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SceneCardParser', () {
    test('parses newspaper scene card', () {
      const input =
          ':::newspaper 寒假|周六|下午三点 / 时翊桉 # 猫不叫你你就过去 # 她来的时候是风，走的时候也是风，只有你站在原地，像个被遗弃的风向标 # 客厅沙发 ✦ 冬日暖阳穿过半拉的窗帘落在地毯上';

      final card = SceneCardParser.parse(input);

      expect(card, isNotNull);
      expect(card!.type, 'newspaper');
      expect(card.timeParts, ['寒假', '周六', '下午三点']);
      expect(card.characterName, '时翊桉');
      expect(card.items, [
        '猫不叫你你就过去',
        '她来的时候是风，走的时候也是风，只有你站在原地，像个被遗弃的风向标',
        '客厅沙发 ✦ 冬日暖阳穿过半拉的窗帘落在地毯上',
      ]);
      expect(card.title, '猫不叫你你就过去');
      expect(card.sceneDescription, '客厅沙发 ✦ 冬日暖阳穿过半拉的窗帘落在地毯上');
    });

    test('trims repeated whitespace and empty time parts', () {
      const input = '  :::newspaper  寒假 | 周六 || 下午三点   /   时翊桉   #  客厅沙发  ';

      final card = SceneCardParser.parse(input);

      expect(card, isNotNull);
      expect(card!.timeParts, ['寒假', '周六', '下午三点']);
      expect(card.characterName, '时翊桉');
      expect(card.items, ['客厅沙发']);
    });

    test('parses arbitrary text with the same separators', () {
      const input = ':::starship 第一纪元|雨夜/ 领航员A# 信号丢失 # 舰桥 ✦ 蓝色警报闪烁';

      final card = SceneCardParser.parse(input);

      expect(card, isNotNull);
      expect(card!.type, 'starship');
      expect(card.timeParts, ['第一纪元', '雨夜']);
      expect(card.characterName, '领航员A');
      expect(card.items, ['信号丢失', '舰桥 ✦ 蓝色警报闪烁']);
    });

    test('returns null for invalid formats', () {
      expect(SceneCardParser.parse('newspaper 寒假 / 时翊桉'), isNull);
      expect(SceneCardParser.parse(':::newspaper'), isNull);
      expect(SceneCardParser.parse(':::newspaper 寒假 时翊桉'), isNull);
      expect(SceneCardParser.parse(':::newspaper 寒假 / '), isNull);
    });

    test('builds instructions for script creation', () {
      const input = ':::newspaper 寒假|周六|下午三点 / 时翊桉 # 猫不叫你你就过去 # 客厅沙发';

      final instructions = SceneCardParser.parse(input)!.toInstructions(
        typeLabel: '类型：',
        timeLabel: '时间：',
        characterLabel: '角色：',
        itemsLabel: '要素：',
      );

      expect(instructions, contains('类型：newspaper'));
      expect(instructions, contains('时间：寒假 / 周六 / 下午三点'));
      expect(instructions, contains('角色：时翊桉'));
      expect(instructions, contains('- 猫不叫你你就过去'));
      expect(instructions, contains('- 客厅沙发'));
    });
  });
}

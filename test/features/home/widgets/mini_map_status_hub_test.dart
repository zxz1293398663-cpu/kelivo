import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/widgets/mini_map_status_hub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseMiniMapStatusHub parses latest assistant status hub entries', () {
    final entries = parseMiniMapStatusHub([
      ChatMessage(
        role: 'assistant',
        content:
            '<status_hub>旧角色\n地点: 旧地点\n想法: 旧想法\n---\n好感度: 1%\n欲望: 2%\n</status_hub>',
        conversationId: 'c1',
      ),
      ChatMessage(role: 'user', content: '继续', conversationId: 'c1'),
      ChatMessage(
        role: 'assistant',
        content:
            '<status_hub>谢维尔\n地点: 私人酒窖\n想法: 这女人的眼神真让人受不了\n---\n好感度: 85%\n欲望: 92%\n---\n当前姿势: 右手摇晃红酒杯\n眼神: 落在她的嘴唇上\n渴望: 更过分的接触\n|||\n阿尔文\n地点: 私人酒窖门口\n想法: 我得盯着周围\n---\n警惕: 40%\n体力: 15%\n---\n持有物: 战术手电\n状态: 警惕\n听觉: 捕捉细微声响\n</status_hub>',
        conversationId: 'c1',
      ),
    ]);

    expect(entries, hasLength(2));
    expect(entries.first.name, '谢维尔');
    expect(entries.first.meters, hasLength(2));
    expect(entries.first.meters[0].label, '好感度');
    expect(entries.first.meters[0].value, 85);
    expect(entries.first.meters[1].label, '欲望');
    expect(entries.first.meters[1].value, 92);
    expect(entries.first.modules, hasLength(3));
    expect(entries.first.modules[0].key, '当前姿势');
    expect(entries[1].name, '阿尔文');
    expect(entries[1].infoFields.any((f) => f.key == '地点'), true);
    expect(
      entries[1].infoFields.firstWhere((f) => f.key == '地点').value,
      '私人酒窖门口',
    );
  });

  test('parseMiniMapStatusHub clamps invalid percentage values', () {
    final entries = parseMiniMapStatusHub([
      ChatMessage(
        role: 'assistant',
        content:
            '<status_hub>角色\n地点: 某处\n想法: 想法\n---\n好感度: 140%\n欲望: -5%\n</status_hub>',
        conversationId: 'c1',
      ),
    ]);

    expect(entries.single.meters[0].value, 100);
    expect(entries.single.meters[1].value, 0);
  });
}

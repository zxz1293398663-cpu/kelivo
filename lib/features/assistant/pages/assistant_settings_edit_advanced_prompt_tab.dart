part of 'assistant_settings_edit_page.dart';

class _AdvancedPromptTab extends StatefulWidget {
  const _AdvancedPromptTab({required this.assistantId});
  final String assistantId;

  @override
  State<_AdvancedPromptTab> createState() => _AdvancedPromptTabState();
}

class _AdvancedPromptTabState extends State<_AdvancedPromptTab> {
  List<Map<String, dynamic>> _blocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  void _loadBlocks() {
    final a = context.read<AssistantProvider>().getById(widget.assistantId);
    if (a == null) return;
    
    final prompt = a.systemPrompt;
    final ruleRegex = RegExp(r'\n### Rule: ([^\n]+)\n((?:(?!\n### Rule: ).)*)', dotAll: true);
    final matches = ruleRegex.allMatches('\n' + prompt);
    
    final newBlocks = <Map<String, dynamic>>[];
    for (final m in matches) {
      newBlocks.add({
        'name': m.group(1)?.trim() ?? 'Unknown',
        'content': m.group(2)?.trim() ?? '',
        'enabled': true, 
      });
    }
    
    setState(() {
      _blocks = newBlocks;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_blocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Lucide.Settings2, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                '未检测到高级规则模块',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 8),
              Text(
                '您可以通过导入酒馆/Vercel预设 (JSON) 来加载动态规则。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _blocks.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4),
            child: Text(
              '已加载的规则与触发器 (${_blocks.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        final block = _blocks[index - 1];
        final isEnabled = block['enabled'] as bool;
        
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                IosSwitch(
                  value: isEnabled,
                  onChanged: (val) {
                    setState(() => block['enabled'] = val);
                    _saveBlocks();
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    block['name'] as String,
                    style: TextStyle(
                      fontWeight: AppFontWeights.medium,
                      fontSize: 14,
                      color: isEnabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  block['content'] as String,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveBlocks() {
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId);
    if (a == null) return;
    
    final oldPrompt = a.systemPrompt;
    final splitIndex = oldPrompt.indexOf('\n[Extensions & Rules]');
    final basePrompt = splitIndex != -1 ? oldPrompt.substring(0, splitIndex) : oldPrompt;
    
    final sb = StringBuffer();
    sb.write(basePrompt);
    sb.writeln('\n\n[Extensions & Rules]');
    
    for (final block in _blocks) {
      if (block['enabled'] == true) {
        sb.writeln('\n### Rule: ${block['name']}');
        sb.writeln(block['content']);
      }
    }
    
    ap.updateAssistant(a.copyWith(systemPrompt: sb.toString().trim()));
  }
}

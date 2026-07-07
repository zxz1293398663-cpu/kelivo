import 'dart:ui';
import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../theme/app_font_weights.dart';

/// Detect if text contains a known special tag.
bool hasSpecialTag(String text) {
  return _specialTagExp.hasMatch(text);
}

/// Known special tag types.
enum SpecialTagType {
  novaOs,
  kindleBar,
  kindleUi,
  statusCard,
  wechatMoments,
  twitterCard,
  bgm,
  statusHub,
}

SpecialTagType? detectSpecialTagType(String text) {
  final s = text.trim();
  if (s.startsWith('<nova_os>')) return SpecialTagType.novaOs;
  if (s.startsWith('<kindle_bar>')) return SpecialTagType.kindleBar;
  if (s.startsWith('<kindle_ui>')) return SpecialTagType.kindleUi;
  if (s.startsWith('<status_card>')) return SpecialTagType.statusCard;
  if (s.startsWith('<wechat_moments_status>')) {
    return SpecialTagType.wechatMoments;
  }
  if (s.startsWith('<twitter_card>')) return SpecialTagType.twitterCard;
  if (s.startsWith('<bgm>')) return SpecialTagType.bgm;
  if (s.contains('<status_hub>')) return SpecialTagType.statusHub;
  return null;
}

IconData iconForTag(SpecialTagType type) {
  switch (type) {
    case SpecialTagType.novaOs:
      return Lucide.Phone;
    case SpecialTagType.kindleBar:
    case SpecialTagType.kindleUi:
      return Lucide.BookOpen;
    case SpecialTagType.statusCard:
      return Lucide.BookOpenText;
    case SpecialTagType.wechatMoments:
      return Lucide.MessageCircle;
    case SpecialTagType.twitterCard:
      return Lucide.Volume2;
    case SpecialTagType.bgm:
      return Lucide.Volume2;
    case SpecialTagType.statusHub:
      return Lucide.Activity;
  }
}

String labelForTag(SpecialTagType type) {
  switch (type) {
    case SpecialTagType.novaOs:
      return 'NovaOS';
    case SpecialTagType.kindleBar:
      return 'Kindle';
    case SpecialTagType.kindleUi:
      return 'Kindle UI';
    case SpecialTagType.statusCard:
      return 'Journal';
    case SpecialTagType.wechatMoments:
      return 'Moments';
    case SpecialTagType.twitterCard:
      return 'Music';
    case SpecialTagType.bgm:
      return 'BGM';
    case SpecialTagType.statusHub:
      return 'Status';
  }
}

final RegExp _specialTagExp = RegExp(
  _novaOsPattern,
  dotAll: true,
  multiLine: true,
);

const String _novaOsPattern =
    r'<nova_os>\s*\[StatusBar\|(.*?)\|(.*?)\]\s*'
    r'\[MusicMeta\|(.*?)\|(.*?)\]\s*'
    r'\[Memo\|(.*?)\|(.*?)\|(.*?)\]\s*'
    r'\[WeChat\|(.*?)\]\s*'
    r'\[Diary\|(.*?)\|(.*?)\]\s*'
    r'\[Forum\|(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*?)\]\s*'
    r'\[Gemini\|(.*?)\|(.*?)\]\s*'
    r'\[Thoughts\|(.*?)\]\s*'
    r'\[SecretMsg\|(.*?)\]\s*'
    r'\[Status\|(.*?)\|(.*?)\|(.*?)\|(.*?)\]\s*'
    r'\[Weibo\|(.*?)\|(.*?)\|(.*?)\|(.*?)\|(.*?)\|(\d+)\|(\d+)\|.*?'
    r'<\/nova_os>';

/// Build a widget for a matched special tag.
/// [tagName] is the opening tag (e.g. nova-os).
/// [rawContent] is everything between the opening and closing tags.
Widget buildTagWidget(BuildContext context, String tagName, String rawContent) {
  if (tagName == '<nova_os>') {
    final m = _novaOsRegex.firstMatch('<nova_os>$rawContent</nova_os>');
    if (m == null) return const SizedBox.shrink();
    final groups = List<String?>.generate(m.groupCount + 1, m.group);
    final groupsStr = groups.map((e) => e ?? '').toList();
    return _NovaOsCard(groups: groupsStr);
  }
  return const SizedBox.shrink();
}

final RegExp _novaOsRegex = RegExp(
  _novaOsPattern,
  dotAll: true,
  multiLine: true,
);

/// ─── NovaOS Phone Card ───────────────────────────────────────────────
class SpecialTagSegmentedControl extends StatelessWidget {
  const SpecialTagSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = labels ?? const ['状态', '事件'];

    // “日系清冷丧感极简风” - 纯净半透磨砂，大留白，低对比度
    final background = isDark
        ? const Color(0x40000000)
        : const Color(0x66FFFFFF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: List.generate(items.length, (i) {
                return Expanded(
                  child: _SegmentItem(
                    label: items[i],
                    selected: selectedIndex == i,
                    onTap: () => onChanged(i),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 极简冷淡的选中态：选中为黑，未选浅灰
    final selectedBg = isDark ? const Color(0xFF333333) : Colors.white;
    final selectedText = isDark ? Colors.white : Colors.black;
    final unselectedText = isDark
        ? const Color(0xFF888888)
        : const Color(0xFFA0A0A0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected
                  ? AppFontWeights.semibold
                  : AppFontWeights.medium,
              letterSpacing: 0.5,
              color: selected ? selectedText : unselectedText,
              fontFamily: 'Noto Serif SC', // 统一使用衬线体增强氛围
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

class _NovaOsCard extends StatelessWidget {
  const _NovaOsCard({required this.groups});
  final List<String> groups;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = groups[1];
    final date = groups[2];
    final song = groups[3];
    final artist = groups[4];
    final memoTitle = groups[5];
    final memoContent = groups[6];
    final wechat = groups[8];
    final thought = groups[18];
    final statusName = groups[17];
    final affection = groups[18];
    final desire = groups[19];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (time.isNotEmpty || date.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: AppFontWeights.heavy,
                          color: cs.onSurface,
                        ),
                      ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              if (song.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Lucide.Volume2, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$song${artist.isNotEmpty ? ' · $artist' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ],
              if (thought.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    thought,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
              if (statusName.isNotEmpty ||
                  affection.isNotEmpty ||
                  desire.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (statusName.isNotEmpty)
                      Text(
                        statusName,
                        style: TextStyle(
                          fontWeight: AppFontWeights.semibold,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                    const Spacer(),
                    if (affection.isNotEmpty)
                      _tag(
                        Lucide.Heart,
                        '$affection%',
                        const Color(0xFFE85D75),
                      ),
                    if (desire.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _tag(Lucide.Zap, '$desire%', const Color(0xFFF08A4B)),
                    ],
                  ],
                ),
              ],
              if (memoTitle.isNotEmpty) ...[
                const SizedBox(height: 10),
                _miniSection(memoTitle, memoContent, cs),
              ],
              if (wechat.isNotEmpty) ...[
                const SizedBox(height: 8),
                _miniSection('WeChat', wechat, cs, icon: Lucide.MessageCircle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _tag(IconData icon, String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: AppFontWeights.semibold,
          color: color,
        ),
      ),
    ],
  );
}

Widget _miniSection(
  String title,
  String content,
  ColorScheme cs, {
  IconData? icon,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 14, color: cs.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            const SizedBox(height: 2),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Pattern to match any known special tag (simple version for block detection).
final RegExp anySpecialTagPattern = RegExp(
  r'<(nova_os|kindle_bar|kindle_ui|status_card|wechat_moments_status|twitter_card)>'
  r'([\s\S]*?)'
  r'<\/\1>',
  caseSensitive: false,
);

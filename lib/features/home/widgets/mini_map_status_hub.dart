import 'package:flutter/material.dart';

import '../../../core/models/chat_message.dart';
import '../../../theme/app_font_weights.dart';

/// ─── Data Models ─────────────────────────────────────────────────────

class MiniMapStatusEntry {
  const MiniMapStatusEntry({
    required this.name,
    required this.infoFields,
    required this.meters,
    required this.modules,
  });

  final String name;
  final List<InfoField> infoFields;
  final List<MeterField> meters;
  final List<ModuleField> modules;
}

class InfoField {
  const InfoField({required this.key, required this.value});
  final String key;
  final String value;
}

class MeterField {
  const MeterField({required this.label, required this.value});
  final String label;
  final int value; // 0-100
}

class ModuleField {
  const ModuleField({required this.key, required this.value});
  final String key;
  final String value;
}

/// ─── Parser ──────────────────────────────────────────────────────────

List<MiniMapStatusEntry> parseMiniMapStatusHub(List<ChatMessage> messages) {
  for (final message in messages.reversed) {
    if (message.role != 'assistant') continue;
    final match = RegExp(
      r'<status_hub>([\s\S]*?)<\/status_hub>',
      caseSensitive: false,
    ).firstMatch(message.content);
    if (match == null) continue;
    return _parseBody(match.group(1) ?? '');
  }
  return const [];
}

List<MiniMapStatusEntry> _parseBody(String body) {
  return body
      .split('|||')
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .map(_parseCharacterBlock)
      .whereType<MiniMapStatusEntry>()
      .toList(growable: false);
}

MiniMapStatusEntry? _parseCharacterBlock(String block) {
  final lines = block
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  if (lines.isEmpty) return null;

  final name = lines.first;
  final infoFields = <InfoField>[];
  final meters = <MeterField>[];
  final modules = <ModuleField>[];

  var section = 0; // 0: info, 1: meters, 2: modules
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line == '---') {
      section++;
      continue;
    }

    final colonIdx = line.indexOf(':');
    if (colonIdx == -1) continue;

    final key = line.substring(0, colonIdx).trim();
    final value = line.substring(colonIdx + 1).trim();
    if (key.isEmpty) continue;

    if (section == 1 && value.endsWith('%')) {
      final num = int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
      meters.add(MeterField(label: key, value: num.clamp(0, 100)));
    } else {
      if (section == 1) {
        meters.add(MeterField(label: key, value: 0));
      } else if (section == 2) {
        modules.add(ModuleField(key: key, value: value));
      } else {
        infoFields.add(InfoField(key: key, value: value));
      }
    }
  }

  return MiniMapStatusEntry(
    name: name,
    infoFields: infoFields,
    meters: meters,
    modules: modules,
  );
}

/// ─── Status Hub Strip ───────────────────────────────────────────────

class MiniMapStatusHubStrip extends StatelessWidget {
  const MiniMapStatusHubStrip({super.key, required this.entries});

  final List<MiniMapStatusEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      key: const ValueKey('mini-map-status-hub-strip'),
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _MiniMapStatusCard(entry: entries[index]);
        },
      ),
    );
  }
}

/// ─── Status Card ────────────────────────────────────────────────────

class _MiniMapStatusCard extends StatelessWidget {
  const _MiniMapStatusCard({required this.entry});

  final MiniMapStatusEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
    final borderColor = isDark
        ? const Color(0x30FFFFFF)
        : const Color(0x20000000);
    final textColor = isDark
        ? const Color(0xFFCCCCCC)
        : const Color(0xFF666666);
    final nameColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111111);
    final labelColor = isDark
        ? const Color(0xFF888888)
        : const Color(0xFF999999);
    final dividerColor = isDark
        ? const Color(0x20FFFFFF)
        : const Color(0x15000000);

    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 角色名 ──
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.emphasis,
              color: nameColor,
            ),
          ),
          if (entry.infoFields.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final field in entry.infoFields) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${field.key}: ',
                      style: TextStyle(fontSize: 11, color: labelColor),
                    ),
                    Expanded(
                      child: Text(
                        field.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // ── 分区线 ──
          if (entry.meters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 8),
            for (final meter in entry.meters) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        meter.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: labelColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: meter.value / 100,
                          minHeight: 3,
                          color: textColor,
                          backgroundColor: isDark
                              ? const Color(0x30FFFFFF)
                              : const Color(0x15000000),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${meter.value}',
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // ── 模块分区 ──
          if (entry.modules.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: entry.modules.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x20FFFFFF)
                        : const Color(0x15000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${m.key}: ${m.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: textColor),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

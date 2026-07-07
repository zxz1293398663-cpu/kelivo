import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/chat_message.dart';
import '../../theme/app_font_weights.dart';

/// ─── Data Models ─────────────────────────────────────────────────────

class RelationEdge {
  const RelationEdge({
    required this.char1,
    required this.char2,
    required this.type,
    required this.strength,
  });

  final String char1;
  final String char2;
  final String type;
  final int strength; // 0-100
}

class RelationshipMap {
  const RelationshipMap({required this.characters, required this.edges});

  final List<String> characters;
  final List<RelationEdge> edges;
}

/// ─── Parser ──────────────────────────────────────────────────────────

RelationshipMap? parseRelationshipMap(List<ChatMessage> messages) {
  for (final message in messages.reversed) {
    if (message.role != 'assistant') continue;
    final match = RegExp(
      r'<relationship_map>([\s\S]*?)<\/relationship_map>',
      caseSensitive: false,
    ).firstMatch(message.content);
    if (match == null) continue;
    return _parseMapBody(match.group(1) ?? '');
  }
  return null;
}

RelationshipMap _parseMapBody(String body) {
  final chars = <String>{};
  final edges = <RelationEdge>[];
  final lines = body
      .split('|||')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);

  for (final line in lines) {
    final parts = line.split('|').map((p) => p.trim()).toList();
    if (parts.length < 4) continue;
    final char1 = parts[0];
    final char2 = parts[1];
    final type = parts[2];
    final strength =
        int.tryParse(parts[3].replaceAll(RegExp(r'[^0-9]'), '')) ?? 50;
    if (char1.isEmpty || char2.isEmpty) continue;
    chars.add(char1);
    chars.add(char2);
    edges.add(
      RelationEdge(
        char1: char1,
        char2: char2,
        type: type,
        strength: strength.clamp(0, 100),
      ),
    );
  }

  return RelationshipMap(
    characters: chars.toList(growable: false),
    edges: edges,
  );
}

/// ─── Color mapping for relationship types ───────────────────────────

Color _edgeColor(String type, bool isDark) {
  switch (type.toLowerCase()) {
    case 'lover':
    case 'love':
    case 'romance':
      return isDark ? const Color(0xFFD4878A) : const Color(0xFFB86B6E);
    case 'family':
    case 'parent':
    case 'sibling':
      return isDark ? const Color(0xFFE4CF95) : const Color(0xFFBCA76D);
    case 'friend':
    case 'ally':
      return isDark ? const Color(0xFF8AB8D4) : const Color(0xFF6E8FB8);
    case 'rival':
    case 'enemy':
    case 'hostile':
      return isDark ? const Color(0xFFD49A8A) : const Color(0xFFB86E6E);
    case 'mentor':
    case 'master':
      return isDark ? const Color(0xFFA8D4A8) : const Color(0xFF6EB86E);
    default:
      return isDark ? const Color(0xFF888888) : const Color(0xFF999999);
  }
}

String _edgeLabel(String type) {
  switch (type.toLowerCase()) {
    case 'lover':
    case 'love':
    case 'romance':
      return '♥';
    case 'family':
    case 'parent':
    case 'sibling':
      return '家';
    case 'friend':
    case 'ally':
      return '友';
    case 'rival':
    case 'enemy':
    case 'hostile':
      return '敌';
    case 'mentor':
    case 'master':
      return '师';
    default:
      return '—';
  }
}

/// ─── Graph Widget ────────────────────────────────────────────────────

class RelationshipGraphWidget extends StatelessWidget {
  const RelationshipGraphWidget({super.key, required this.map});

  final RelationshipMap map;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (map.characters.isEmpty) {
      return Center(
        child: Text(
          '暂无关系数据',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF888888) : const Color(0xFF999999),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return _RelationshipGraphPainter(map: map, size: size, isDark: isDark);
      },
    );
  }
}

class _RelationshipGraphPainter extends StatelessWidget {
  const _RelationshipGraphPainter({
    required this.map,
    required this.size,
    required this.isDark,
  });

  final RelationshipMap map;
  final Size size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final count = map.characters.length;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) / 2 - 48;

    // Compute node positions in a circle
    final positions = <String, Offset>{};
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi * i / count) - math.pi / 2;
      positions[map.characters[i]] = Offset(
        centerX + radius * math.cos(angle),
        centerY + radius * math.sin(angle),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        size: size,
        painter: _GraphPainter(map: map, positions: positions, isDark: isDark),
        child: Stack(
          children: positions.entries.map((entry) {
            return Positioned(
              left: entry.value.dx - 24,
              top: entry.value.dy - 24,
              child: _GraphNode(name: entry.key, isDark: isDark),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({required this.name, required this.isDark});

  final String name;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '?';
    final bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E5E1);
    final textColor = isDark
        ? const Color(0xFFDCD6D0)
        : const Color(0xFF4A4A4A);
    final borderColor = isDark
        ? const Color(0xFF444444)
        : const Color(0xFFD6D1CA);

    return SizedBox(
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(color: borderColor, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.emphasis,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: AppFontWeights.medium,
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.map,
    required this.positions,
    required this.isDark,
  });

  final RelationshipMap map;
  final Map<String, Offset> positions;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in map.edges) {
      final p1 = positions[edge.char1];
      final p2 = positions[edge.char2];
      if (p1 == null || p2 == null) continue;

      final color = _edgeColor(
        edge.type,
        isDark,
      ).withValues(alpha: 0.3 + (edge.strength / 100) * 0.5);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.0 + (edge.strength / 100) * 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(p1, p2, paint);

      // Draw edge label at midpoint
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final label = _edgeLabel(edge.type);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: AppFontWeights.medium,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.map != map || oldDelegate.isDark != isDark;
  }
}

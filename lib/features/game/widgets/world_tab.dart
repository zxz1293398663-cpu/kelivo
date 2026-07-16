import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/game_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

class WorldTab extends StatelessWidget {
  const WorldTab({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final state = gp.state;
    final script = gp.script;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: cs.surface.withValues(alpha: 0.5),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.gameWorldTitle(script?.title ?? ''),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          l10n.gameWorldNpcCount(state?.npcs.length ?? 0),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _PillButton(
                    icon: Lucide.Import,
                    label: l10n.gameWorldImportFromFavorites,
                    onTap: () {},
                    cs: cs,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PillButton(
                    icon: Lucide.Plus,
                    label: l10n.gameWorldCreateNpc,
                    onTap: () {},
                    cs: cs,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // NPC list
          Expanded(
            child: state == null || state.npcs.isEmpty
                ? Center(
                    child: Text(
                      l10n.gameWorldNoNpc,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.npcs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final npc = state.npcs[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: cs.primary.withValues(
                                alpha: 0.15,
                              ),
                              child: Text(
                                npc.name.isNotEmpty ? npc.name[0] : '?',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    npc.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (npc.identity.isNotEmpty)
                                        Text(
                                          npc.identity,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.secondary,
                                          ),
                                        ),
                                      if (npc.identity.isNotEmpty &&
                                          npc.location.isNotEmpty)
                                        Text(
                                          '  ·  ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurface.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                      if (npc.location.isNotEmpty)
                                        Text(
                                          npc.location,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Lucide.NotebookTabs,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

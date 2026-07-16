import 'package:flutter/material.dart';
import '../../../core/models/assistant_play_mode.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../theme/app_font_weights.dart';

class PlayModeSelector extends StatelessWidget {
  const PlayModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final AssistantPlayMode currentMode;
  final ValueChanged<AssistantPlayMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ModeOption(
              label: l10n.playModeSwitcherNovelLabel,
              icon: Lucide.BookOpen,
              isSelected: currentMode == AssistantPlayMode.novel,
              onTap: () => onModeChanged(AssistantPlayMode.novel),
            ),
          ),
          Expanded(
            child: _ModeOption(
              label: l10n.playModeSwitcherGameLabel,
              icon: Lucide.Wand2,
              isSelected: currentMode == AssistantPlayMode.game,
              onTap: () => onModeChanged(AssistantPlayMode.game),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      baseColor: isSelected
          ? (isDark ? const Color(0xFF3A3A3C) : Colors.white)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected
                  ? AppFontWeights.emphasis
                  : AppFontWeights.medium,
              color: isSelected
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

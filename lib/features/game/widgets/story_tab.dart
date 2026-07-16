import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/game_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/markdown_with_highlight.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/avatar_cache.dart';
import '../../../utils/sandbox_path_resolver.dart';

class StoryTab extends StatelessWidget {
  const StoryTab({
    super.key,
    this.openingMessages = const [],
    this.openingPreviews,
    this.openingPreviewHtmls,
    this.openingPreviewFaceText,
    this.openingPreviewFaceHtml,
    this.userName,
    this.onUserNameChanged,
    this.onOpeningSelected,
    this.onImportTavernCard,
    this.onCreateScript,
    this.hasStarted = false,
    this.activeOpening,
    this.activeOpeningPreviewHtml,
    this.choosingOpening = false,
    this.onChangeOpening,
    this.onOpeningChosen,
  });

  final List<String> openingMessages;
  final List<String>? openingPreviews;
  final List<String>? openingPreviewHtmls;
  final String? openingPreviewFaceText;
  final String? openingPreviewFaceHtml;
  final String? userName;
  final Future<void> Function(String name)? onUserNameChanged;
  final Future<void> Function(String opening)? onOpeningSelected;
  final Future<void> Function()? onImportTavernCard;
  final VoidCallback? onCreateScript;
  final bool hasStarted;
  final String? activeOpening;
  final String? activeOpeningPreviewHtml;
  final bool choosingOpening;
  final VoidCallback? onChangeOpening;
  final VoidCallback? onOpeningChosen;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final l10n = AppLocalizations.of(context)!;
    final script = gp.script;
    final state = gp.state;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (script == null || state == null) {
      if (hasStarted && !choosingOpening) {
        return _StartedOpeningState(
          activeOpening: activeOpening,
          activeOpeningPreviewHtml: activeOpeningPreviewHtml,
          onChangeOpening: onChangeOpening,
          cs: cs,
          isDark: isDark,
        );
      }
      return _OpeningSelectionState(
        openings: openingMessages,
        openingPreviews: openingPreviews,
        openingPreviewHtmls: openingPreviewHtmls,
        openingPreviewFaceText: openingPreviewFaceText,
        openingPreviewFaceHtml: openingPreviewFaceHtml,
        userName: userName,
        onUserNameChanged: onUserNameChanged,
        onOpeningSelected: onOpeningSelected,
        onImportTavernCard: onImportTavernCard,
        onCreateScript: onCreateScript,
        onOpeningChosen: onOpeningChosen,
        cs: cs,
        isDark: isDark,
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Top status bar
          _StatusBar(script: script, state: state, cs: cs),
          const SizedBox(height: 8),
          // Attribute bars + money
          _AttributeRow(script: script, cs: cs),
          const SizedBox(height: 8),
          // Attribute changes
          if (state.attributeChanges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _AttributeChangeBanner(
                text: state.attributeChanges,
                cs: cs,
              ),
            ),
          // Narrative text
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.currentNarrative.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        state.currentNarrative,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          l10n.gameStoryEmptyHint,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  // Active events
                  if (state.activeEvents.isNotEmpty) ...[
                    Text(
                      l10n.gameStoryActiveEventsTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...state.activeEvents.map(
                      (e) => _EventCard(event: e, cs: cs, isDark: isDark),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Completed events
                  if (state.completedEvents.isNotEmpty) ...[
                    Text(
                      l10n.gameStoryCompletedEventsTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...state.completedEvents.map(
                      (e) => _EventCard(
                        event: e,
                        cs: cs,
                        isDark: isDark,
                        completed: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Lucide.Play, size: 20),
                label: Text(l10n.gameStoryAdvanceButton),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningSelectionState extends StatefulWidget {
  const _OpeningSelectionState({
    required this.openings,
    required this.openingPreviews,
    required this.openingPreviewHtmls,
    required this.openingPreviewFaceText,
    required this.openingPreviewFaceHtml,
    required this.userName,
    required this.onUserNameChanged,
    required this.onOpeningSelected,
    required this.onImportTavernCard,
    required this.onCreateScript,
    required this.onOpeningChosen,
    required this.cs,
    required this.isDark,
  });

  final List<String> openings;
  final List<String>? openingPreviews;
  final List<String>? openingPreviewHtmls;
  final String? openingPreviewFaceText;
  final String? openingPreviewFaceHtml;
  final String? userName;
  final Future<void> Function(String name)? onUserNameChanged;
  final Future<void> Function(String opening)? onOpeningSelected;
  final Future<void> Function()? onImportTavernCard;
  final VoidCallback? onCreateScript;
  final VoidCallback? onOpeningChosen;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_OpeningSelectionState> createState() => _OpeningSelectionStateState();
}

class _OpeningSelectionStateState extends State<_OpeningSelectionState> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasOpenings = widget.openings.isNotEmpty;
    final effectiveUserName = widget.userName?.trim() ?? '';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasOpenings
                  ? l10n.gameOpeningSelectionTitle
                  : l10n.gameEmptyStartCreating,
              style: TextStyle(
                fontSize: 25,
                height: 1.18,
                fontWeight: AppFontWeights.emphasis,
                color: widget.cs.onSurface.withValues(alpha: 0.94),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasOpenings
                  ? l10n.gameOpeningSelectionSubtitle
                  : l10n.gameEmptyScriptCardDescription,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: widget.cs.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 18),
            if (effectiveUserName.isNotEmpty) ...[
              Text(
                l10n.gameOpeningUserTokenTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFontWeights.semibold,
                  color: widget.cs.onSurface.withValues(alpha: 0.54),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      effectiveUserName,
                      style: TextStyle(
                        fontSize: 15,
                        color: widget.cs.onSurface.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  IosIconButton(
                    icon: Lucide.Pencil,
                    size: 17,
                    minSize: 36,
                    semanticLabel: l10n.gameOpeningEditUserNameButton,
                    onTap: widget.onUserNameChanged == null
                        ? null
                        : () => _editUserName(context, effectiveUserName),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (hasOpenings) ...[
              Expanded(
                child: _OpeningCarousel(
                  openings: widget.openings,
                  openingPreviews: widget.openingPreviews,
                  openingPreviewHtmls: widget.openingPreviewHtmls,
                  onOpeningSelected: widget.onOpeningSelected,
                  onOpeningChosen: widget.onOpeningChosen,
                  cs: widget.cs,
                  isDark: widget.isDark,
                ),
              ),
            ] else ...[
              if (widget.onImportTavernCard != null)
                _PrimaryEntryCard(
                  title: l10n.gameImportTavernCardButton,
                  description: l10n.gameImportTavernCardEntryDescription,
                  icon: Lucide.User,
                  cs: widget.cs,
                  isDark: widget.isDark,
                  onTap: widget.onImportTavernCard!,
                ),
              if (widget.onCreateScript != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.onCreateScript,
                  icon: Icon(Lucide.Wand2, size: 17, color: widget.cs.primary),
                  label: Text(l10n.gameEmptyStartButton),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: widget.cs.primary,
                    side: BorderSide(
                      color: widget.cs.primary.withValues(
                        alpha: widget.isDark ? 0.34 : 0.28,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editUserName(BuildContext context, String currentName) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.gameOpeningEditUserNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.sideDrawerNicknameHint),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.homePageCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.worldBookSave),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = next?.trim() ?? '';
    if (trimmed.isEmpty || !context.mounted) return;
    await widget.onUserNameChanged?.call(trimmed);
  }
}

class _StartedOpeningState extends StatelessWidget {
  const _StartedOpeningState({
    required this.activeOpening,
    required this.activeOpeningPreviewHtml,
    required this.onChangeOpening,
    required this.cs,
    required this.isDark,
  });

  final String? activeOpening;
  final String? activeOpeningPreviewHtml;
  final VoidCallback? onChangeOpening;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final opening = (activeOpening ?? '').trim();
    final preview = (activeOpeningPreviewHtml ?? '').trim();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
        children: [
          opening.isEmpty
              ? Text(
                  l10n.gameOpeningCurrentEmpty,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.65,
                    color: cs.onSurface.withValues(alpha: 0.86),
                  ),
                )
              : MarkdownWithCodeHighlight(
                  text: preview.isNotEmpty ? preview : opening,
                  baseStyle: TextStyle(
                    fontSize: 14.5,
                    height: 1.65,
                    color: cs.onSurface.withValues(alpha: 0.86),
                  ),
                ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onChangeOpening,
            icon: Icon(Lucide.RefreshCw, size: 17, color: cs.primary),
            label: Text(l10n.gameOpeningChangeButton),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: cs.primary,
              side: BorderSide(
                color: cs.primary.withValues(alpha: isDark ? 0.34 : 0.28),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningPulseIcon extends StatefulWidget {
  const _OpeningPulseIcon({required this.icon, required this.cs});

  final IconData icon;
  final ColorScheme cs;

  @override
  State<_OpeningPulseIcon> createState() => _OpeningPulseIconState();
}

class _OpeningPulseIconState extends State<_OpeningPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.cs.primary.withValues(alpha: 0.12 + t * 0.06),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.cs.primary.withValues(alpha: 0.10 + t * 0.08),
                  blurRadius: 18 + t * 14,
                  spreadRadius: t * 2,
                ),
              ],
            ),
            child: Icon(widget.icon, color: widget.cs.primary, size: 26),
          );
        },
      ),
    );
  }
}

class _OpeningCarousel extends StatefulWidget {
  const _OpeningCarousel({
    required this.openings,
    required this.openingPreviews,
    required this.openingPreviewHtmls,
    required this.onOpeningSelected,
    required this.onOpeningChosen,
    required this.cs,
    required this.isDark,
  });

  final List<String> openings;
  final List<String>? openingPreviews;
  final List<String>? openingPreviewHtmls;
  final Future<void> Function(String opening)? onOpeningSelected;
  final VoidCallback? onOpeningChosen;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_OpeningCarousel> createState() => _OpeningCarouselState();
}

class _OpeningCarouselState extends State<_OpeningCarousel> {
  int _index = 0;
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final opening = widget.openings[_index];
    final preview =
        widget.openingPreviews != null &&
            _index < widget.openingPreviews!.length
        ? widget.openingPreviews![_index]
        : opening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _OpeningPlainMessage(
                key: ValueKey(_index),
                text: preview,
                htmlText:
                    widget.openingPreviewHtmls != null &&
                        _index < widget.openingPreviewHtmls!.length
                    ? widget.openingPreviewHtmls![_index]
                    : null,
                cs: widget.cs,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _OpeningNavButton(
              icon: Lucide.ChevronLeft,
              cs: widget.cs,
              onTap: widget.openings.length <= 1
                  ? null
                  : () => setState(() {
                      _index =
                          (_index - 1 + widget.openings.length) %
                          widget.openings.length;
                    }),
            ),
            Expanded(
              child: Text(
                l10n.gameOpeningPageIndicator(
                  _index + 1,
                  widget.openings.length,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: widget.cs.onSurface.withValues(alpha: 0.52),
                ),
              ),
            ),
            _OpeningNavButton(
              icon: Lucide.ChevronRight,
              cs: widget.cs,
              onTap: widget.openings.length <= 1
                  ? null
                  : () => setState(() {
                      _index = (_index + 1) % widget.openings.length;
                    }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: widget.onOpeningSelected == null || _starting
              ? null
              : () async {
                  setState(() => _starting = true);
                  try {
                    await widget.onOpeningSelected!(opening);
                    widget.onOpeningChosen?.call();
                  } finally {
                    if (mounted) setState(() => _starting = false);
                  }
                },
          icon: _starting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.cs.onPrimary,
                  ),
                )
              : const Icon(Lucide.Play, size: 18),
          label: Text(l10n.gameOpeningStartButton),
        ),
      ],
    );
  }
}

class _OpeningNavButton extends StatelessWidget {
  const _OpeningNavButton({
    required this.icon,
    required this.cs,
    required this.onTap,
  });

  final IconData icon;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IosIconButton(
      icon: icon,
      size: 18,
      minSize: 40,
      semanticLabel: null,
      onTap: onTap,
    );
  }
}

class _OpeningPlainMessage extends StatelessWidget {
  const _OpeningPlainMessage({
    super.key,
    required this.text,
    required this.htmlText,
    required this.cs,
  });

  final String text;
  final String? htmlText;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return MarkdownWithCodeHighlight(
      text: htmlText ?? text,
      baseStyle: TextStyle(
        fontSize: 15,
        height: 1.65,
        color: cs.onSurface.withValues(alpha: 0.88),
      ),
    );
  }
}

class _PrimaryEntryCard extends StatelessWidget {
  const _PrimaryEntryCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      padding: EdgeInsets.zero,
      baseColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.34),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 21, color: cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: AppFontWeights.emphasis,
                      color: cs.onSurface.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Lucide.ChevronRight,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final dynamic script;
  final dynamic state;
  final ColorScheme cs;

  const _StatusBar({
    required this.script,
    required this.state,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final player = script.player;
    final playerName = (player?.name as String?)?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: cs.surface.withValues(alpha: 0.5),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showPlayerAvatarPicker(context),
              child: _GameAvatar(
                avatar: player?.avatar as String?,
                fallbackName: playerName.isEmpty
                    ? l10n.gameStoryPlayerFallbackInitial
                    : playerName,
                size: 36,
                cs: cs,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playerName.isEmpty
                        ? l10n.gameStoryPlayerFallbackName
                        : playerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    script.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '${state.gameTime}  ·  ${state.currentScene}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    );
  }

  Future<void> _showPlayerAvatarPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final maxH = MediaQuery.of(ctx).size.height * 0.8;
        Widget row(String text, Future<void> Function() action) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 48,
              child: IosCardPress(
                borderRadius: BorderRadius.circular(14),
                baseColor: cs.surface,
                duration: const Duration(milliseconds: 260),
                onTap: () async {
                  Haptics.light();
                  Navigator.of(ctx).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  await action();
                },
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.medium,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    row(
                      l10n.assistantEditAvatarChooseImage,
                      () async => _pickLocalImage(context),
                    ),
                    row(l10n.assistantEditAvatarChooseEmoji, () async {
                      final emoji = await _pickEmoji(context);
                      if (!context.mounted || emoji == null) return;
                      await context.read<GameProvider>().updatePlayerAvatar(
                        emoji,
                      );
                    }),
                    row(
                      l10n.assistantEditAvatarEnterLink,
                      () async => _inputAvatarUrl(context),
                    ),
                    row(
                      l10n.assistantEditAvatarImportQQ,
                      () async => _inputQQAvatar(context),
                    ),
                    row(l10n.assistantEditAvatarReset, () async {
                      await context.read<GameProvider>().updatePlayerAvatar(
                        null,
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickEmoji(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    String value = '';
    bool validGrapheme(String s) {
      final trimmed = s.characters.take(1).toString().trim();
      return trimmed.isNotEmpty && trimmed == s.trim();
    }

    final quick = const [
      '😀',
      '😊',
      '😍',
      '🙂',
      '🤗',
      '🤩',
      '🫶',
      '✨',
      '🌟',
      '🔥',
      '🌙',
      '☀️',
      '🐱',
      '🐶',
      '🦊',
      '🐰',
      '🎮',
      '📚',
      '☕',
      '🌈',
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.assistantEditEmojiDialogTitle),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: EmojiText(
                        value.isEmpty
                            ? '🙂'
                            : value.characters.take(1).toString(),
                        fontSize: 40,
                        optimizeEmojiAlign: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (v) => setLocal(() => value = v),
                      onSubmitted: (_) {
                        if (validGrapheme(value)) {
                          Navigator.of(
                            ctx,
                          ).pop(value.characters.take(1).toString());
                        }
                      },
                      decoration: InputDecoration(
                        hintText: l10n.assistantEditEmojiDialogHint,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF2F3F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quick
                          .map(
                            (e) => InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(ctx).pop(e),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: EmojiText(
                                  e,
                                  fontSize: 20,
                                  optimizeEmojiAlign: true,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.assistantEditEmojiDialogCancel),
                ),
                TextButton(
                  onPressed: validGrapheme(value)
                      ? () => Navigator.of(
                          ctx,
                        ).pop(value.characters.take(1).toString())
                      : null,
                  child: Text(l10n.assistantEditEmojiDialogSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _inputAvatarUrl(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool valid(String s) =>
            s.trim().startsWith('http://') || s.trim().startsWith('https://');
        String value = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: cs.surface,
            title: Text(l10n.assistantEditImageUrlDialogTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.assistantEditImageUrlDialogHint,
                filled: true,
                fillColor: Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.white10
                    : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setLocal(() => value = v),
              onSubmitted: (_) {
                if (valid(value)) Navigator.of(ctx).pop(true);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.assistantEditImageUrlDialogCancel),
              ),
              TextButton(
                onPressed: valid(value)
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                child: Text(l10n.assistantEditImageUrlDialogSave),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    final url = controller.text.trim();
    if (!context.mounted || url.isEmpty) return;
    await context.read<GameProvider>().updatePlayerAvatar(url);
  }

  Future<void> _inputQQAvatar(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final gp = context.read<GameProvider>();
        final dialogNavigator = Navigator.of(ctx);
        String value = '';
        bool valid(String s) => RegExp(r'^[0-9]{5,12}$').hasMatch(s.trim());
        String randomQQ() {
          final lengths = <int>[5, 6, 7, 8, 9, 10, 11];
          final weights = <int>[1, 20, 80, 100, 500, 5000, 80];
          final total = weights.fold<int>(0, (a, b) => a + b);
          final rnd = math.Random();
          var roll = rnd.nextInt(total) + 1;
          var chosenLen = lengths.last;
          var acc = 0;
          for (var i = 0; i < lengths.length; i++) {
            acc += weights[i];
            if (roll <= acc) {
              chosenLen = lengths[i];
              break;
            }
          }
          final firstGroups = <List<int>>[
            [1, 2],
            [3, 4],
            [5, 6, 7, 8],
            [9],
          ];
          final firstWeights = <int>[128, 4, 2, 1];
          final firstTotal = firstWeights.fold<int>(0, (a, b) => a + b);
          roll = rnd.nextInt(firstTotal) + 1;
          var groupIndex = 0;
          acc = 0;
          for (var i = 0; i < firstGroups.length; i++) {
            acc += firstWeights[i];
            if (roll <= acc) {
              groupIndex = i;
              break;
            }
          }
          final sb = StringBuffer(
            firstGroups[groupIndex][rnd.nextInt(
              firstGroups[groupIndex].length,
            )],
          );
          for (var i = 1; i < chosenLen; i++) {
            sb.write(rnd.nextInt(10));
          }
          return sb.toString();
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: cs.surface,
            title: Text(l10n.assistantEditQQAvatarDialogTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: l10n.assistantEditQQAvatarDialogHint,
                filled: true,
                fillColor: Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.white10
                    : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setLocal(() => value = v),
              onSubmitted: (_) {
                if (valid(value)) Navigator.of(ctx).pop(true);
              },
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () async {
                  const maxTries = 20;
                  var applied = false;
                  for (var i = 0; i < maxTries; i++) {
                    final qq = randomQQ();
                    final url =
                        'https://q2.qlogo.cn/headimg_dl?dst_uin=$qq&spec=100';
                    try {
                      final resp = await http
                          .get(Uri.parse(url))
                          .timeout(const Duration(seconds: 5));
                      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                        await gp.updatePlayerAvatar(url);
                        applied = true;
                        break;
                      }
                    } catch (e, st) {
                      debugPrint('Failed to fetch QQ avatar $qq: $e\n$st');
                    }
                  }
                  if (applied) {
                    if (dialogNavigator.mounted && dialogNavigator.canPop()) {
                      dialogNavigator.pop(false);
                    }
                  } else {
                    if (!context.mounted) return;
                    showAppSnackBar(
                      context,
                      message: l10n.assistantEditQQAvatarFailedMessage,
                      type: NotificationType.error,
                    );
                  }
                },
                child: Text(l10n.assistantEditQQAvatarRandomButton),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.assistantEditQQAvatarDialogCancel),
                  ),
                  TextButton(
                    onPressed: valid(value)
                        ? () => Navigator.of(ctx).pop(true)
                        : null,
                    child: Text(l10n.assistantEditQQAvatarDialogSave),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    final qq = controller.text.trim();
    if (!context.mounted || qq.isEmpty) return;
    await context.read<GameProvider>().updatePlayerAvatar(
      'https://q2.qlogo.cn/headimg_dl?dst_uin=$qq&spec=100',
    );
  }

  Future<void> _pickLocalImage(BuildContext context) async {
    if (kIsWeb) {
      await _inputAvatarUrl(context);
      return;
    }
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 90,
      );
      if (!context.mounted || file == null) return;
      await context.read<GameProvider>().updatePlayerAvatar(file.path);
    } on PlatformException {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.assistantEditGalleryErrorMessage,
        type: NotificationType.error,
      );
      await _inputAvatarUrl(context);
    } catch (_) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.assistantEditGeneralErrorMessage,
        type: NotificationType.error,
      );
      await _inputAvatarUrl(context);
    }
  }
}

class _GameAvatar extends StatelessWidget {
  const _GameAvatar({
    required this.avatar,
    required this.fallbackName,
    required this.size,
    required this.cs,
  });

  final String? avatar;
  final String fallbackName;
  final double size;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final value = avatar?.trim() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget child;
    if (value.startsWith('http')) {
      child = FutureBuilder<String?>(
        future: AvatarCache.getPath(value),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path != null && File(path).existsSync()) {
            return _avatarImage(FileImage(File(path)));
          }
          return ClipOval(
            child: Image.network(
              value,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            ),
          );
        },
      );
    } else if (!kIsWeb && (value.startsWith('/') || value.contains(':'))) {
      final file = File(SandboxPathResolver.fix(value));
      child = file.existsSync() ? _avatarImage(FileImage(file)) : _fallback();
    } else if (value.isNotEmpty) {
      child = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: EmojiText(
          value.characters.take(1).toString(),
          fontSize: size * 0.5,
          optimizeEmojiAlign: true,
        ),
      );
    } else {
      child = _fallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }

  Widget _avatarImage(ImageProvider image) {
    return ClipOval(
      child: Image(image: image, width: size, height: size, fit: BoxFit.cover),
    );
  }

  Widget _fallback() {
    final letter = fallbackName.characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: cs.primary,
          fontSize: size * 0.42,
          fontWeight: AppFontWeights.emphasis,
        ),
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  final dynamic script;
  final ColorScheme cs;

  const _AttributeRow({required this.script, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Attribute bars
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: script.attributes.map<Widget>((a) {
              final pct = (a.value - a.min) / (a.max - a.min);
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 40) / 2,
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        a.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: cs.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${a.value.toInt()}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // Resources
          Row(
            children: script.resources.map<Widget>((r) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Lucide.Coins,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${r.name}: ${r.value.toInt()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AttributeChangeBanner extends StatelessWidget {
  final String text;
  final ColorScheme cs;

  const _AttributeChangeBanner({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: cs.primary)),
    );
  }
}

class _EventCard extends StatelessWidget {
  final dynamic event;
  final ColorScheme cs;
  final bool isDark;
  final bool completed;

  const _EventCard({
    required this.event,
    required this.cs,
    required this.isDark,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: completed ? 0.04 : 0.06)
            : Colors.white.withValues(alpha: completed ? 0.7 : 1.0),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: completed
                ? cs.onSurface.withValues(alpha: 0.2)
                : cs.primary.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completed ? Lucide.CheckCircle : Icons.circle_outlined,
                size: 16,
                color: completed
                    ? cs.onSurface.withValues(alpha: 0.4)
                    : cs.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(
                      alpha: completed ? 0.5 : 0.8,
                    ),
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

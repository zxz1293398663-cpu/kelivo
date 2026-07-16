import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/game_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/importers/tavern_card_importer.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../utils/assistant_regex.dart';
import 'story_tab.dart';
import 'world_tab.dart';
import 'phone_tab.dart';
import 'settings_tab.dart';
import 'script_creation_page.dart';

class GameContent extends StatefulWidget {
  const GameContent({
    super.key,
    this.onTavernCardImported,
    this.onOpeningSelected,
    this.hasStarted = false,
    this.activeOpening,
  });

  final Future<void> Function()? onTavernCardImported;
  final Future<void> Function(String opening)? onOpeningSelected;
  final bool hasStarted;
  final String? activeOpening;

  @override
  State<GameContent> createState() => _GameContentState();
}

class _GameContentState extends State<GameContent> {
  int _currentTab = 0;
  bool _creatingScript = false;
  bool _choosingOpening = false;
  String? _initialScriptTitle;
  String? _initialScriptInstructions;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final assistant = context.watch<AssistantProvider>().currentAssistant;
    if (gp.scopeId != assistant?.id) {
      return const Center(child: CircularProgressIndicator());
    }
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!gp.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_creatingScript) {
      return ScriptCreationPage(
        embedded: true,
        initialTitle: _initialScriptTitle,
        initialInstructions: _initialScriptInstructions,
        onCancel: () => setState(() => _creatingScript = false),
        onCreated: (script) async {
          await gp.setScript(script);
          if (mounted) {
            setState(() => _creatingScript = false);
          }
        },
      );
    }

    final globalUserName = context.watch<UserProvider>().name.trim();
    final gameUserName = gp.playerName?.trim() ?? '';
    final userName = gameUserName.isNotEmpty ? gameUserName : globalUserName;
    final charName = assistant?.name.trim() ?? '';
    final assistantOpenings = (assistant?.presetMessages ?? const [])
        .where(
          (message) =>
              message.role == 'assistant' && message.content.trim().isNotEmpty,
        )
        .toList(growable: false);
    final openingPreviewFace = null;
    final selectableOpeningMessages = assistantOpenings;
    final openingMessages = selectableOpeningMessages
        .map(
          (message) => _renderOpeningPlaceholders(
            message.content.trim(),
            userName: userName,
            charName: charName,
          ),
        )
        .toList(growable: false);
    final openingPreviews = selectableOpeningMessages
        .map(
          (message) => _renderOpeningPreviews(
            message.content.trim(),
            assistant: assistant,
            userName: userName,
            charName: charName,
          ),
        )
        .toList(growable: false);
    final openingPreviewHtmls = selectableOpeningMessages
        .map(
          (message) => _renderOpeningPreviewHtml(
            message.content.trim(),
            assistant: assistant,
            userName: userName,
            charName: charName,
          ),
        )
        .toList(growable: false);
    final openingPreviewFaceText = openingPreviewFace?.content.trim();
    final openingPreviewFaceHtml = openingPreviewFaceText == null
        ? null
        : _renderOpeningPreviewHtml(
            openingPreviewFaceText,
            assistant: assistant,
            userName: userName,
            charName: charName,
          );
    final activeOpeningPreviewHtml = widget.activeOpening == null
        ? null
        : _renderOpeningPreviewHtml(
            widget.activeOpening!,
            assistant: assistant,
            userName: userName,
            charName: charName,
          );

    if (!gp.hasScript &&
        openingMessages.isEmpty &&
        openingPreviewFaceText == null) {
      return _buildEmptyState(context, cs, isDark, gp);
    }

    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _currentTab,
            children: [
              StoryTab(
                openingMessages: gp.hasScript ? const [] : openingMessages,
                openingPreviews: gp.hasScript ? const [] : openingPreviews,
                openingPreviewHtmls: gp.hasScript
                    ? const []
                    : openingPreviewHtmls,
                openingPreviewFaceText: gp.hasScript
                    ? null
                    : openingPreviewFaceText,
                openingPreviewFaceHtml: gp.hasScript
                    ? null
                    : openingPreviewFaceHtml,
                userName: userName,
                onUserNameChanged: gp.updatePlayerName,
                onOpeningSelected: widget.onOpeningSelected,
                onImportTavernCard: gp.hasScript ? null : _importTavernCard,
                onCreateScript: gp.hasScript
                    ? null
                    : () => _startCreation(context, gp),
                hasStarted: !gp.hasScript && widget.hasStarted,
                activeOpening: widget.activeOpening,
                activeOpeningPreviewHtml: activeOpeningPreviewHtml,
                choosingOpening: _choosingOpening,
                onChangeOpening: () => setState(() => _choosingOpening = true),
                onOpeningChosen: () => setState(() => _choosingOpening = false),
              ),
              const PhoneTab(),
              const WorldTab(),
              const GameSettingsTab(),
            ],
          ),
        ),
        _buildBottomNav(cs, isDark),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
    GameProvider gp,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.gameEmptyStartCreating,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.92),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 18),
              IosCardPress(
                onTap: () => _startCreation(context, gp),
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
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.22 : 0.34,
                      ),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.22 : 0.08,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(Lucide.Wand2, size: 21, color: cs.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.gameEmptyScriptCardTitle,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.gameEmptyScriptCardDescription,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: cs.onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFeatureChip(
                            context,
                            Lucide.SquareEqual,
                            l10n.gameEmptyVisualEditor,
                          ),
                          _buildFeatureChip(
                            context,
                            Lucide.Sparkles,
                            l10n.gameEmptyAiOpening,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.gameEmptyStartButton,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Lucide.ChevronRight,
                              size: 17,
                              color: cs.onPrimary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _importTavernCard,
                icon: Icon(Lucide.User, size: 17, color: cs.primary),
                label: Text(l10n.gameImportTavernCardButton),
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
        ),
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.20),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(ColorScheme cs, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = <_TabInfo>[
      _TabInfo(label: l10n.gameTabStory, icon: Lucide.BookOpenText),
      _TabInfo(label: l10n.gameTabPhone, icon: Lucide.Phone),
      _TabInfo(label: l10n.gameTabWorld, icon: Lucide.Globe),
      _TabInfo(label: l10n.gameTabSettings, icon: Lucide.Settings),
    ];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final t = tabs[i];
              final selected = _currentTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentTab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t.icon,
                          size: 22,
                          color: selected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _startCreation(BuildContext context, GameProvider gp) async {
    setState(() {
      _initialScriptTitle = null;
      _initialScriptInstructions = null;
      _creatingScript = true;
    });
  }

  Future<void> _importTavernCard() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'png', 'html'],
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      final content = await File(path).readAsBytes();
      final importResult = TavernCardImporter.parseFileBytes(
        content,
        fileName: result.files.first.name,
        includeWorldBook: false,
      );
      if (importResult == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gameImportTavernCardFailed)),
        );
        return;
      }

      if (!mounted) return;
      final assistant = importResult.assistant;
      await context.read<AssistantProvider>().addAssistantObject(assistant);

      if (!mounted) return;
      if (widget.onTavernCardImported != null) {
        await widget.onTavernCardImported!();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.gameImportTavernCardSuccess)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.gameImportTavernCardFailed)));
    }
  }

  String _renderOpeningPlaceholders(
    String text, {
    required String userName,
    required String charName,
  }) {
    final resolvedUser = userName.isEmpty
        ? AppLocalizations.of(context)!.userProviderDefaultUserName
        : userName;
    final resolvedChar = charName.isEmpty
        ? AppLocalizations.of(context)!.assistantProviderDefaultAssistantName
        : charName;
    return text
        .replaceAll('{{user}}', resolvedUser)
        .replaceAll('{{User}}', resolvedUser)
        .replaceAll('{{USER}}', resolvedUser)
        .replaceAll('{{char}}', resolvedChar)
        .replaceAll('{{Char}}', resolvedChar)
        .replaceAll('{{CHAR}}', resolvedChar);
  }

  String _renderOpeningPreviews(
    String text, {
    required Assistant? assistant,
    required String userName,
    required String charName,
  }) {
    return _renderOpeningPlaceholders(
      _stripOpeningPreviewRequestTags(
        applyAssistantRegexes(
          text,
          assistant: assistant,
          scope: AssistantRegexScope.assistant,
          target: AssistantRegexTransformTarget.visual,
        ),
      ),
      userName: userName,
      charName: charName,
    );
  }

  String _renderOpeningPreviewHtml(
    String text, {
    required Assistant? assistant,
    required String userName,
    required String charName,
  }) {
    return _renderOpeningPlaceholders(
      applyAssistantRegexes(
        text,
        assistant: assistant,
        scope: AssistantRegexScope.assistant,
        target: AssistantRegexTransformTarget.visual,
      ),
      userName: userName,
      charName: charName,
    );
  }

  String _stripOpeningPreviewRequestTags(String text) {
    return text
        .replaceAll(RegExp(r'<request\s*:[\s\S]*?>', caseSensitive: false), '')
        .trim();
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  const _TabInfo({required this.label, required this.icon});
}

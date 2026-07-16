part of '../desktop_settings_page.dart';

class DesktopPresetsPane extends StatefulWidget {
  const DesktopPresetsPane({super.key});
  @override
  State<DesktopPresetsPane> createState() => _DesktopPresetsPaneState();
}

class _DesktopPresetsPaneState extends State<DesktopPresetsPane> {
  // ===== Import =====
  Future<void> _importPreset() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    final String content = await File(file.path!).readAsString();
    final preset = TavernPresetImporter.parseToSavedPreset(content);
    if (preset == null) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: l10n.desktopPresetsImportFailed,
          type: NotificationType.error,
        );
      }
      return;
    }
    final fileName = file.name;
    preset.name = fileName.endsWith('.json')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
    await settings.addSavedPreset(preset);
    if (mounted) {
      showAppSnackBar(
        context,
        message: l10n.desktopPresetsImportSuccess(preset.name),
        type: NotificationType.success,
      );
    }
  }

  // ===== Edit preset meta =====
  Future<void> _editPresetMeta(SavedPreset preset) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: preset.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.desktopPresetsEditNameTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFontWeights.emphasis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white10
                          : const Color(0xFFF7F7F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DeskIosButton(
                        label: l10n.homePageCancel,
                        filled: false,
                        dense: true,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 8),
                      _DeskIosButton(
                        label: l10n.messageEditPageSave,
                        filled: true,
                        dense: true,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (saved != true || !mounted) return;
    final ap = context.read<SettingsProvider>();
    final updated = SavedPreset(
      id: preset.id,
      name: nameCtrl.text.trim().isEmpty ? preset.name : nameCtrl.text.trim(),
      mainPrompt: preset.mainPrompt,
      rules: preset.rules,
    );
    await ap.updateSavedPreset(updated);
  }

  // ===== Apply to assistants =====
  Future<void> _applyPreset(SavedPreset preset) async {
    final l10n = AppLocalizations.of(context)!;
    final ap = context.read<AssistantProvider>();
    final assistants = ap.assistants;
    if (assistants.isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.desktopPresetsNoApplicableAssistants,
        type: NotificationType.warning,
      );
      return;
    }
    final selectedIds = await _showMultiAssistantPicker(assistants);
    if (selectedIds == null || selectedIds.isEmpty || !mounted) return;
    final systemPrompt = preset.systemPrompt;
    for (final a in assistants) {
      if (selectedIds.contains(a.id)) {
        await ap.updateAssistant(
          a.copyWith(
            systemPrompt: systemPrompt,
            mainPrompt: preset.mainPrompt,
            rules: List<PresetRule>.from(preset.rules),
          ),
        );
      }
    }
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: l10n.desktopPresetsAppliedToAssistants(selectedIds.length),
      type: NotificationType.success,
    );
  }

  Future<Set<String>?> _showMultiAssistantPicker(
    List<Assistant> assistants,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final selected = <String>{};
    bool allSelected = false;
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Dialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                  maxHeight: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.desktopPresetsSelectAssistantsTitle,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: AppFontWeights.emphasis,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              icon: Icon(
                                allSelected
                                    ? lucide.Lucide.CheckSquare
                                    : lucide.Lucide.Square,
                                size: 16,
                              ),
                              label: Text(l10n.desktopPresetsSelectAll),
                              onPressed: () {
                                allSelected = !allSelected;
                                selected.clear();
                                if (allSelected) {
                                  selected.addAll(assistants.map((a) => a.id));
                                }
                                setLocal(() {});
                              },
                            ),
                            IconButton(
                              tooltip: MaterialLocalizations.of(
                                ctx,
                              ).closeButtonTooltip,
                              icon: const Icon(lucide.Lucide.X, size: 18),
                              color: cs.onSurface,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: cs.outlineVariant.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: assistants.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final a = assistants[i];
                          final checked = selected.contains(a.id);
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (checked) {
                                selected.remove(a.id);
                                allSelected = false;
                              } else {
                                selected.add(a.id);
                                if (selected.length == assistants.length) {
                                  allSelected = true;
                                }
                              }
                              setLocal(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    checked
                                        ? lucide.Lucide.CheckCircle
                                        : Icons.circle_outlined,
                                    size: 20,
                                    color: checked
                                        ? cs.primary
                                        : cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 12),
                                  CircleAvatar(
                                    backgroundColor: cs.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    radius: 16,
                                    child: Text(
                                      a.name.isNotEmpty ? a.name[0] : '?',
                                      style: TextStyle(color: cs.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    a.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _DeskIosButton(
                            label: l10n.homePageCancel,
                            filled: false,
                            dense: true,
                            onTap: () => Navigator.of(ctx).pop(),
                          ),
                          const SizedBox(width: 8),
                          _DeskIosButton(
                            label: l10n.desktopPresetsApplyCount(
                              selected.length,
                            ),
                            filled: true,
                            dense: true,
                            onTap: () =>
                                Navigator.of(ctx).pop(Set.of(selected)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final presets = settings.savedPresets;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.desktopPresetsTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFontWeights.regular,
                            color: cs.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                    _DeskIosButton(
                      label: l10n.desktopPresetsImportButton,
                      filled: true,
                      dense: true,
                      onTap: _importPreset,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: presets.isEmpty
                    ? Center(
                        child: Text(
                          l10n.desktopPresetsEmpty,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: EdgeInsets.zero,
                        buildDefaultDragHandles: false,
                        itemCount: presets.length,
                        onReorderItem: (oldIndex, newIndex) async {
                          await settings.reorderSavedPreset(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (_, __) {
                              final t = Curves.easeOutCubic.transform(
                                animation.value,
                              );
                              return Transform.scale(
                                scale: 0.98 + 0.02 * t,
                                child: Material(
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: child,
                                ),
                              );
                            },
                          );
                        },
                        itemBuilder: (context, index) {
                          final preset = presets[index];
                          return _PresetCard(
                            key: ValueKey(preset.id),
                            preset: preset,
                            onEditMeta: () => _editPresetMeta(preset),
                            onApply: () => _applyPreset(preset),
                            onDelete: () async {
                              await settings.removeSavedPreset(preset.id);
                            },
                            onUpdate: () async {
                              await settings.updateSavedPreset(preset);
                            },
                            dragHandle: ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                lucide.Lucide.GripVertical,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatefulWidget {
  final SavedPreset preset;
  final VoidCallback onEditMeta;
  final VoidCallback onApply;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;
  final Widget dragHandle;
  const _PresetCard({
    super.key,
    required this.preset,
    required this.onEditMeta,
    required this.onApply,
    required this.onDelete,
    required this.onUpdate,
    required this.dragHandle,
  });

  @override
  State<_PresetCard> createState() => _PresetCardState();
}

class _PresetCardState extends State<_PresetCard> {
  bool _hover = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark
        ? Colors.white10
        : Colors.white.withValues(alpha: 0.96);
    final borderColor = _hover
        ? cs.primary.withValues(alpha: isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: widget.dragHandle,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Icon(
                            _expanded
                                ? lucide.Lucide.ChevronDown
                                : lucide.Lucide.ChevronRight,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          lucide.Lucide.FileText,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        _ToolbarButton(
                          icon: lucide.Lucide.Pencil,
                          tooltip: l10n.desktopPresetsEditNameTooltip,
                          onTap: widget.onEditMeta,
                        ),
                        const SizedBox(width: 4),
                        _ToolbarButton(
                          icon: lucide.Lucide.CheckCircle,
                          tooltip: l10n.desktopPresetsApplyTooltip,
                          onTap: widget.onApply,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        _ToolbarButton(
                          icon: lucide.Lucide.Trash2,
                          tooltip: l10n.desktopPresetsDeleteTooltip,
                          color: cs.error,
                          onTap: widget.onDelete,
                        ),
                      ],
                    ),
                  ),

                  // Expanded content: main prompt + rules
                  if (_expanded) ...[
                    const SizedBox(height: 4),
                    // Main prompt
                    if (widget.preset.mainPrompt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(30, 0, 8, 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF7F7F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: cs.primary.withValues(alpha: 0.3),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    l10n.desktopPresetsMainPrompt,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: AppFontWeights.semibold,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const Spacer(),
                                  _ToolbarButton(
                                    icon: lucide.Lucide.Pencil,
                                    tooltip: l10n
                                        .desktopPresetsEditMainPromptTooltip,
                                    onTap: () => _editMainPrompt(
                                      context,
                                      widget.preset,
                                      widget.onUpdate,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                widget.preset.mainPrompt,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Rules
                    if (widget.preset.rules.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(30, 0, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.desktopPresetsRules,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: AppFontWeights.semibold,
                                color: cs.secondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (_, __) => Material(
                                    elevation: 0,
                                    color: Colors.transparent,
                                    child: child,
                                  ),
                                );
                              },
                              itemCount: widget.preset.rules.length,
                              onReorderItem: (oldIndex, newIndex) async {
                                final list = widget.preset.rules;
                                final item = list.removeAt(oldIndex);
                                list.insert(newIndex, item);
                                widget.onUpdate();
                                setState(() {});
                              },
                              itemBuilder: (ctx, i) {
                                final rule = widget.preset.rules[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  key: ValueKey(rule.id),
                                  child: ReorderableDragStartListener(
                                    index: i,
                                    child: _buildRuleItem(rule),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(PresetRule rule) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = rule.enabled ? 1.0 : 0.45;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05 * opacity)
            : const Color(0xFFF7F7F9).withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: (rule.enabled ? cs.primary : cs.onSurface).withValues(
              alpha: 0.2,
            ),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleRule(rule),
                child: Icon(
                  rule.enabled
                      ? lucide.Lucide.CheckCircle
                      : Icons.circle_outlined,
                  size: 18,
                  color: rule.enabled
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rule.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface.withValues(alpha: 0.8 * opacity),
                  ),
                ),
              ),
              _ToolbarButton(
                icon: lucide.Lucide.Pencil,
                tooltip: l10n.desktopPresetsEditRuleTooltip,
                onTap: () => _editRuleDialog(rule),
              ),
              const SizedBox(width: 4),
              _ToolbarButton(
                icon: lucide.Lucide.Trash2,
                tooltip: l10n.desktopPresetsDeleteRuleTooltip,
                color: cs.error,
                onTap: () => _deleteRule(rule),
              ),
            ],
          ),
          if (rule.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              rule.content,
              maxLines: rule.enabled ? 2 : 1,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: cs.onSurface.withValues(alpha: 0.55 * opacity),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleRule(PresetRule rule) {
    rule.enabled = !rule.enabled;
    widget.onUpdate();
    setState(() {});
  }

  void _deleteRule(PresetRule rule) {
    widget.preset.rules.removeWhere((r) => r.id == rule.id);
    widget.onUpdate();
    setState(() {});
  }

  Future<void> _editRuleDialog(PresetRule rule) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: rule.name);
    final contentCtrl = TextEditingController(text: rule.content);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 500),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.assistantEditRuleEditTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFontWeights.emphasis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.assistantEditRuleNameLabel,
                      filled: true,
                      fillColor: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white10
                          : const Color(0xFFF7F7F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: contentCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        labelText: l10n.assistantEditRuleContentLabel,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DeskIosButton(
                        label: l10n.homePageCancel,
                        filled: false,
                        dense: true,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 8),
                      _DeskIosButton(
                        label: l10n.messageEditPageSave,
                        filled: true,
                        dense: true,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (saved != true || !mounted) return;
    rule.name = nameCtrl.text.trim().isEmpty ? rule.name : nameCtrl.text.trim();
    rule.content = contentCtrl.text;
    widget.onUpdate();
    setState(() {});
  }

  Future<void> _editMainPrompt(
    BuildContext context,
    SavedPreset preset,
    VoidCallback onUpdate,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: preset.mainPrompt);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 500),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.desktopPresetsEditMainPromptTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFontWeights.emphasis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DeskIosButton(
                        label: l10n.homePageCancel,
                        filled: false,
                        dense: true,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 8),
                      _DeskIosButton(
                        label: l10n.messageEditPageSave,
                        filled: true,
                        dense: true,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (saved != true || !context.mounted) return;
    preset.mainPrompt = ctrl.text;
    onUpdate();
    setState(() {});
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.color,
    required this.onTap,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = widget.color ?? cs.onSurface.withValues(alpha: 0.7);
    final bg = _hover ? fg.withValues(alpha: 0.12) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 15, color: fg),
          ),
        ),
      ),
    );
  }
}

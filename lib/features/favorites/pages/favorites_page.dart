import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/favorite_cards_store.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/markdown_with_highlight.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';

String _favoritePreviewText(String content) {
  final trimmed = content.trimLeft();
  if (trimmed.startsWith('```') ||
      trimmed.startsWith('<!DOCTYPE') ||
      trimmed.startsWith('<!doctype') ||
      trimmed.startsWith('<html') ||
      trimmed.startsWith('<body') ||
      trimmed.startsWith('<div') ||
      trimmed.startsWith('<section')) {
    if (trimmed.startsWith('```')) return content;
    return '```html\n$content\n```';
  }
  return content;
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.scope,
    this.embedded = false,
    this.selectedReferenceIds = const <String>{},
    this.onToggleReference,
    this.onClose,
  });

  final FavoriteScope scope;
  final bool embedded;
  final Set<String> selectedReferenceIds;
  final ValueChanged<FavoriteCardReference>? onToggleReference;
  final VoidCallback? onClose;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<FavoriteCard> _cards = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await FavoriteCardsStore.load(scope: widget.scope);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _save(List<FavoriteCard> cards) async {
    await FavoriteCardsStore.save(cards, scope: widget.scope);
    if (!mounted) return;
    setState(() => _cards = cards);
  }

  Future<void> _upsertCard({FavoriteCard? existing}) async {
    final result = await showDialog<FavoriteCard>(
      context: context,
      builder: (context) => _FavoriteCardDialog(existing: existing),
    );
    if (result == null) return;
    final next = [..._cards];
    final index = existing == null
        ? -1
        : next.indexWhere((card) => card.id == existing.id);
    if (index == -1) {
      next.insert(0, _withScope(result));
    } else {
      next[index] = _withScope(result);
    }
    await _save(next);
  }

  FavoriteCard _withScope(FavoriteCard card) {
    return FavoriteCard(
      id: card.id,
      title: card.title,
      note: card.note,
      content: card.content,
      createdAt: card.createdAt,
      updatedAt: card.updatedAt,
      sourceMessageId: card.sourceMessageId,
      assistantId: widget.scope.assistantId,
      conversationId: widget.scope.conversationId,
      autoSaved: card.autoSaved,
    );
  }

  Future<void> _deleteCard(FavoriteCard card) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.favoritesDeleteTitle),
        content: Text(l10n.favoritesDeleteMessage(card.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.homePageCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.homePageDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _save(_cards.where((item) => item.id != card.id).toList());
  }

  Future<void> _copyForAi(FavoriteCard card) async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.onToggleReference != null) {
      widget.onToggleReference!(
        FavoriteCardReference(
          id: card.id,
          title: card.title,
          text: card.referenceText,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: card.referenceText));
    if (!mounted) return;
    showAppSnackBar(context, message: l10n.chatMessageWidgetCopiedToClipboard);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 黑白灰毛玻璃基础底色
    final bgColor = isDark ? const Color(0x66000000) : const Color(0x66FFFFFF);

    final body = ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(color: bgColor),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    if (widget.embedded)
                      _FavoritesHeader(onClose: widget.onClose),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _cards.isEmpty
                          ? _FavoritesEmpty(onAdd: () => _upsertCard())
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount =
                                    constraints.maxWidth >= 900
                                    ? 4
                                    : constraints.maxWidth >= 700
                                    ? 3
                                    : constraints.maxWidth >= 500
                                    ? 2
                                    : 1;
                                return GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    96,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                        mainAxisExtent: 130,
                                      ),
                                  itemCount: _cards.length,
                                  itemBuilder: (context, index) {
                                    final card = _cards[index];
                                    return _FavoriteCardTile(
                                      card: card,
                                      referenced: widget.selectedReferenceIds
                                          .contains(card.id),
                                      onEdit: () => _upsertCard(existing: card),
                                      onDelete: () => _deleteCard(card),
                                      onCopy: () => _copyForAi(card),
                                      onPreview: () => _previewCard(card),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
                if (!_loading && _cards.isNotEmpty)
                  Positioned(
                    right: 22,
                    bottom: 22,
                    child: _AddFloatingButton(onTap: () => _upsertCard()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favoritesPageTitle),
        actions: const [SizedBox(width: 8)],
      ),
      body: body,
    );
  }

  Future<void> _previewCard(FavoriteCard card) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.82),
                ),
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    card.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: AppFontWeights.emphasis,
                                    ),
                                  ),
                                ),
                                IosIconButton(
                                  icon: Lucide.X,
                                  semanticLabel: AppLocalizations.of(
                                    context,
                                  )!.homePageCancel,
                                  onTap: () => Navigator.of(context).maybePop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: ColoredBox(
                                  color: cs.surfaceContainer.withValues(
                                    alpha: 0.48,
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(22),
                                    physics: const BouncingScrollPhysics(),
                                    child: MarkdownWithCodeHighlight(
                                      text: _favoritePreviewText(card.content),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FavoritesHeader extends StatelessWidget {
  const _FavoritesHeader({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconBg = isDark ? const Color(0x33FFFFFF) : const Color(0x1A000000);
    final inkColor = isDark ? const Color(0xFFCCCCCC) : const Color(0xFF666666);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0x20FFFFFF)
                    : const Color(0x1A000000),
              ),
            ),
            child: Icon(Lucide.Bookmark, size: 18, color: inkColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.favoritesPageTitle,
              style: TextStyle(
                fontSize: 17,
                color: inkColor,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
          ),
          if (onClose != null)
            IosIconButton(
              icon: Lucide.X,
              semanticLabel: l10n.homePageCancel,
              onTap: onClose,
            ),
        ],
      ),
    );
  }
}

class _AddFloatingButton extends StatelessWidget {
  const _AddFloatingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final btnIcon = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return Semantics(
      button: true,
      label: l10n.favoritesAddTooltip,
      child: IosCardPress(
        onTap: onTap,
        baseColor: btnBg,
        pressedScale: 0.94,
        borderRadius: BorderRadius.circular(999),
        padding: EdgeInsets.zero,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: btnBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Lucide.Plus, color: btnIcon, size: 22),
        ),
      ),
    );
  }
}

class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inkColor = isDark ? const Color(0xFF888888) : const Color(0xFF666666);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Lucide.Bookmark,
              size: 28,
              color: inkColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.favoritesEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                color: inkColor,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.favoritesEmptyDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            IosCardPress(
              onTap: onAdd,
              baseColor: isDark
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF000000),
              pressedScale: 0.96,
              borderRadius: BorderRadius.circular(10),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Lucide.Plus,
                    size: 15,
                    color: isDark
                        ? const Color(0xFF000000)
                        : const Color(0xFFFFFFFF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.favoritesAddCard,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF000000)
                          : const Color(0xFFFFFFFF),
                      fontWeight: AppFontWeights.semibold,
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
}

class _FavoriteCardTile extends StatelessWidget {
  const _FavoriteCardTile({
    required this.card,
    required this.referenced,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onPreview,
  });

  final FavoriteCard card;
  final bool referenced;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 黑白灰毛玻璃基础配色
    final headerBg = isDark ? const Color(0x33FFFFFF) : const Color(0x1A000000);
    final bodyBg = isDark ? const Color(0x40000000) : const Color(0x40FFFFFF);
    final textColor = isDark
        ? const Color(0xFFCCCCCC)
        : const Color(0xFF666666);
    final titleColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111111);
    final borderColor = isDark
        ? const Color(0x20FFFFFF)
        : const Color(0x1A000000);
    final selectedColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    return IosCardPress(
      onTap: onPreview,
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.zero,
      baseColor: Colors.transparent,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bodyBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: referenced ? selectedColor : borderColor,
            width: referenced ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColoredBox(
              color: headerBg,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(Lucide.Code, size: 13, color: titleColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 12,
                          fontFamily: 'Noto Serif SC',
                          letterSpacing: 0.4,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ),
                    IosIconButton(
                      icon: referenced ? Lucide.Check : Lucide.Plus,
                      semanticLabel: l10n.favoritesCopyForAi,
                      onTap: onCopy,
                      color: referenced ? selectedColor : titleColor,
                      size: 15,
                      padding: const EdgeInsets.all(3),
                    ),
                    IosIconButton(
                      icon: Lucide.Edit,
                      semanticLabel: l10n.messageMoreSheetEdit,
                      onTap: onEdit,
                      color: textColor,
                      size: 15,
                      padding: const EdgeInsets.all(3),
                    ),
                    IosIconButton(
                      icon: Lucide.Trash2,
                      semanticLabel: l10n.messageMoreSheetDelete,
                      color: isDark
                          ? const Color(0xFFD4878A)
                          : const Color(0xFFB86B6E),
                      onTap: onDelete,
                      size: 15,
                      padding: const EdgeInsets.all(3),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  physics: const BouncingScrollPhysics(),
                  child: SelectableText(
                    card.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      height: 1.35,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCardDialog extends StatefulWidget {
  const _FavoriteCardDialog({this.existing});

  final FavoriteCard? existing;

  @override
  State<_FavoriteCardDialog> createState() => _FavoriteCardDialogState();
}

class _FavoriteCardDialogState extends State<_FavoriteCardDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _contentController = TextEditingController(text: existing?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      showAppSnackBar(context, message: l10n.favoritesValidationMessage);
      return;
    }
    final now = DateTime.now();
    final existing = widget.existing;
    Navigator.of(context).pop(
      FavoriteCard(
        id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
        title: title,
        note: _noteController.text.trim(),
        content: content,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        sourceMessageId: existing?.sourceMessageId,
        autoSaved: existing?.autoSaved ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? l10n.favoritesEditCard : l10n.favoritesAddCard),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.favoritesTitleLabel,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(labelText: l10n.favoritesNoteLabel),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.favoritesContentLabel,
                  alignLabelWithHint: true,
                ),
                minLines: 8,
                maxLines: 16,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.homePageCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.messageEditPageSave)),
      ],
    );
  }
}

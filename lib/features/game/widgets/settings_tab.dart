import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/world_book.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/game_provider.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/game_storage_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../model/widgets/model_select_sheet.dart';

class GameSettingsTab extends StatefulWidget {
  const GameSettingsTab({super.key});

  @override
  State<GameSettingsTab> createState() => _GameSettingsTabState();
}

class _GameSettingsTabState extends State<GameSettingsTab> {
  String? _modelProvider;
  String? _modelId;
  final _storage = GameStorageService();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    final p = await _storage.loadModelProvider();
    final m = await _storage.loadModelId();
    if (mounted) {
      setState(() {
        _modelProvider = p;
        _modelId = m;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gp = context.watch<GameProvider>();
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            cs,
            l10n.gameSettingsAiModelSection,
            Lucide.Brain,
          ),
          const SizedBox(height: 8),
          _buildModelTile(cs),
          const SizedBox(height: 24),
          _buildSectionHeader(
            cs,
            l10n.gameSettingsWorldBookSection,
            Lucide.BookOpenText,
          ),
          const SizedBox(height: 8),
          _buildImportWorldBookTile(cs),
          const SizedBox(height: 24),
          _buildSectionHeader(
            cs,
            l10n.gameSettingsScriptSection,
            Lucide.Trash2,
          ),
          const SizedBox(height: 8),
          _buildDeleteButton(cs, gp),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ColorScheme cs, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildModelTile(ColorScheme cs) {
    final label = _modelProvider != null && _modelId != null
        ? '$_modelProvider / $_modelId'
        : AppLocalizations.of(context)!.gameSettingsModelNotSet;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          Lucide.Brain,
          size: 20,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
        title: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface)),
        trailing: Icon(
          Lucide.ChevronRight,
          size: 18,
          color: cs.onSurface.withValues(alpha: 0.4),
        ),
        onTap: _pickModel,
      ),
    );
  }

  Future<void> _pickModel() async {
    final sel = await showModelSelector(context);
    if (sel != null && mounted) {
      await _storage.setModel(sel.providerKey, sel.modelId);
      setState(() {
        _modelProvider = sel.providerKey;
        _modelId = sel.modelId;
      });
    }
  }

  Widget _buildImportWorldBookTile(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          Lucide.Import,
          size: 20,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
        title: Text(
          l10n.gameSettingsImportWorldBook,
          style: TextStyle(fontSize: 14, color: cs.onSurface),
        ),
        subtitle: Text(
          l10n.gameSettingsImportWorldBookDescription,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
        trailing: Icon(
          Lucide.ChevronRight,
          size: 18,
          color: cs.onSurface.withValues(alpha: 0.4),
        ),
        onTap: _importWorldBookFromFile,
      ),
    );
  }

  Future<String?> _readPickedFileAsString(PlatformFile file) async {
    try {
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        return utf8.decode(file.bytes!, allowMalformed: true);
      }
    } catch (_) {}
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    try {
      return await File(path).readAsString();
    } catch (_) {
      try {
        final bytes = await File(path).readAsBytes();
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        return null;
      }
    }
  }

  WorldBook? _parseWorldBookImport(dynamic decoded) {
    try {
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        final data = map['data'];
        if (data is Map) {
          return WorldBook.fromJson(data.cast<String, dynamic>());
        }
        if (map.containsKey('entries')) {
          return WorldBook.fromJson(map);
        }
      }
    } catch (_) {}
    return null;
  }

  WorldBook _normalizeImportedBook(
    WorldBook book, {
    required Set<String> existingBookIds,
  }) {
    var bookId = book.id.trim();
    if (bookId.isEmpty || existingBookIds.contains(bookId)) {
      bookId = const Uuid().v4();
    }

    final seenEntryIds = <String>{};
    final nextEntries = <WorldBookEntry>[];
    for (final entry in book.entries) {
      var entryId = entry.id.trim();
      if (entryId.isEmpty || !seenEntryIds.add(entryId)) {
        entryId = const Uuid().v4();
      }
      nextEntries.add(entry.copyWith(id: entryId));
    }

    return book.copyWith(id: bookId, entries: nextEntries);
  }

  Future<void> _importWorldBookFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<WorldBookProvider>();
    final assistantId = context.read<AssistantProvider>().currentAssistantId;
    await provider.initialize();
    if (!mounted) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
    } catch (_) {
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final content = await _readPickedFileAsString(result.files.first);
    if (!mounted) return;
    if (content == null || content.trim().isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.assistantEditSystemPromptImportEmpty,
        type: NotificationType.warning,
      );
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      showAppSnackBar(
        context,
        message: l10n.mcpJsonEditParseFailed,
        type: NotificationType.error,
      );
      return;
    }

    final imported = _parseWorldBookImport(decoded);
    if (imported == null) {
      showAppSnackBar(
        context,
        message: l10n.assistantEditSystemPromptImportFailed,
        type: NotificationType.error,
      );
      return;
    }

    final normalized = _normalizeImportedBook(
      imported,
      existingBookIds: provider.books.map((e) => e.id).toSet(),
    );
    await provider.addBook(normalized);

    final activeIds = provider.activeBookIdsFor(assistantId).toSet()
      ..add(normalized.id);
    await provider.setActiveBookIds(
      activeIds.toList(growable: false),
      assistantId: assistantId,
    );
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: l10n.gameSettingsImportWorldBookSuccess(normalized.name),
      type: NotificationType.success,
    );
  }

  Widget _buildDeleteButton(ColorScheme cs, GameProvider gp) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(Lucide.Trash2, size: 20, color: cs.error),
        title: Text(
          l10n.gameSettingsDeleteCurrentScript,
          style: TextStyle(fontSize: 14, color: cs.error),
        ),
        subtitle: Text(
          l10n.gameSettingsDeleteIrreversible,
          style: TextStyle(
            fontSize: 11,
            color: cs.error.withValues(alpha: 0.6),
          ),
        ),
        onTap: () => _confirmDelete(context, gp),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, GameProvider gp) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.gameSettingsDeleteDialogTitle),
        content: Text(l10n.gameSettingsDeleteDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.homePageCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.homePageDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await gp.deleteScript();
    }
  }
}

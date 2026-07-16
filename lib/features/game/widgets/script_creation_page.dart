import 'package:flutter/material.dart';
import '../../../core/models/game_script.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';

class ScriptCreationPage extends StatefulWidget {
  const ScriptCreationPage({
    super.key,
    this.embedded = false,
    this.onCancel,
    this.onCreated,
    this.initialTitle,
    this.initialInstructions,
  });

  final bool embedded;
  final VoidCallback? onCancel;
  final ValueChanged<GameScript>? onCreated;
  final String? initialTitle;
  final String? initialInstructions;

  @override
  State<ScriptCreationPage> createState() => _ScriptCreationPageState();
}

class _ScriptCreationPageState extends State<ScriptCreationPage> {
  int _step = 0;
  ScriptStyle _selectedStyle = ScriptStyle.epicAdventure;
  final _titleCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  bool _allowAiPolish = true;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle?.trim() ?? '';
    _instructionsCtrl.text = widget.initialInstructions?.trim() ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = widget.embedded ? kToolbarHeight + 12.0 : 14.0;
    final body = Container(
      color: widget.embedded
          ? Colors.transparent
          : isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF2F2F5),
      child: SafeArea(
        top: !widget.embedded,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, topPadding, 18, 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  _buildWizardHeader(cs, isDark),
                  const SizedBox(height: 18),
                  Expanded(
                    child: _step == 0
                        ? _buildStyleStep(cs, isDark)
                        : _step == 1
                        ? _buildDescribeStep(cs, isDark)
                        : _buildConfirmStep(cs, isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStepTitle(context)),
        backgroundColor: Colors.transparent,
      ),
      body: body,
    );
  }

  String _currentStepTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_step == 0) return l10n.gameScriptStepStyle;
    if (_step == 1) return l10n.gameScriptStepDescribe;
    return l10n.gameScriptStepConfirm;
  }

  int get _guideStep => _step.clamp(0, 2);

  List<_StyleOption> _styleOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _StyleOption(
        label: l10n.gameScriptStyleDailyHealing,
        description: l10n.gameScriptStyleDailyHealingDescription,
        generationRule: l10n.gameScriptStyleDailyHealingRule,
        style: ScriptStyle.dailyHealing,
      ),
      _StyleOption(
        label: l10n.gameScriptStyleEpicAdventure,
        description: l10n.gameScriptStyleEpicAdventureDescription,
        generationRule: l10n.gameScriptStyleEpicAdventureRule,
        style: ScriptStyle.epicAdventure,
      ),
      _StyleOption(
        label: l10n.gameScriptStyleSuspenseMystery,
        description: l10n.gameScriptStyleSuspenseMysteryDescription,
        generationRule: l10n.gameScriptStyleSuspenseMysteryRule,
        style: ScriptStyle.suspenseMystery,
      ),
      _StyleOption(
        label: l10n.gameScriptStyleRomanceEnsemble,
        description: l10n.gameScriptStyleRomanceEnsembleDescription,
        generationRule: l10n.gameScriptStyleRomanceEnsembleRule,
        style: ScriptStyle.romanceEnsemble,
      ),
      _StyleOption(
        label: l10n.gameScriptStyleUrbanWeird,
        description: l10n.gameScriptStyleUrbanWeirdDescription,
        generationRule: l10n.gameScriptStyleUrbanWeirdRule,
        style: ScriptStyle.urbanWeird,
      ),
      _StyleOption(
        label: l10n.gameScriptStyleAncientPower,
        description: l10n.gameScriptStyleAncientPowerDescription,
        generationRule: l10n.gameScriptStyleAncientPowerRule,
        style: ScriptStyle.ancientPower,
      ),
      _StyleOption(
        label: l10n.gameScriptStyleRomanceDrama,
        description: l10n.gameScriptStyleRomanceDramaDescription,
        generationRule: l10n.gameScriptStyleRomanceDramaRule,
        style: ScriptStyle.romanceDrama,
      ),
    ];
  }

  String _effectiveInstructions() {
    final l10n = AppLocalizations.of(context)!;
    final raw = _instructionsCtrl.text.trim();
    if (!_allowAiPolish) return raw;

    final styleOption = _styleOptions(
      context,
    ).firstWhere((o) => o.style == _selectedStyle);
    final title = _titleCtrl.text.trim();
    final base = raw.isEmpty ? l10n.gameScriptEmptyInstructionsForPolish : raw;

    return l10n.gameScriptAiPolishInstruction(
      styleOption.label,
      styleOption.generationRule,
      title.isEmpty ? l10n.gameScriptUntitled : title,
      base,
    );
  }

  Widget _buildWizardHeader(ColorScheme cs, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final accent = cs.primary;
    final ink = cs.onSurface;
    final steps = [
      l10n.gameScriptStepStyle,
      l10n.gameScriptStepDescribe,
      l10n.gameScriptStepConfirm,
    ];
    return Row(
      children: [
        if (widget.embedded)
          IosIconButton(
            icon: Lucide.X,
            size: 18,
            padding: const EdgeInsets.all(7),
            color: cs.onSurface.withValues(alpha: 0.58),
            semanticLabel: MaterialLocalizations.of(context).closeButtonLabel,
            onTap: widget.onCancel,
          )
        else
          const SizedBox(width: 34),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: List.generate(steps.length, (index) {
              final active = index == _guideStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.26)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active
                          ? accent.withValues(alpha: 0.55)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : cs.outlineVariant.withValues(alpha: 0.18)),
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: AppFontWeights.semibold,
                          color: active ? accent : ink.withValues(alpha: 0.52),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          steps[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: active
                                ? AppFontWeights.semibold
                                : AppFontWeights.medium,
                            color: active
                                ? accent
                                : ink.withValues(alpha: 0.64),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleStep(ColorScheme cs, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final styleOptions = _styleOptions(context);
    final accent = cs.primary;
    final ink = cs.onSurface;
    final muted = ink.withValues(alpha: isDark ? 0.68 : 0.62);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gameScriptStyleTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: AppFontWeights.emphasis,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.gameScriptStyleSubtitle,
                  style: TextStyle(fontSize: 13.5, height: 1.35, color: muted),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useGrid = constraints.maxWidth >= 760;
                    final itemWidth = useGrid
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: styleOptions.map((opt) {
                        return SizedBox(
                          width: itemWidth,
                          child: _buildStyleCard(
                            opt: opt,
                            cs: cs,
                            isDark: isDark,
                            accent: accent,
                            ink: ink,
                            muted: muted,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => setState(() => _step = 1),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(l10n.gameScriptNextButton),
          ),
        ),
      ],
    );
  }

  Widget _buildDescribeStep(ColorScheme cs, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected style display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                l10n.gameScriptSelectedToneLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _styleOptions(
                  context,
                ).firstWhere((o) => o.style == _selectedStyle).label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _step = 0),
                child: Text(
                  l10n.gameScriptChangeStyleButton,
                  style: TextStyle(fontSize: 12, color: cs.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.gameScriptTitleLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleCtrl,
          maxLength: 20,
          decoration: InputDecoration(
            hintText: l10n.gameScriptTitleHint,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.gameScriptInstructionsLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.gameScriptInstructionsHelper,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: cs.onSurface.withValues(alpha: 0.46),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _instructionsCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            maxLength: 10000,
            decoration: InputDecoration(
              hintText: l10n.gameScriptInstructionsHint,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Lucide.Sparkles,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.gameScriptAllowAiPolishLabel,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Switch(
              value: _allowAiPolish,
              onChanged: (v) => setState(() => _allowAiPolish = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _titleCtrl.text.trim().isEmpty
                ? null
                : () => setState(() => _step = 2),
            child: Text(l10n.gameScriptConfirmButton),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleCard({
    required _StyleOption opt,
    required ColorScheme cs,
    required bool isDark,
    required Color accent,
    required Color ink,
    required Color muted,
  }) {
    final selected = _selectedStyle == opt.style;
    return IosCardPress(
      onTap: () => setState(() => _selectedStyle = opt.style),
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      baseColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
              : isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.58)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.13)
                      : cs.outlineVariant.withValues(alpha: 0.22)),
            width: selected ? 1.1 : 0.7,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : ink.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                selected ? Lucide.Check : Lucide.BookOpenText,
                size: 15,
                color: selected ? accent : ink.withValues(alpha: 0.46),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: AppFontWeights.semibold,
                      color: selected ? accent : ink.withValues(alpha: 0.90),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    opt.description,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: muted,
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

  Widget _buildConfirmStep(ColorScheme cs, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveInstructions = _effectiveInstructions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Icon(
            Lucide.Wand2,
            size: 48,
            color: cs.primary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _titleCtrl.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _styleOptions(
              context,
            ).firstWhere((o) => o.style == _selectedStyle).label,
            style: TextStyle(fontSize: 13, color: cs.primary),
          ),
        ),
        const SizedBox(height: 20),
        if (effectiveInstructions.isNotEmpty) ...[
          Text(
            l10n.gameScriptInstructionsPreviewLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  effectiveInstructions,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ] else
          const Spacer(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.gameScriptBackToEditButton),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _onConfirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.gameScriptStartGenerateButton),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onConfirm() {
    final script = GameScript(
      title: _titleCtrl.text.trim(),
      instructions: _effectiveInstructions(),
      style: _selectedStyle,
    );
    if (widget.onCreated != null) {
      widget.onCreated!(script);
    } else {
      Navigator.of(context).pop(script);
    }
  }
}

class _StyleOption {
  final String label;
  final String description;
  final String generationRule;
  final ScriptStyle style;
  const _StyleOption({
    required this.label,
    required this.description,
    required this.generationRule,
    required this.style,
  });
}

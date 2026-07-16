import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

class PhoneTab extends StatelessWidget {
  const PhoneTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      bottom: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Lucide.Phone,
              size: 48,
              color: cs.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.gamePhoneFeatureTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.gamePhoneFeatureSubtitle,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

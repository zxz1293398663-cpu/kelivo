import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/ios_tactile.dart';
import '../icons/lucide_adapter.dart';

class DesktopVirtualPhonePage extends StatefulWidget {
  const DesktopVirtualPhonePage({super.key, this.onClose, this.isOpen = true});

  final VoidCallback? onClose;
  final bool isOpen;

  @override
  State<DesktopVirtualPhonePage> createState() => _DesktopVirtualPhonePageState();
}

class _DesktopVirtualPhonePageState extends State<DesktopVirtualPhonePage> {
  static const double _panelWidth = 320;
  static const double _panelHeight = 650;

  Offset _position = const Offset(80, 80);
  int _currentApp = 0;

  void _onClose() => widget.onClose?.call();

  void _onDrag(double dx, double dy) {
    setState(() => _position += Offset(dx, dy));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      width: _panelWidth,
      height: _panelHeight,
      child: GestureDetector(
        onPanUpdate: (d) => _onDrag(d.delta.dx, d.delta.dy),
        child: Material(
          elevation: 24,
          borderRadius: BorderRadius.circular(44),
          color: Colors.black,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(44),
              border: Border.all(color: Colors.grey.shade800, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  _buildScreen(cs),
                  _buildNotch(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotch() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 100,
        height: 28,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildScreen(ColorScheme cs) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _currentApp == 0 
          ? _buildHome(cs) 
          : _currentApp == 2 
              ? _buildMoments(cs)
              : const SizedBox.shrink(),
    );
  }

  Widget _buildHome(ColorScheme cs) {
    return Container(
      width: double.infinity, height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Text('10:09', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 64, fontWeight: FontWeight.w200)),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AppIcon(icon: Lucide.Aperture, color: Colors.purple.shade400, label: '朋友圈', onTap: () => setState(() => _currentApp = 2)),
                  _AppIcon(icon: Lucide.Power, color: Colors.red.shade400, label: '退出', onTap: _onClose),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMoments(ColorScheme cs) {
    return Container(
      color: cs.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 12, left: 16, right: 16),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: [
                IosIconButton(icon: Lucide.ChevronLeft, onTap: () => setState(() => _currentApp = 0)),
                const SizedBox(width: 8),
                Text('AI 朋友圈', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMomentPost(cs, 'Alice', '刚刚看了一场电影，太棒了！', '10分钟前'),
                _buildMomentPost(cs, 'Bob', '今天天气真不错，适合出去玩～', '1小时前'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomentPost(ColorScheme cs, String name, String content, String time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(Lucide.User, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade400)),
                const SizedBox(height: 4),
                Text(content, style: TextStyle(color: cs.onSurface)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(time, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    Icon(Lucide.MessageSquare, size: 16, color: cs.onSurfaceVariant),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.icon, required this.color, required this.label, this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

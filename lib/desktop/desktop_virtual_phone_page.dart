import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as winweb;
import '../icons/lucide_adapter.dart';
import '../shared/widgets/ios_tactile.dart';

class DesktopVirtualPhonePage extends StatefulWidget {
  const DesktopVirtualPhonePage({super.key, this.onClose, this.isOpen = true});

  final VoidCallback? onClose;
  final bool isOpen;

  @override
  State<DesktopVirtualPhonePage> createState() => _DesktopVirtualPhonePageState();
}

class _DesktopVirtualPhonePageState extends State<DesktopVirtualPhonePage> {
  static const double _panelWidth = 340;
  static const double _panelHeight = 680;

  Offset _position = const Offset(80, 80);

  WebViewController? _flutterCtrl;
  winweb.WebviewController? _winCtrl;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _failed = true;
      _ready = true;
      return;
    }
    _init();
  }

  void _onClose() => widget.onClose?.call();

  void _onDrag(double dx, double dy) {
    setState(() => _position += Offset(dx, dy));
  }

  Future<void> _init() async {
    try {
      if (Platform.isWindows) {
        await _initWindows();
      } else {
        await _initFlutter();
      }
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _initWindows() async {
    final c = winweb.WebviewController();
    await c.initialize();
    await c.loadUrl('https://ai-virtual-phone-zeta-black.vercel.app');
    _winCtrl = c;
  }

  Future<void> _initFlutter() async {
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);
    await c.loadRequest(Uri.parse('https://ai-virtual-phone-zeta-black.vercel.app'));
    _flutterCtrl = c;
  }

  @override
  void dispose() {
    try {
      _winCtrl?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      width: _panelWidth,
      height: _panelHeight,
      child: Material(
        elevation: 24,
        borderRadius: BorderRadius.circular(44),
        color: Colors.black, // iPhone bezel
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: Colors.grey.shade800, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ]
          ),
          child: Stack(
            children: [
              // Screen content
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: _buildScreen(),
                ),
              ),
              
              // Notch
              _buildNotch(),
              
              // Drag Zone (Top 40px)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 40,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (d) => _onDrag(d.delta.dx, d.delta.dy),
                ),
              ),

              // Close button at bottom right bezel area
              Positioned(
                bottom: -5,
                right: -5,
                child: IosIconButton(
                  icon: Lucide.X,
                  size: 16,
                  color: Colors.white54,
                  onTap: _onClose,
                )
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotch() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 0),
        width: 120,
        height: 30,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          )
        ),
      ),
    );
  }

  Widget _buildScreen() {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_failed) {
      return const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white)));
    }
    if (Platform.isWindows) {
      return _winCtrl != null ? winweb.Webview(_winCtrl!) : const SizedBox.shrink();
    }
    return _flutterCtrl != null
        ? WebViewWidget(
            controller: _flutterCtrl!,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          )
        : const SizedBox.shrink();
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as winweb;

class DesktopMusicPage extends StatefulWidget {
  const DesktopMusicPage({super.key, this.onClose, this.isOpen = true});

  final VoidCallback? onClose;
  final bool isOpen;

  @override
  State<DesktopMusicPage> createState() => _DesktopMusicPageState();
}

class _DesktopMusicPageState extends State<DesktopMusicPage> {
  static const double _panelWidth = 340;
  static const double _panelHeight = 590;

  Offset _position = const Offset(40, 40);

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

  void _handleMessage(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return;
      if (m['type'] == 'close') _onClose();
      if (m['type'] == 'drag') {
        _onDrag((m['dx'] ?? 0).toDouble(), (m['dy'] ?? 0).toDouble());
      }
    } catch (_) {}
  }

  Future<void> _init() async {
    try {
      final html = await rootBundle.loadString(
        'assets/html/netease_player.html',
      );
      final injected = html
          .replaceAll('__KELIVO_SONG__', '')
          .replaceAll('__KELIVO_ARTIST__', '');

      if (Platform.isWindows) {
        await _initWindows(injected);
      } else {
        await _initFlutter(injected);
      }
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _initWindows(String html) async {
    final c = winweb.WebviewController();
    await c.initialize();
    c.webMessage.listen((msg) => _handleMessage(msg.toString()));
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/netease_player_${DateTime.now().millisecondsSinceEpoch}.html',
    );
    await file.writeAsString(html, flush: true);
    await c.loadUrl(Uri.file(file.path).toString());
    _winCtrl = c;
  }

  Future<void> _initFlutter(String html) async {
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'KelivoHost',
        onMessageReceived: (msg) => _handleMessage(msg.message),
      );
    await c.loadHtmlString(html, baseUrl: 'https://kelivo.local/');
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
        borderRadius: BorderRadius.circular(24),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              defaultTargetPlatform == TargetPlatform.linux
                  ? 'Music player not available on Linux'
                  : 'Failed to load player',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    if (Platform.isWindows) {
      return _winCtrl != null
          ? winweb.Webview(_winCtrl!)
          : const SizedBox.shrink();
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

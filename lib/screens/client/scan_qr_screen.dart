import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/deep_link_service.dart';
import '../../widgets/common/snackbar_helper.dart';

/// Scans a `picgallery://` QR code (studio share links, studio profile
/// codes) and hands it to [DeepLinkService].
///
/// Previously, a malformed-but-`picgallery://`-prefixed code (e.g. a
/// damaged or badly-printed one) would latch [_scanned] and stop the
/// camera *before* confirming `Uri.tryParse` actually succeeded — since
/// [_onDetect] bails out immediately once [_scanned] is true, that left
/// the camera frozen forever with no feedback and no way to recover
/// short of backing out of the screen. Every other failure in the
/// scan → deep-link chain (unrecognized host, missing token/studioId)
/// was silent too. Now: the camera/[_scanned] only latch once a link is
/// confirmed parseable, a parse failure shows a snackbar and lets
/// scanning continue, and unrecognized/incomplete links are reported by
/// [DeepLinkService] itself instead of disappearing.
class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  bool _showSuccess = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    for (final barcode in capture.barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _handleCandidateLink(code.trim());
        break;
      }
    }
  }

  /// Shared by the live scanner, "scan from gallery", and manual entry.
  /// Handles canonical HTTPS links (e.g. `https://api.picgallery.in/shared/<shareId>`),
  /// custom scheme URIs (`picgallery://shared/<shareId>`), and bare token strings.
  void _handleCandidateLink(String raw) {
    if (_scanned) return;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    Uri? uri = Uri.tryParse(trimmed);
    
    // If input is not a scheme-qualified URL, treat it as a bare share token.
    if (uri == null ||
        (!trimmed.startsWith('http://') &&
            !trimmed.startsWith('https://') &&
            !trimmed.startsWith('picgallery://'))) {
      uri = Uri.tryParse('https://api.picgallery.in/shared/$trimmed');
    }

    if (uri == null) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Invalid QR code — please try again');
      }
      return;
    }

    setState(() {
      _scanned = true;
      _showSuccess = true;
    });
    _controller.stop();
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('[QR_DEBUG] Scanned QR raw: $raw => Uri: $uri');
      DeepLinkService.instance.handleLink(uri!);
    });
  }

  Future<void> _scanFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final found = await _controller.analyzeImage(file.path);
    // analyzeImage() feeds any detected barcode through the same
    // onDetect stream _onDetect is already listening to, so a
    // recognized picgallery code is handled from there. This only
    // needs to cover the "nothing found" case.
    if (found == null && mounted && !_scanned) {
      SnackBarHelper.showError(context, 'No QR code found in that image');
    }
  }

  Future<void> _showManualEntryDialog() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          title: Text(
            'Enter code',
            style: TextStyle(color: isDark ? AppColors.textOnDark : AppColors.text, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Paste a share link or code',
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    final trimmed = submitted?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;

    _handleCandidateLink(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Scan from gallery',
            icon: const Icon(Icons.image_outlined, color: Colors.white),
            onPressed: _scanFromGallery,
          ),
          IconButton(
            tooltip: 'Flip camera',
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Turn off flashlight' : 'Turn on flashlight',
                icon: Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: on ? AppColors.primary : Colors.white,
                ),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Align QR code within the frame to scan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: _showManualEntryDialog,
                  icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white70, size: 18),
                  label: const Text('Enter code instead', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
          if (_showSuccess)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showSuccess ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 96),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
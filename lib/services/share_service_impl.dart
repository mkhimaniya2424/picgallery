import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'share_service.dart';

class ShareServiceImpl implements ShareService {
  const ShareServiceImpl();

  Future<bool> _isValidFilePath(BuildContext context, String filePath) async {
    if (filePath.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path is not available.')),
        );
      }
      return false;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is missing. Please try again.')),
        );
      }
      return false;
    }

    return true;
  }

  @override
  Future<void> shareMedia({
    required BuildContext context,
    required String filePath,
  }) async {
    try {
      if (!await _isValidFilePath(context, filePath)) return;

      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(filePath)]),
      );
    } on UnsupportedError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sharing is not supported on this device.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  @override
  Future<void> shareMediaBytes({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(bytes, name: fileName, mimeType: mimeType),
          ],
        ),
      );
    } on UnsupportedError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sharing is not supported on this device.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }
}

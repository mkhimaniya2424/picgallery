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

      await Share.shareXFiles(
        [XFile(filePath)],
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
  Future<void> shareMultipleMedia({
    required BuildContext context,
    required List<String> filePaths,
  }) async {
    try {
      final validPaths = <String>[];
      for (final path in filePaths) {
        if (await _isValidFilePath(context, path)) {
          validPaths.add(path);
        }
      }
      
      if (validPaths.isEmpty) return;

      await Share.shareXFiles(
        validPaths.map((p) => XFile(p)).toList(),
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
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
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
  Future<void> shareMultipleMediaBytes({
    required BuildContext context,
    required List<Uint8List> bytesList,
    required List<String> fileNames,
    List<String?>? mimeTypes,
  }) async {
    try {
      if (bytesList.isEmpty || bytesList.length != fileNames.length) return;

      final xFiles = <XFile>[];
      for (int i = 0; i < bytesList.length; i++) {
        xFiles.add(XFile.fromData(
          bytesList[i],
          name: fileNames[i],
          mimeType: mimeTypes?[i],
        ));
      }

      await Share.shareXFiles(xFiles);
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

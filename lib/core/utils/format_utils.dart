import 'dart:math';

/// Formats a byte count into a human-readable string (e.g. "2.3 GB", "1.1 TB").
String formatBytes(int bytes, [int decimals = 1]) {
  if (bytes <= 0) return '0 B';
  const k = 1024;
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  final i = (log(bytes) / log(k)).floor();
  final clampedIndex = i.clamp(0, suffixes.length - 1);
  final numVal = bytes / pow(k, clampedIndex);
  return '${numVal.toStringAsFixed(decimals)} ${suffixes[clampedIndex]}';
}

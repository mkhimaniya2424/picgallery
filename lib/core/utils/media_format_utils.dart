/// Small formatting helpers shared by every media screen (grid, details,
/// image viewer, video player) so file sizes / durations / dates render
/// consistently everywhere instead of each screen rolling its own.
class MediaFormatUtils {
  MediaFormatUtils._();

  /// Human readable file size, e.g. `1.2 MB`, `340 KB`, `0 B`.
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final formatted =
        (size >= 100 || unitIndex == 0) ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$formatted ${units[unitIndex]}';
  }

  /// `mm:ss` (or `h:mm:ss` past an hour). Returns `--:--` when unknown.
  static String formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mm:$ss';
    return '$mm:$ss';
  }

  /// e.g. `Jul 10, 2026 • 3:45 PM`.
  static String formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour12:$minute $period';
  }

  /// e.g. `3840 × 2160`. Returns `Unknown` when dimensions aren't set.
  static String formatResolution(int width, int height) {
    if (width <= 0 || height <= 0) return 'Unknown';
    return '$width × $height';
  }
}

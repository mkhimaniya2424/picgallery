import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Fetches the shipped app's version/build info from the platform at
/// runtime (via `package_info_plus`), so the UI never has to hardcode
/// a version string that drifts from what's actually installed.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Convenience string provider, e.g. `v1.4.2 (37)`, built from
/// [packageInfoProvider]. Screens/widgets that just need display text
/// should watch this instead of reaching into [PackageInfo] directly.
final appVersionLabelProvider = Provider<AsyncValue<String>>((ref) {
  final info = ref.watch(packageInfoProvider);
  return info.whenData((value) => 'v${value.version} (${value.buildNumber})');
});

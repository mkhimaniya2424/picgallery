import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/location_repository.dart';
import 'auth_providers.dart' show apiClientProvider;

/// Backs [CascadingLocationPicker] — see [LocationRepository] for the
/// `/locations/*` wiring.
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(apiClient: ref.watch(apiClientProvider));
});

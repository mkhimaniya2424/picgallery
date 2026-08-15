import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart' show apiClientProvider;
import '../repositories/user_repository.dart';

/// Shares the single app-wide [ApiClient] (see `apiClientProvider` in
/// `auth_providers.dart`) — same pattern as `authRepositoryProvider` and
/// `locationRepositoryProvider`.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(apiClient: ref.watch(apiClientProvider));
});

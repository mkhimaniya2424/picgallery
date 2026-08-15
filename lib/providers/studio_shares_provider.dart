import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/studio_shares_repository.dart';
import 'auth_providers.dart';

/// Talks to the real backend (`app/api/routes/studio_shares.py`) via
/// [ApiStudioSharesRepository] — same "swap one line" convention as
/// [connectionsRepositoryProvider]/`albumRepositoryProvider`. No
/// notifier/state on top of this: the "Share with client" sheet is a
/// one-shot action (pick a client, fire the request, close), not a
/// screen that needs to hold onto sharing state between rebuilds.
final studioSharesRepositoryProvider = Provider<StudioSharesRepository>((ref) {
  return ApiStudioSharesRepository(apiClient: ref.watch(apiClientProvider));
});

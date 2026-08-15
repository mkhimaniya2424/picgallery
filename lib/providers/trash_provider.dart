import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_model.dart';
import '../repositories/media_repository.dart';
import 'media_provider.dart';

final trashProvider = StateNotifierProvider<TrashNotifier, List<MediaModel>>((ref) {
  final repo = ref.watch(mediaRepositoryProvider);
  return TrashNotifier(repo, ref);
});

class TrashNotifier extends StateNotifier<List<MediaModel>> {
  final MediaRepository _repo;
  final Ref _ref;

  TrashNotifier(this._repo, this._ref) : super([]) {
    load();
  }

  Future<void> load() async {
    final deleted = await _repo.fetchDeletedMedia();
    state = deleted;
  }

  Future<void> restore(String id) async {
    final item = state.firstWhere((m) => m.id == id);
    final restored = item.copyWith(isDeleted: false, modifiedAt: DateTime.now());
    await _repo.updateMedia(restored);
    await load();
    await _ref.read(mediaProvider).load();
  }

  Future<void> deletePermanently(String id) async {
    await _repo.permanentlyDeleteMedia(id);
    await load();
  }

  Future<void> emptyTrash() async {
    await _repo.emptyTrash();
    state = [];
  }
}

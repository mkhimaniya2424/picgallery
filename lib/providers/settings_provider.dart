import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_model.dart';
import '../storage/settings_local_store.dart';

final settingsStoreProvider = Provider((ref) => SettingsLocalStore());

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsModel>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<SettingsModel> {
  SettingsLocalStore get _store => ref.read(settingsStoreProvider);

  @override
  SettingsModel build() {
    _loadPersistedSettings();
    return const SettingsModel();
  }

  Future<void> _loadPersistedSettings() async {
    final data = await _store.load();
    if (data != null) {
      state = SettingsModel.fromJson(data);
    }
  }

  Future<void> updateSettings(SettingsModel newSettings) async {
    state = newSettings;
    await _store.save(newSettings.toJson());
  }

  Future<void> resetSettings() async {
    state = const SettingsModel();
    await _store.clear();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_grid_screen.dart';
import '../../providers/media_provider.dart';

/// Dedicated favorites screen. Uses the same real Hive-backed controller,
/// just with favorites filter enabled.
///
/// [MediaGridScreen] already builds its own complete app bar (title,
/// search, back button) whenever `favoritesOnly` is set, so this wrapper
/// must NOT add a second [Scaffold]/app bar on top of it — doing so used
/// to stack two headers on screen at once.
class MediaFavoritesScreen extends ConsumerWidget {
  const MediaFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Subscribe to the provider so this screen rebuilds on media changes.
    ref.watch(mediaProvider);

    // Ensure filter is set for this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(mediaProvider);
      controller.setFilterOption(MediaFilterOption.favorites);
    });

    return const MediaGridScreen(favoritesOnly: true);
  }
}

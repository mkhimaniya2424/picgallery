import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/media_provider.dart';
import '../../models/media_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/custom_app_bar.dart';

/// Minimal filter screen for Phase 4 Part 3.
/// (Controller business logic will be expanded in Step 2.)
class MediaFilterScreen extends ConsumerWidget {
  const MediaFilterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(mediaProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Filters',
        showBack: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Filter your local Hive media library',
              style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.subtitleOnDark
                      : AppColors.subtitle),
                  fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  label: Text('Photos'),
                  selected: c.type == MediaType.photo,
                  onSelected: (v) => ref
                      .read(mediaProvider)
                      .setType(v ? MediaType.photo : null),
                ),
                FilterChip(
                  label: Text('Videos'),
                  selected: c.type == MediaType.video,
                  onSelected: (v) => ref
                      .read(mediaProvider)
                      .setType(v ? MediaType.video : null),
                ),
                FilterChip(
                  label: Text('Favorites'),
                  selected: c.filterOption == MediaFilterOption.favorites,
                  onSelected: (v) => ref.read(mediaProvider).setFilterOption(
                      v ? MediaFilterOption.favorites : MediaFilterOption.all),
                ),
                FilterChip(
                  label: Text('Reset'),
                  selected: false,
                  onSelected: (_) {
                    final controller = ref.read(mediaProvider);
                    controller.setType(null);
                    controller.setAlbum(null);
                    controller.setFolder(null);
                    controller.setSearchQuery('');
                    controller.setSortOption(MediaSortOption.recent);
                    controller.setFilterOption(MediaFilterOption.all);
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Apply'),
              ),
            ),
          )
        ],
      ),
    );
  }
}

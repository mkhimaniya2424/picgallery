import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/user_providers.dart';
import '../../../widgets/common/custom_app_bar.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;

    const languages = ['English', 'Hindi', 'Spanish'];

    return Scaffold(
      appBar: CustomAppBar(title: l10n.language, showBack: true),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: languages.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final lang = languages[index];
            final selected = settings.language == lang;

            return ListTile(
              leading: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.subtitle,
              ),
              title: Text(lang, style: Theme.of(context).textTheme.titleLarge),
              trailing: selected
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        l10n.selected,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5),
                      ),
                    )
                  : null,
              onTap: () async {
                try {
                  final updatedUser = await ref
                      .read(userRepositoryProvider)
                      .updateProfile(appLanguage: lang);
                  ref.read(authProvider.notifier).setUser(updatedUser);
                  await ref
                      .read(settingsProvider.notifier)
                      .updateSettings(settings.copyWith(language: updatedUser.appLanguage));
                } catch (_) {
                  await ref
                      .read(settingsProvider.notifier)
                      .updateSettings(settings.copyWith(language: lang));
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            );
          },
        ),
      ),
    );
  }
}

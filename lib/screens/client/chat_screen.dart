import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/cards/glass_card.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/common/screen_backdrop.dart';

/// Guards against an empty-string avatar URL, not just null — an empty
/// string is falsy-looking but still "truthy" to a plain `!= null` check,
/// and `NetworkImage('')` throws just as readily as a null check missed
/// entirely (Task 9 — the studio-profile crash fix applies the same
/// guard here since [ChatScreen] hits the identical failure mode).
bool _hasAvatarUrl(String? url) => url != null && url.trim().isNotEmpty;

/// Screen listing all chat threads (connected studios/clients).
/// Wired to [ChatNotifier] which polls the API every 10 seconds.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final threads = chatState.threads;

    return Scaffold(
      
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(
        title: 'Messages',
        showBack: true,
      ),
      body: ScreenBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight),
            child: chatState.isLoading && threads.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : threads.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(chatProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 12),
                          itemCount: threads.length,
                          itemBuilder: (context, index) {
                            final thread = threads[index];
                            final msgs = chatState.messagesForThread(thread.id);
                            final unreadCount = msgs
                                .where((m) => !m.isRead)
                                .length;

                            return Padding(
                              key: ValueKey(thread.id),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: EdgeInsets.zero,
                                borderRadius: 16,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.1),
                                    backgroundImage: _hasAvatarUrl(thread.otherPartyAvatar)
                                        ? NetworkImage(thread.otherPartyAvatar!)
                                        : null,
                                    onBackgroundImageError: _hasAvatarUrl(thread.otherPartyAvatar)
                                        ? (error, stackTrace) {}
                                        : null,
                                    child: _hasAvatarUrl(thread.otherPartyAvatar)
                                        ? null
                                        : const Icon(Icons.person_rounded,
                                            color: AppColors.primary),
                                  ),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          thread.otherPartyName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                      if (thread.lastMessageAt != null)
                                        Text(
                                          _formatTime(thread.lastMessageAt!),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.subtitle,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            thread.lastMessagePreview ??
                                                'No messages yet',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: unreadCount > 0
                                                  ? AppColors.text
                                                  : AppColors.subtitle,
                                              fontWeight: unreadCount > 0
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        if (unreadCount > 0)
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              unreadCount.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    // Load messages for this thread
                                    ref
                                        .read(chatProvider.notifier)
                                        .loadMessages(thread.id);
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.chatThread,
                                      arguments: {
                                        'threadId': thread.id,
                                        'connectionId': thread.connectionId,
                                        'otherPartyName':
                                            thread.otherPartyName,
                                        'otherPartyAvatar':
                                            thread.otherPartyAvatar,
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmptyStateCard(
              icon: Icons.chat_bubble_outline_rounded,
              message: 'No Active Messages',
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Direct conversations with connected studios will be listed here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtitle,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(time);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE').format(time);
    } else {
      return DateFormat('dd/MM/yyyy').format(time);
    }
  }
}
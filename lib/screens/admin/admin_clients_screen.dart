import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exceptions.dart';
import '../../models/admin_dashboard_data.dart';
import '../../models/studio_client_connection_model.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/studio_client_connections_provider.dart';

class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  ConsumerState<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showInviteClientDialog() {
    final formKey = GlobalKey<FormState>();
    String email = '';
    bool isSending = false;

    // Captured from THIS screen's own (permanently mounted) context,
    // not the bottom sheet's builder context — that one gets deactivated
    // the moment `Navigator.pop(context)` runs below, so calling
    // `ScaffoldMessenger.of(context)` afterwards on it throws
    // "deactivated widget" and gets swallowed by the catch block. That
    // silent failure was the actual bug: the invite (and its email) was
    // going through on the backend the whole time, but the confirmation
    // snackbar never showed, so it looked like nothing happened.
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Invite New Client',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // `POST /connections/invite-by-email` handles both
                      // cases: if this email already has a PicGallery
                      // client account it's connected right away; if not,
                      // the backend records the invite and emails them a
                      // signup link, then auto-connects them the moment
                      // they register with this email.
                      Text(
                        "If they already have a PicGallery client account we'll connect right away. Otherwise we'll email them an invitation to join.",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceRaised : AppColors.surfaceElevated,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.email_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Please enter an email';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(val.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        onSaved: (val) => email = val!.trim(),
                        enabled: !isSending,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSending
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  formKey.currentState!.save();

                                  setSheetState(() => isSending = true);
                                  try {
                                    final result = await ref
                                        .read(connectionsProvider.notifier)
                                        .studioInviteByEmail(email);
                                    if (context.mounted) Navigator.pop(context);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result.isPendingSignup
                                              ? "Invitation emailed to $email — they'll be connected automatically once they sign up."
                                              : 'Invitation sent to ${result.connection!.clientData?.name ?? email}',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    setSheetState(() => isSending = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            e is NotFoundException
                                                ? e.message
                                                : 'Could not send the invitation. Please try again.'),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: isSending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Send Invitation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_clients_fab',
        onPressed: _showInviteClientDialog,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab bar
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? AppColors.subtitleOnDark : AppColors.subtitle,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Pending Requests'),
                  Tab(text: 'Connected Clients'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PendingRequestsTab(),
                  _ConnectedClientsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab showing pending connection requests from Clients to the Studio.
class _PendingRequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsProvider);
    final studioId = ref.watch(authStateProvider).user?.id ?? '';
    final connNotifier = ref.read(connectionsProvider.notifier);

    return connectionsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.sm),
            const Text('Failed to load requests', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => connNotifier.refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (connections) {
        final pendingRequests = connections
            .where((c) =>
                c.studioId == studioId &&
                c.status == ConnectionStatus.pendingClientRequest)
            .toList();

        if (pendingRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_disabled_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4), size: 48),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Clients can send you a connection request\nfrom the Discover Studios screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => connNotifier.refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: pendingRequests.length,
            itemBuilder: (context, index) {
              final request = pendingRequests[index];
              final client = request.clientData;
              return _PendingRequestCard(
                request: request,
                clientName: client?.name ?? 'Unknown Client',
                clientInitials: client?.initials ?? '??',
                clientEmail: client?.email ?? '',
                onAccept: () {
                  connNotifier.studioAcceptRequest(request.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Accepted ${client?.name ?? "client"}'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                onReject: () {
                  connNotifier.studioRejectRequest(request.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rejected ${client?.name ?? "client"}'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Tab showing connected/accepted clients.
class _ConnectedClientsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(adminDashboardProvider);
    final connections = ref.watch(connectionsProvider).valueOrNull ?? [];
    // Same fix as _PendingRequestsTab: filter against the real
    // authenticated studio id, not the stale/local settings.studioId.
    final studioId = ref.watch(authStateProvider).user?.id ?? '';

    final connected = connections
        .where((c) =>
            c.studioId == studioId && c.status == ConnectionStatus.connected)
        .toList();

    return dashboardAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, _) => Center(
          child: Text('Error loading clients: $err',
              style: const TextStyle(color: AppColors.error))),
      data: (snapshot) {
        if (connected.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4), size: 48),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'No connected clients yet',
                  style: TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Accept pending requests to build\nyour client list.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        // Build a lookup from the richer dashboard snapshot so we can
        // merge booking/gallery/payment info into each card.  For any
        // client not yet in the snapshot (e.g. just accepted), we fall
        // back to the lean profile that connections already carry.
        final dashboardById = {
          for (final c in snapshot.clients) c.id: c,
        };

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: connected.length,
          itemBuilder: (context, index) {
            final conn = connected[index];
            final rawClientData = conn.clientData;
            if (rawClientData == null) return const SizedBox.shrink();

            // Prefer the richer dashboard snapshot entry when it exists.
            final clientData =
                dashboardById[rawClientData.id] ?? rawClientData;

            return _ClientCard(
              client: clientData,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/admin/clients/details',
                  arguments: clientData.id,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  final StudioClientConnection request;
  final String clientName;
  final String clientInitials;
  final String clientEmail;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingRequestCard({
    required this.request,
    required this.clientName,
    required this.clientInitials,
    required this.clientEmail,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceRaised : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border),
        boxShadow:
            AppShadows.soft(AppColors.primary, opacity: 0.04, blur: 16, y: 8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C5CFF), Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                clientInitials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Pending Request',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (clientEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      clientEmail,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.check_rounded,
                        color: AppColors.success, size: 20),
                    onPressed: onAccept,
                    tooltip: 'Accept',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.error, size: 20),
                    onPressed: onReject,
                    tooltip: 'Reject',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _ClientCard extends StatelessWidget {
  final ClientData client;
  final VoidCallback onTap;

  const _ClientCard({
    required this.client,
    required this.onTap,
  });

  (String, Color) get _galleryLabel {
    switch (client.galleryStatus) {
      case GalleryStatus.delivered:
        return ('Delivered', AppColors.success);
      case GalleryStatus.editing:
        return ('Editing', const Color(0xFFF59E0B));
      case GalleryStatus.notStarted:
        return ('Not Started', AppColors.subtitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (galleryLabel, galleryColor) = _galleryLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceRaised : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border),
        boxShadow:
            AppShadows.soft(AppColors.primary, opacity: 0.04, blur: 16, y: 8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: client.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      client.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            // Only show booking-level badges (gallery status /
                            // paid) when there is real booking data behind them
                            // (non-zero booking value or delivered/editing
                            // status). If all we have is the bare connection
                            // profile (defaults from the /connections API), show
                            // a simple "Connected" badge instead to avoid
                            // misleading "Not Started / Unpaid" defaults.
                            if (client.bookingValue > 0 ||
                                client.galleryStatus != GalleryStatus.notStarted) ...[
                              _Badge(label: galleryLabel, color: galleryColor),
                              _Badge(
                                label: client.isPaid ? 'Paid' : 'Unpaid',
                                color: client.isPaid
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ] else
                              _Badge(
                                label: client.bookingStatus.isNotEmpty
                                    ? client.bookingStatus
                                    : 'Connected',
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        client.lastActive != null
                            ? 'Active ${relativeTime(client.lastActive!)}'
                            : 'Inactive',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
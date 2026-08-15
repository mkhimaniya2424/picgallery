import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routes/app_routes.dart';
import '../../providers/drawer_provider.dart';

/// Wraps an action that requires an active subscription.
/// If the current plan is Free or expired, shows a snackbar and redirects
/// to the subscription plans screen. Otherwise, executes [onSuccess].
///
/// If the subscription status hasn't finished loading from the backend yet,
/// this waits for it instead of assuming "expired" — previously a fast tap
/// right after navigating (before the async provider resolved) would
/// incorrectly show "plan has expired" even for an active subscription,
/// only to work correctly on the very next tap once the data had loaded.
Future<void> requireActiveSubscription(BuildContext context, WidgetRef ref, VoidCallback onSuccess) async {
  final subStateAsync = ref.read(subscriptionStateProvider);

  final subState = subStateAsync.isLoading
      ? await ref.read(subscriptionStateProvider.future)
      : subStateAsync.valueOrNull;

  if (!context.mounted) return;

  if (subState == null || subState.plan == SubscriptionPlan.free || subState.isExpired) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your plan has expired. Please upgrade to continue.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushNamed(AppRoutes.subscriptionPlans);
  } else {
    onSuccess();
  }
}
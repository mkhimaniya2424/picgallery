import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routes/app_routes.dart';
import '../../providers/drawer_provider.dart';

/// Wraps an action that requires an active subscription.
/// If the current plan is Free or expired, shows a snackbar and redirects
/// to the subscription plans screen. Otherwise, executes [onSuccess].
void requireActiveSubscription(BuildContext context, WidgetRef ref, VoidCallback onSuccess) {
  final subState = ref.read(subscriptionStateProvider).valueOrNull;
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

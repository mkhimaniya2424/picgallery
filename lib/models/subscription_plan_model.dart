import '../../providers/drawer_provider.dart';

/// Describes a subscription tier offered to studio owners.
///
/// Key changes from the earlier stub:
///  • Free trial   — 5 days, price ₹0
///  • Pro (6-month) — ₹9,000 for exactly 6 calendar months
///  • Premium (yearly) — ₹16,000 for exactly 1 calendar year
///
/// The actual expiry DateTime is computed and stored in
/// [SubscriptionState] (see [drawer_provider.dart]), NOT here.
class SubscriptionPlanModel {
  final String id;
  final String name;
  final String subtitle;
  final double price;
  final String currency;
  final String duration;
  final String billingPeriod;
  final List<String> features;
  final String backupDuration;
  final bool isPopular;
  final SubscriptionPlan planType;
  /// Number of calendar months this plan lasts. 0 = lifetime/trial (uses [trialDays]).
  final int months;
  /// Days for a free trial plan (only used when [planType] == SubscriptionPlan.trial).
  final int trialDays;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.price,
    required this.currency,
    required this.duration,
    required this.billingPeriod,
    required this.features,
    required this.backupDuration,
    required this.isPopular,
    required this.planType,
    this.months = 0,
    this.trialDays = 0,
  });

  /// Computes the exact expiry [DateTime] for this plan given an [activatedAt]
  /// timestamp.  The same hour/minute/second is preserved so a subscription
  /// started at 08:00 PM expires at 08:00 PM 6 months / 1 year later.
  DateTime computeExpiresAt(DateTime activatedAt) {
    if (planType == SubscriptionPlan.trial) {
      return activatedAt.add(Duration(days: trialDays));
    }
    if (months > 0) {
      // Add calendar months — handles year rollovers automatically.
      int newMonth = activatedAt.month + months;
      int newYear  = activatedAt.year + (newMonth - 1) ~/ 12;
      newMonth     = ((newMonth - 1) % 12) + 1;
      // Clamp day to the last day of the resulting month (e.g. Jan 31 + 1 month → Feb 28/29).
      final maxDay = DateTime(newYear, newMonth + 1, 0).day;
      final day    = activatedAt.day > maxDay ? maxDay : activatedAt.day;
      return DateTime(
        newYear, newMonth, day,
        activatedAt.hour, activatedAt.minute, activatedAt.second,
      );
    }
    // Free plan — no expiry (set far future).
    return DateTime(9999);
  }

  static const List<SubscriptionPlanModel> plans = [
    // ── No Active Plan ───────────────────────────────────────────────────────
    // Placeholder entry for `SubscriptionPlan.free` (a brand-new account, or a
    // plan that has expired and lapsed back to "no plan"). Never shown as a
    // purchasable card in the pricing grid — `_PlanCard` loops only render
    // paid/trial entries — this exists purely so `firstWhere(planType ==
    // currentPlanType)` resolves correctly for a free/no-plan user instead of
    // silently falling back to `plans[0]` (which used to BE the trial plan,
    // causing a fresh account to display "Current Plan: 5-Day Free Trial").
    SubscriptionPlanModel(
      id: 'free',
      name: 'No Active Plan',
      subtitle: 'Choose a plan to get started',
      price: 0,
      currency: '₹',
      duration: '',
      billingPeriod: '',
      months: 0,
      trialDays: 0,
      features: [],
      backupDuration: 'No Backup',
      isPopular: false,
      planType: SubscriptionPlan.free,
    ),

    // ── Free Trial (5 days) ──────────────────────────────────────────────────
    SubscriptionPlanModel(
      id: 'trial',
      name: '5-Day Free Trial',
      subtitle: 'Try everything — no payment needed',
      price: 0,
      currency: '₹',
      duration: '5 Days',
      billingPeriod: 'Trial',
      months: 0,
      trialDays: 5,
      features: [
        'Unlimited galleries',
        'Unlimited storage',
        '24/7 Priority Support',
        'All premium features',
      ],
      backupDuration: '5-Day Trial Backup',
      isPopular: false,
      planType: SubscriptionPlan.trial,
    ),

    // ── Pro — 6 months ───────────────────────────────────────────────────────
    SubscriptionPlanModel(
      id: 'premium_6m',
      name: 'Pro 6-Month Plan',
      subtitle: 'Power up your studio for 6 months',
      price: 7999,
      currency: '₹',
      duration: '6 Months',
      billingPeriod: '6 Months',
      months: 6,
      features: [
        'Unlimited Galleries',
        'Unlimited Storage',
        '24/7 Priority Support',
        '6-Month Backup Storage',
        'Advanced Analytics',
        'Client Portal',
      ],
      backupDuration: '6 Months Backup',
      isPopular: false,
      planType: SubscriptionPlan.pro,
    ),

    // ── Premium — yearly ─────────────────────────────────────────────────────
    SubscriptionPlanModel(
      id: 'premium_yearly',
      name: 'Premium Yearly Plan',
      subtitle: 'The ultimate professional toolkit',
      price: 13999,
      currency: '₹',
      duration: '1 Year',
      billingPeriod: 'Year',
      months: 12,
      features: [
        'Unlimited Galleries',
        'Unlimited Storage',
        '24/7 Priority Support',
        '1-Year Backup Storage',
        'Advanced Analytics',
        'Client Portal',
      ],
      backupDuration: '1 Year Backup',
      isPopular: true,
      planType: SubscriptionPlan.premium,
    ),
  ];

  /// Returns the plan with the given [planType]. Every [SubscriptionPlan]
  /// value (including `free`) now has a matching entry in [plans], so this
  /// should always find a real match — `orElse` only exists as a
  /// last-resort safety net and intentionally falls back to the `free`
  /// entry (not trial), so an unrecognized type never gets misrepresented
  /// as an active paid/trial plan.
  static SubscriptionPlanModel forType(SubscriptionPlan type) =>
      plans.firstWhere((p) => p.planType == type,
          orElse: () => plans.firstWhere((p) => p.planType == SubscriptionPlan.free));
}
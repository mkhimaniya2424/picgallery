/// Data shapes + mock/demo data for the platform-wide Super Admin panel.
///
/// IMPORTANT: this is a brand-new surface, separate from
/// `screens/admin/*` (which is the Studio Owner's own dashboard for
/// managing *their* clients). This panel is for the platform owner —
/// it looks across ALL studios and ALL clients on the whole platform.
///
/// Nothing here is wired to the real backend yet (there is no
/// super-admin API today — see `app/api/routes` in the backend repo).
/// Every list below is static/mock so the screens are visually
/// complete and clickable; swap `SuperAdminMockData.*` for real
/// provider calls once the backend endpoints exist.
///
/// "Website user" — assumed here to mean a public-site visitor/lead
/// who filled a contact/interest form but has NOT created a Studio or
/// Client account yet. If you actually meant "Client, just relabeled",
/// delete `WebsiteLead` below and merge its list into `PlatformUser`
/// with `type: PlatformUserType.client` instead — everything else
/// (screens, nav) still works unchanged.
library;

import 'package:flutter/material.dart';

enum PlatformUserType { studio, client }

enum SubscriptionStatus { active, trial, expired, none }

extension SubscriptionStatusX on SubscriptionStatus {
  String get label => switch (this) {
        SubscriptionStatus.active => 'Active',
        SubscriptionStatus.trial => 'Trial',
        SubscriptionStatus.expired => 'Expired',
        SubscriptionStatus.none => 'No subscription',
      };

  Color get color => switch (this) {
        SubscriptionStatus.active => const Color(0xFF22C55E),
        SubscriptionStatus.trial => const Color(0xFFEFBF6B),
        SubscriptionStatus.expired => const Color(0xFFEF4444),
        SubscriptionStatus.none => const Color(0xFF6B7280),
      };
}

/// One row in the Studio Users or Client Users list.
///
/// `linkedAccountId` is the key piece for the "same email, two roles"
/// case: your backend allows one email to have a separate Client row
/// AND a separate Studio row (`uq_users_email_role`). When that's
/// true for a person, both `PlatformUser` rows carry each other's id
/// here, so the detail screen can show "This email also has a
/// [Client/Studio] account" and let the admin jump straight to it —
/// instead of the two rows looking like unrelated strangers who
/// happen to share an email.
class PlatformUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final PlatformUserType type;
  final DateTime joinedAt;
  final String city;
  final String? studioName; // studio-only
  final SubscriptionStatus subscriptionStatus; // studio-only; .none for clients
  final String? linkedAccountId; // id of this email's other-role account, if any

  const PlatformUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.type,
    required this.joinedAt,
    required this.city,
    this.studioName,
    this.subscriptionStatus = SubscriptionStatus.none,
    this.linkedAccountId,
  });

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// A public-website visitor/lead — see the "website user" note above.
class WebsiteLead {
  final String id;
  final String name;
  final String email;
  final String source; // e.g. "Contact form", "Pricing page", "Newsletter"
  final DateTime visitedAt;
  final bool convertedToAccount;

  const WebsiteLead({
    required this.id,
    required this.name,
    required this.email,
    required this.source,
    required this.visitedAt,
    this.convertedToAccount = false,
  });
}

class SuperAdminMockData {
  SuperAdminMockData._();

  // Demonstrates the dual-role case on purpose: "riya@lumenstudio.in"
  // has BOTH a Studio row (s2) and a Client row (c3), same email.
  static final List<PlatformUser> studios = [
    PlatformUser(
      id: 's1',
      fullName: 'Arjun Mehta',
      email: 'arjun@framewalastudio.com',
      phone: '+91 98200 11223',
      type: PlatformUserType.studio,
      joinedAt: DateTime(2025, 2, 14),
      city: 'Mumbai',
      studioName: 'Framewala Studio',
      subscriptionStatus: SubscriptionStatus.active,
    ),
    PlatformUser(
      id: 's2',
      fullName: 'Riya Sharma',
      email: 'riya@lumenstudio.in',
      phone: '+91 99870 44556',
      type: PlatformUserType.studio,
      joinedAt: DateTime(2025, 5, 2),
      city: 'Ahmedabad',
      studioName: 'Lumen Studio',
      subscriptionStatus: SubscriptionStatus.trial,
      linkedAccountId: 'c3',
    ),
    PlatformUser(
      id: 's3',
      fullName: 'Karan Patel',
      email: 'karan@clickfolks.com',
      phone: '+91 90210 77889',
      type: PlatformUserType.studio,
      joinedAt: DateTime(2024, 11, 30),
      city: 'Rajkot',
      studioName: 'ClickFolks Photography',
      subscriptionStatus: SubscriptionStatus.expired,
    ),
  ];

  static final List<PlatformUser> clients = [
    PlatformUser(
      id: 'c1',
      fullName: 'Neha Joshi',
      email: 'neha.joshi@gmail.com',
      phone: '+91 98980 12121',
      type: PlatformUserType.client,
      joinedAt: DateTime(2025, 6, 10),
      city: 'Pune',
    ),
    PlatformUser(
      id: 'c2',
      fullName: 'Devansh Rao',
      email: 'devansh.rao@gmail.com',
      phone: '+91 91234 56789',
      type: PlatformUserType.client,
      joinedAt: DateTime(2025, 7, 1),
      city: 'Bengaluru',
    ),
    // Same person + same email as studio s2 above — the client-side row.
    PlatformUser(
      id: 'c3',
      fullName: 'Riya Sharma',
      email: 'riya@lumenstudio.in',
      phone: '+91 99870 44556',
      type: PlatformUserType.client,
      joinedAt: DateTime(2025, 5, 20),
      city: 'Ahmedabad',
      linkedAccountId: 's2',
    ),
  ];

  static final List<WebsiteLead> websiteLeads = [
    WebsiteLead(
      id: 'w1',
      name: 'Priya Nair',
      email: 'priya.nair@outlook.com',
      source: 'Pricing page',
      visitedAt: DateTime(2026, 7, 28),
    ),
    WebsiteLead(
      id: 'w2',
      name: 'Sameer Khan',
      email: 'sameer.k@yahoo.com',
      source: 'Contact form',
      visitedAt: DateTime(2026, 7, 25),
      convertedToAccount: true,
    ),
    WebsiteLead(
      id: 'w3',
      name: 'Ananya Iyer',
      email: 'ananya.iyer@gmail.com',
      source: 'Newsletter signup',
      visitedAt: DateTime(2026, 7, 20),
    ),
  ];

  static List<PlatformUser> get allUsers => [...studios, ...clients];

  static PlatformUser? findById(String id) {
    for (final u in allUsers) {
      if (u.id == id) return u;
    }
    return null;
  }
}

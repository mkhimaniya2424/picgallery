

import '../../legal/common/expandable_faq_section.dart';

/// Local, structured Help & Support content.
///
/// This is intentionally UI-independent so it can later be swapped with a
/// backend-driven repository with minimal changes.
class HelpSupportContent {
  final List<FaqSectionData> faqSections;
  final SupportContact contact;
  final String lastUpdated;

  const HelpSupportContent({
    required this.faqSections,
    required this.contact,
    required this.lastUpdated,
  });

  /// Builds a [HelpSupportContent] from the backend's
  /// `HelpSupportContentOut` shape (`GET /legal/help-support`):
  /// `{last_updated, faq_sections, contact}`.
  factory HelpSupportContent.fromApiJson(Map<String, dynamic> json) {
    return HelpSupportContent(
      lastUpdated: json['last_updated'] as String,
      faqSections: (json['faq_sections'] as List)
          .map((s) => FaqSectionData.fromApiJson(s as Map<String, dynamic>))
          .toList(),
      contact:
          SupportContact.fromApiJson(json['contact'] as Map<String, dynamic>),
    );
  }
}

class SupportContact {
  final String title;
  final String email;
  final String phone;
  final List<SupportAction> actions;

  const SupportContact({
    required this.title,
    required this.email,
    required this.phone,
    required this.actions,
  });

  /// Builds a [SupportContact] from the backend's `SupportContactOut`
  /// shape (`app/schemas/legal.py`): `{title, email, phone, actions}`.
  factory SupportContact.fromApiJson(Map<String, dynamic> json) {
    return SupportContact(
      title: json['title'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      actions: (json['actions'] as List)
          .map((a) => SupportAction.fromApiJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SupportAction {
  final String label;
  final String payload;
  final SupportActionType type;

  const SupportAction({
    required this.label,
    required this.payload,
    required this.type,
  });

  /// Builds a [SupportAction] from the backend's `SupportActionOut` shape
  /// (`app/schemas/legal.py`): `{label, payload, type}`, where `type` is
  /// one of the raw strings `"email" | "phone" | "copy"`.
  factory SupportAction.fromApiJson(Map<String, dynamic> json) {
    return SupportAction(
      label: json['label'] as String,
      payload: json['payload'] as String,
      type: SupportActionType.fromApiJson(json['type'] as String),
    );
  }
}

enum SupportActionType {
  email,
  phone,
  copy;

  /// Maps the backend's raw `type` string (`"email" | "phone" | "copy"`)
  /// onto this enum. Falls back to [SupportActionType.copy] for any
  /// unrecognized value so an unexpected/new backend type degrades to a
  /// safe "copy the payload" action instead of throwing.
  static SupportActionType fromApiJson(String value) {
    switch (value) {
      case 'email':
        return SupportActionType.email;
      case 'phone':
        return SupportActionType.phone;
      case 'copy':
        return SupportActionType.copy;
      default:
        return SupportActionType.copy;
    }
  }
}

const helpSupportContentLocal = HelpSupportContent(
  lastUpdated: '2026-07-01',
  faqSections: [
    FaqSectionData(
      title: 'Getting Started',
      items: [
        FaqItem(
          question: 'How do I create a profile?',
          answer:
              'Open Profile and complete your account details. If you’re a studio owner, add your studio information too.',
        ),
        FaqItem(
          question: 'Where can I find my collections?',
          answer:
              'Go to Collections from your Profile menu. You can create and manage collections from there.',
        ),
      ],
    ),
    FaqSectionData(
      title: 'Account & Security',
      items: [
        FaqItem(
          question: 'How do privacy settings work?',
          answer:
              'Use Privacy & Security in your Profile to adjust what information is shown and how your activity is handled.',
        ),
        FaqItem(
          question: 'I forgot my password',
          answer:
              'Use the “Forgot Password” option on the login screen to reset using your email.',
        ),
      ],
    ),
    FaqSectionData(
      title: 'Troubleshooting',
      items: [
        FaqItem(
          question: 'App is slow or stuck',
          answer:
              'Try restarting the app. If the issue continues, contact support and include your device model and app version.',
        ),
      ],
    ),
  ],
  contact: SupportContact(
    title: 'Contact Support',
    email: 'picgallery448@gmail.com',
    phone: '+91 9662220012',
    actions: [
      SupportAction(
        label: 'Email us',
        payload: 'picgallery448@gmail.com',
        type: SupportActionType.email,
      ),
      SupportAction(
        label: 'Call support',
        payload: '+919662220012',
        type: SupportActionType.phone,
      ),
      SupportAction(
        label: 'Copy email',
        payload: 'picgallery448@gmail.com',
        type: SupportActionType.copy,
      ),
    ],
  ),
);

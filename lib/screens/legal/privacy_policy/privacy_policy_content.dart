

class PolicyBullet {
  final String text;
  const PolicyBullet(this.text);
}

class PolicySection {
  final String title;
  final List<String> paragraphs;
  final List<PolicyBullet> bullets;

  const PolicySection({
    required this.title,
    required this.paragraphs,
    this.bullets = const [],
  });

  /// Builds a [PolicySection] from the backend's `PolicySectionOut` shape
  /// (`app/schemas/legal.py`): `{title, paragraphs, bullets}`, where
  /// `bullets` is a flat list of strings.
  factory PolicySection.fromApiJson(Map<String, dynamic> json) {
    return PolicySection(
      title: json['title'] as String,
      paragraphs: (json['paragraphs'] as List).cast<String>(),
      bullets: ((json['bullets'] as List?) ?? const [])
          .map((b) => PolicyBullet(b as String))
          .toList(),
    );
  }
}

class PolicyContent {
  final String lastUpdated;
  final String introTitle;
  final List<String> introParagraphs;
  final List<PolicySection> sections;

  const PolicyContent({
    required this.lastUpdated,
    required this.introTitle,
    required this.introParagraphs,
    required this.sections,
  });

  /// Builds a [PolicyContent] from the backend's `PolicyContentOut` shape
  /// (`GET /legal/privacy-policy`): `{last_updated, intro_title,
  /// intro_paragraphs, sections}`.
  factory PolicyContent.fromApiJson(Map<String, dynamic> json) {
    return PolicyContent(
      lastUpdated: json['last_updated'] as String,
      introTitle: json['intro_title'] as String,
      introParagraphs: (json['intro_paragraphs'] as List).cast<String>(),
      sections: (json['sections'] as List)
          .map((s) => PolicySection.fromApiJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

const privacyPolicyContentLocal = PolicyContent(
  lastUpdated: '2026-07-01',
  introTitle: 'Privacy Policy',
  introParagraphs: [
    'This Privacy Policy explains how p collects, uses, and protects information when you use the application.',
    'We aim to keep your data safe and to give you clear controls over your preferences.',
  ],
  sections: [
    PolicySection(
      title: 'Information We Collect',
      paragraphs: [
        'We may collect account information (e.g., name and email), usage data, and content-related metadata you generate within the app.',
        'For studio owners, we may also collect studio profile details to enable discovery and contact.',
      ],
      bullets: [
        PolicyBullet('Account profile information'),
        PolicyBullet('Device and usage analytics (non-identifying)'),
        PolicyBullet('Content and interaction metadata'),
      ],
    ),
    PolicySection(
      title: 'How We Use Information',
      paragraphs: [
        'We use information to operate the service, personalize experiences, and improve performance and reliability.',
        'We may also use information to communicate with you about support requests and account changes.',
      ],
    ),
    PolicySection(
      title: 'Security',
      paragraphs: [
        'We use reasonable technical and organizational measures designed to protect information.',
        'However, no method of transmission or storage is completely secure.',
      ],
      bullets: [
        PolicyBullet('Access controls and monitoring'),
        PolicyBullet('Encryption in transit where appropriate'),
      ],
    ),
    PolicySection(
      title: 'Contact',
      paragraphs: [
        'Questions or requests related to privacy can be sent to support.',
      ],
    ),
  ],
);

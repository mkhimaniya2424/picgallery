

class TermsSection {
  final String title;
  final List<String> paragraphs;

  const TermsSection({
    required this.title,
    required this.paragraphs,
  });

  /// Builds a [TermsSection] from the backend's `TermsSectionOut` shape
  /// (`app/schemas/legal.py`): `{title, paragraphs}`.
  factory TermsSection.fromApiJson(Map<String, dynamic> json) {
    return TermsSection(
      title: json['title'] as String,
      paragraphs: (json['paragraphs'] as List).cast<String>(),
    );
  }
}

class TermsContent {
  final String lastUpdated;
  final String introTitle;
  final List<String> introParagraphs;
  final List<TermsSection> sections;

  const TermsContent({
    required this.lastUpdated,
    required this.introTitle,
    required this.introParagraphs,
    required this.sections,
  });

  /// Builds a [TermsContent] from the backend's `TermsContentOut` shape
  /// (`GET /legal/terms-conditions`): `{last_updated, intro_title,
  /// intro_paragraphs, sections}`.
  factory TermsContent.fromApiJson(Map<String, dynamic> json) {
    return TermsContent(
      lastUpdated: json['last_updated'] as String,
      introTitle: json['intro_title'] as String,
      introParagraphs: (json['intro_paragraphs'] as List).cast<String>(),
      sections: (json['sections'] as List)
          .map((s) => TermsSection.fromApiJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

const termsConditionsContentLocal = TermsContent(
  lastUpdated: '2026-07-01',
  introTitle: 'Terms & Conditions',
  introParagraphs: [
    'By using Picgallery, you agree to be bound by these Terms & Conditions.',
    'If you do not agree, please do not use the application.',
  ],
  sections: [
    TermsSection(
      title: 'Use of the Service',
      paragraphs: [
        'You agree to use the service in a lawful manner and not to interfere with its operation.',
        'You are responsible for maintaining the confidentiality of any account credentials you use to access the service.',
      ],
    ),
    TermsSection(
      title: 'User Content',
      paragraphs: [
        'You retain ownership of your content but grant the service a license to host, display, and distribute content as necessary to operate the platform.',
        'You must ensure that your content does not violate applicable laws or third-party rights.',
      ],
    ),
    TermsSection(
      title: 'Limitation of Liability',
      paragraphs: [
        'To the maximum extent permitted by law, Picgallery shall not be liable for any indirect, incidental, special, consequential, or punitive damages.',
      ],
    ),
    TermsSection(
      title: 'Changes',
      paragraphs: [
        'We may update these Terms & Conditions from time to time. Your continued use of the service after changes are posted constitutes acceptance of the revised terms.',
      ],
    ),
  ],
);

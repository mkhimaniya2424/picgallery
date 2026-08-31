import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Deep Link URI Parsing Tests', () {
    _ParsedAction? parseAction(Uri uri) {
      if (uri.scheme == 'picgallery') {
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        return _ParsedAction(uri.host, id);
      }
      if (uri.scheme == 'https' || uri.scheme == 'http') {
        final host = uri.host.toLowerCase();
        if (host == 'api.picgallery.in' ||
            host == 'picgallery.in' ||
            host == 'www.picgallery.in' ||
            host == 'picgallery.app' ||
            host == 'www.picgallery.app') {
          final segments = uri.pathSegments;
          if (segments.isEmpty) return null;
          final action = segments.first;
          final id = segments.length > 1 ? segments[1] : null;
          return _ParsedAction(action, id);
        }
      }
      return null;
    }

    test('Canonical HTTPS share URL is parsed correctly', () {
      final uri = Uri.parse('https://api.picgallery.in/shared/abc123xyz');
      final result = parseAction(uri);
      expect(result, isNotNull);
      expect(result!.action, equals('shared'));
      expect(result.id, equals('abc123xyz'));
    });

    test('Canonical HTTPS share URL with trailing slash is parsed correctly', () {
      final uri = Uri.parse('https://api.picgallery.in/shared/abc123xyz/');
      final result = parseAction(uri);
      expect(result, isNotNull);
      expect(result!.action, equals('shared'));
      expect(result.id, equals('abc123xyz'));
    });

    test('Legacy custom scheme URI is parsed correctly', () {
      final uri = Uri.parse('picgallery://shared/abc123xyz');
      final result = parseAction(uri);
      expect(result, isNotNull);
      expect(result!.action, equals('shared'));
      expect(result.id, equals('abc123xyz'));
    });

    test('Bare token normalization produces valid Uri', () {
      const raw = 'abc123xyz';
      final uri = Uri.parse('https://api.picgallery.in/shared/$raw');
      final result = parseAction(uri);
      expect(result, isNotNull);
      expect(result!.action, equals('shared'));
      expect(result.id, equals('abc123xyz'));
    });

    test('Unrecognized domain returns null', () {
      final uri = Uri.parse('https://example.com/shared/abc123xyz');
      final result = parseAction(uri);
      expect(result, isNull);
    });
  });
}

class _ParsedAction {
  final String action;
  final String? id;
  const _ParsedAction(this.action, this.id);
}

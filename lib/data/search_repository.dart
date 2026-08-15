import '../models/search_data.dart';

/// Contract Global Search is coded against — same pattern as
/// [AdminDashboardRepository]: the UI never touches the dummy content
/// directly, only this interface, so a real search backend can replace
/// [InMemorySearchRepository] later with zero screen changes.
abstract class SearchRepository {
  /// Returns every indexed item, optionally filtered by [type] and/or
  /// matched (case-insensitive) against [query]. Starts empty — real
  /// results only appear once Albums/Folders/Photos actually exist.
  Future<List<SearchResultItem>> search({String query = '', SearchResultType? type});

  /// Short list of suggested terms shown while the search field is
  /// empty or partially typed. Starts empty — no canned suggestions.
  Future<List<String>> fetchSuggestions();
}

/// Pure in-memory repository with a small artificial delay so the
/// screen's loading state behaves like a real search backend would.
///
/// No network, no db, no local persistence (per brief). Starts with an
/// EMPTY index — no dummy Albums/Photos/Videos/Folders content and no
/// canned suggestions. Swapping this for a real search backend later
/// means writing one new class that implements [SearchRepository] and
/// wiring it into `searchRepositoryProvider` — no screen changes needed.
class InMemorySearchRepository implements SearchRepository {
  InMemorySearchRepository({Duration? latency}) : _latency = latency ?? const Duration(milliseconds: 380);

  final Duration _latency;

  final List<SearchResultItem> _items = [];

  final List<String> _suggestions = [];

  Future<void> _delay() => Future.delayed(_latency);

  @override
  Future<List<SearchResultItem>> search({String query = '', SearchResultType? type}) async {
    await _delay();
    final q = query.trim().toLowerCase();
    return _items.where((item) {
      final matchesType = type == null || item.type == type;
      final matchesQuery = q.isEmpty || item.title.toLowerCase().contains(q) || item.subtitle.toLowerCase().contains(q);
      return matchesType && matchesQuery;
    }).toList();
  }

  @override
  Future<List<String>> fetchSuggestions() async {
    await _delay();
    return _suggestions;
  }
}

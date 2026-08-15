import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed persistence for Media UI state (search/filter/sort).
///
/// This stores only UI selections, not the media library itself.
class MediaUiFiltersLocalStore {
  static const String _boxName = 'media_ui_box';
  static const String _stateKey = 'media_ui_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<MediaUiFiltersState?> load() async {
    if (!_initialized) await init();
    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    return MediaUiFiltersState.fromJson(decoded);
  }

  Future<void> save(MediaUiFiltersState state) async {
    if (!_initialized) await init();
    final json = state.toJson();
    await _box?.put(_stateKey, jsonEncode(json));
  }
}

class MediaUiFiltersState {
  final String searchQuery;
  final String? albumId;
  final String? folderId;
  final String? type; // 'photo' | 'video' | null

  final String filterOption; // 'all' | 'favorites'

  final String sortOption; // 'recent' | 'name' | 'size' | 'duration'

  final int? sizeMin;
  final int? sizeMax;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const MediaUiFiltersState({
    required this.searchQuery,
    required this.albumId,
    required this.folderId,
    required this.type,
    required this.filterOption,
    required this.sortOption,
    required this.sizeMin,
    required this.sizeMax,
    required this.dateFrom,
    required this.dateTo,
  });

  factory MediaUiFiltersState.defaultState() => const MediaUiFiltersState(
        searchQuery: '',
        albumId: null,
        folderId: null,
        type: null,
        filterOption: 'all',
        sortOption: 'recent',
        sizeMin: null,
        sizeMax: null,
        dateFrom: null,
        dateTo: null,
      );

  factory MediaUiFiltersState.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? s) {
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return MediaUiFiltersState(
      searchQuery: json['searchQuery'] as String? ?? '',
      albumId: json['albumId'] as String?,
      folderId: json['folderId'] as String?,
      type: json['type'] as String?,
      filterOption: json['filterOption'] as String? ?? 'all',
      sortOption: json['sortOption'] as String? ?? 'recent',
      sizeMin: json['sizeMin'] as int?,
      sizeMax: json['sizeMax'] as int?,
      dateFrom: parseDate(json['dateFrom'] as String?),
      dateTo: parseDate(json['dateTo'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    String? iso(DateTime? d) => d?.toIso8601String();

    return {
      'searchQuery': searchQuery,
      'albumId': albumId,
      'folderId': folderId,
      'type': type,
      'filterOption': filterOption,
      'sortOption': sortOption,
      'sizeMin': sizeMin,
      'sizeMax': sizeMax,
      'dateFrom': iso(dateFrom),
      'dateTo': iso(dateTo),
    };
  }
}

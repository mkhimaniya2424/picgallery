import 'face_model.dart';
import 'media_model.dart';

/// One gallery photo matched against the query face — mirrors
/// `FaceMatchRead` in `app/schemas/face.py`. The similarity score comes
/// straight from the backend's pgvector cosine search; nothing is
/// recomputed on-device.
class FaceSearchResultModel {
  final MediaModel media;
  final double similarity;

  const FaceSearchResultModel({
    required this.media,
    required this.similarity,
  });

  factory FaceSearchResultModel.fromJson(Map<String, dynamic> json) => FaceSearchResultModel(
        media: MediaModel.fromApiJson(json['media'] as Map<String, dynamic>),
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      );

  /// Match confidence percentage (e.g. 94 for 94%)
  int get confidencePercentage => (similarity * 100).round().clamp(0, 100);
}

/// Full response from a face-search call — mirrors `FaceSearchResponse`
/// in `app/schemas/face.py`. [detectedFaces] describes every face found
/// in the *selfie* (not the gallery); [matches] is the actual search
/// result, already deduplicated to one row per photo and sorted by
/// [FaceSearchResultModel.similarity] descending.
class FaceSearchApiResponse {
  final List<DetectedFaceModel> detectedFaces;
  final int? searchedFaceIndex;
  final List<FaceSearchResultModel> matches;

  const FaceSearchApiResponse({
    required this.detectedFaces,
    required this.searchedFaceIndex,
    required this.matches,
  });

  factory FaceSearchApiResponse.fromJson(Map<String, dynamic> json) => FaceSearchApiResponse(
        detectedFaces: (json['detected_faces'] as List<dynamic>? ?? const [])
            .map((e) => DetectedFaceModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        searchedFaceIndex: json['searched_face_index'] as int?,
        matches: (json['matches'] as List<dynamic>? ?? const [])
            .map((e) => FaceSearchResultModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

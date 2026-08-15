/// Pixel bounding box (in the ORIGINAL uploaded image's coordinate
/// space) of one detected face, as returned by the backend's face
/// search endpoints (`app/schemas/face.py::FaceBoxRead`).
class FaceBoxPixels {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const FaceBoxPixels({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory FaceBoxPixels.fromJson(Map<String, dynamic> json) => FaceBoxPixels(
        left: json['left'] as int? ?? 0,
        top: json['top'] as int? ?? 0,
        right: json['right'] as int? ?? 0,
        bottom: json['bottom'] as int? ?? 0,
      );

  int get width => (right - left) < 0 ? 0 : (right - left);
  int get height => (bottom - top) < 0 ? 0 : (bottom - top);
}

/// One face detected in the *query selfie* — mirrors `DetectedFaceRead`
/// in `app/schemas/face.py`. Carries no embedding; the real 512-D
/// ArcFace embedding never leaves the backend (detection AND matching
/// both happen server-side, in InsightFace + pgvector).
///
/// `faceIndex` is what to pass to [FaceSearchNotifier.searchWithFaceIndex]
/// on a follow-up call if the selfie has more than one face and the
/// auto-picked "largest face" result isn't the right person.
class DetectedFaceModel {
  final int faceIndex;
  final FaceBoxPixels box;
  final double confidence;

  const DetectedFaceModel({
    required this.faceIndex,
    required this.box,
    required this.confidence,
  });

  factory DetectedFaceModel.fromJson(Map<String, dynamic> json) => DetectedFaceModel(
        faceIndex: json['face_index'] as int? ?? 0,
        box: FaceBoxPixels.fromJson(json['box'] as Map<String, dynamic>? ?? const {}),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

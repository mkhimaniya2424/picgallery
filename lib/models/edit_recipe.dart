/// Holds the parameters for non-destructive photo editing.
class EditRecipe {
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final int rotation; // 0, 90, 180, 270 degrees
  final bool flipHorizontal;
  final bool flipVertical;
  final double brightness;   // -1.0 to 1.0 (neutral is 0.0)
  final double contrast;     // -1.0 to 1.0 (neutral is 0.0)
  final double saturation;   // -1.0 to 1.0 (neutral is 0.0)
  final double exposure;     // -1.0 to 1.0 (neutral is 0.0)
  final double temperature;  // -1.0 to 1.0 (neutral is 0.0)
  final double sharpen;      // 0.0 to 1.0 (neutral is 0.0)
  final String? filter;      // null or 'none', 'grayscale', 'sepia', etc.
  final double filterIntensity; // 0.0 to 1.0 (default is 1.0)

  const EditRecipe({
    this.cropLeft = 0.0,
    this.cropTop = 0.0,
    this.cropRight = 1.0,
    this.cropBottom = 1.0,
    this.rotation = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.exposure = 0.0,
    this.temperature = 0.0,
    this.sharpen = 0.0,
    this.filter,
    this.filterIntensity = 1.0,
  });

  bool get hasEdits =>
      cropLeft != 0.0 ||
      cropTop != 0.0 ||
      cropRight != 1.0 ||
      cropBottom != 1.0 ||
      rotation != 0 ||
      flipHorizontal ||
      flipVertical ||
      brightness != 0.0 ||
      contrast != 0.0 ||
      saturation != 0.0 ||
      exposure != 0.0 ||
      temperature != 0.0 ||
      sharpen != 0.0 ||
      (filter != null && filter != 'none');

  Map<String, dynamic> toJson() => {
        'cropLeft': cropLeft,
        'cropTop': cropTop,
        'cropRight': cropRight,
        'cropBottom': cropBottom,
        'rotation': rotation,
        'flipHorizontal': flipHorizontal,
        'flipVertical': flipVertical,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'exposure': exposure,
        'temperature': temperature,
        'sharpen': sharpen,
        'filter': filter,
        'filterIntensity': filterIntensity,
      };

  factory EditRecipe.fromJson(Map<String, dynamic> json) => EditRecipe(
        cropLeft: (json['cropLeft'] as num?)?.toDouble() ?? 0.0,
        cropTop: (json['cropTop'] as num?)?.toDouble() ?? 0.0,
        cropRight: (json['cropRight'] as num?)?.toDouble() ?? 1.0,
        cropBottom: (json['cropBottom'] as num?)?.toDouble() ?? 1.0,
        rotation: json['rotation'] as int? ?? 0,
        flipHorizontal: json['flipHorizontal'] as bool? ?? false,
        flipVertical: json['flipVertical'] as bool? ?? false,
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 0.0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 0.0,
        exposure: (json['exposure'] as num?)?.toDouble() ?? 0.0,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        sharpen: (json['sharpen'] as num?)?.toDouble() ?? 0.0,
        filter: json['filter'] as String?,
        filterIntensity: (json['filterIntensity'] as num?)?.toDouble() ?? 1.0,
      );

  EditRecipe copyWith({
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    int? rotation,
    bool? flipHorizontal,
    bool? flipVertical,
    double? brightness,
    double? contrast,
    double? saturation,
    double? exposure,
    double? temperature,
    double? sharpen,
    String? filter,
    double? filterIntensity,
  }) =>
      EditRecipe(
        cropLeft: cropLeft ?? this.cropLeft,
        cropTop: cropTop ?? this.cropTop,
        cropRight: cropRight ?? this.cropRight,
        cropBottom: cropBottom ?? this.cropBottom,
        rotation: rotation ?? this.rotation,
        flipHorizontal: flipHorizontal ?? this.flipHorizontal,
        flipVertical: flipVertical ?? this.flipVertical,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        exposure: exposure ?? this.exposure,
        temperature: temperature ?? this.temperature,
        sharpen: sharpen ?? this.sharpen,
        filter: filter ?? this.filter,
        filterIntensity: filterIntensity ?? this.filterIntensity,
      );

  /// Helper to combine all color adjustment values and active filter into a single 4x5 ColorFilter matrix.
  List<double> get combinedColorMatrix {
    List<double> current = _identityMatrix;

    // 1. Brightness
    if (brightness != 0.0) {
      final offset = brightness * 255.0;
      final m = [
        1.0,0.0,0.0,0.0,offset,
        0.0,1.0,0.0,0.0,offset,
        0.0,0.0,1.0,0.0,offset,
        0.0,0.0,0.0,1.0,0.0,
      ];
      current = multiplyMatrices(m, current);
    }

    // 2. Contrast
    if (contrast != 0.0) {
      final c = contrast >= 0 ? 1.0 + contrast * 1.5 : 1.0 + contrast * 0.6;
      final offset = 128.0 * (1.0 - c);
      final m = [
        c,0.0,0.0,0.0,offset,
        0.0,c,0.0,0.0,offset,
        0.0,0.0,c,0.0,offset,
        0.0,0.0,0.0,1.0,0.0,
      ];
      current = multiplyMatrices(m, current);
    }

    // 3. Saturation
    if (saturation != 0.0) {
      final sat = saturation >= 0 ? 1.0 + saturation * 1.5 : 1.0 + saturation;
      final invSat = 1.0 - sat;
      final r = 0.2126 * invSat;
      final g = 0.7152 * invSat;
      final b = 0.0722 * invSat;
      final m = [
        r + sat, g, b, 0.0, 0.0,
        r, g + sat, b, 0.0, 0.0,
        r, g, b + sat, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ];
      current = multiplyMatrices(m, current);
    }

    // 4. Exposure
    if (exposure != 0.0) {
      final exp = exposure >= 0 ? 1.0 + exposure * 1.5 : 1.0 + exposure * 0.7;
      final m = [
        exp,0.0,0.0,0.0,0.0,
        0.0,exp,0.0,0.0,0.0,
        0.0,0.0,exp,0.0,0.0,
        0.0,0.0,0.0,1.0,0.0,
      ];
      current = multiplyMatrices(m, current);
    }

    // 5. Temperature
    if (temperature != 0.0) {
      final warmth = temperature * 0.12;
      final m = [
        1.0 + warmth, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0 + warmth * 0.5, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0 - warmth, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ];
      current = multiplyMatrices(m, current);
    }

    // 6. Filter Preset
    if (filter != null && filter != 'none') {
      final filterM = _filterPresets[filter];
      if (filterM != null) {
        final List<double> finalM;
        if (filterIntensity == 1.0) {
          finalM = filterM;
        } else {
          finalM = List<double>.generate(20, (idx) {
            return _identityMatrix[idx] + (filterM[idx] - _identityMatrix[idx]) * filterIntensity;
          });
        }
        current = multiplyMatrices(finalM, current);
      }
    }

    return current;
  }

  static const List<double> _identityMatrix = [
    1.0,0.0,0.0,0.0,0.0,
    0.0,1.0,0.0,0.0,0.0,
    0.0,0.0,1.0,0.0,0.0,
    0.0,0.0,0.0,1.0,0.0,
  ];

  static final Map<String, List<double>> _filterPresets = {
    'grayscale': const [
      0.2126, 0.7152, 0.0722, 0.0, 0.0,
      0.2126, 0.7152, 0.0722, 0.0, 0.0,
      0.2126, 0.7152, 0.0722, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
    'sepia': const [
      0.393, 0.769, 0.189, 0.0, 0.0,
      0.349, 0.686, 0.168, 0.0, 0.0,
      0.272, 0.534, 0.131, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
    'vintage': const [
      0.9, 0.1, 0.0, 0.0, 20.0,
      0.0, 0.8, 0.1, 0.0, 15.0,
      0.0, 0.0, 0.7, 0.0, 10.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
    'cinematic': const [
      0.8, 0.0, 0.0, 0.0, 5.0,
      0.0, 0.9, 0.0, 0.0, 10.0,
      0.0, 0.0, 1.0, 0.0, 25.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
    'dramatic': const [
      1.3, 0.0, 0.0, 0.0, -25.0,
      0.0, 1.3, 0.0, 0.0, -25.0,
      0.0, 0.0, 1.3, 0.0, -25.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
    'cool': const [
      0.9, 0.0, 0.0, 0.0, 0.0,
      0.0, 0.95, 0.0, 0.0, 5.0,
      0.0, 0.0, 1.1, 0.0, 15.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
    'warm': const [
      1.1, 0.0, 0.0, 0.0, 15.0,
      0.0, 1.0, 0.0, 0.0, 5.0,
      0.0, 0.0, 0.9, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  };

  /// Multiplies two 5x5 color matrices (each represented as 20-element List, implied last row is [0,0,0,0,1])
  static List<double> multiplyMatrices(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0.0);

    double getA(int r, int c) {
      if (r == 4) return c == 4 ? 1.0 : 0.0;
      return a[r * 5 + c];
    }
    double getB(int r, int c) {
      if (r == 4) return c == 4 ? 1.0 : 0.0;
      return b[r * 5 + c];
    }

    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 5; c++) {
        double sum = 0.0;
        for (int i = 0; i < 5; i++) {
          sum += getA(r, i) * getB(i, c);
        }
        out[r * 5 + c] = sum;
      }
    }

    return out;
  }
}

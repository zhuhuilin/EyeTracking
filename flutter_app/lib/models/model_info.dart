// Model information and metadata for detection models
// Supports YOLO, YuNet, Haar Cascade, and MediaPipe models

enum ModelType {
  yolo,
  yunet,
  haar,
  mediaPipe,
}

enum ModelVariant {
  nano,    // Smallest, fastest
  small,   // Small, fast
  medium,  // Balanced
  large,   // Large, accurate
  xlarge,  // Largest, most accurate
  standard, // No specific variant (e.g., YuNet, Haar)
}

enum ModelFormat {
  onnx,      // ONNX format (cross-platform)
  mlpackage, // CoreML (macOS/iOS)
  tflite,    // TensorFlow Lite (mobile)
  xml,       // OpenCV XML (Haar cascades)
}

enum SupportedPlatform {
  all,
  macos,
  ios,
  android,
  windows,
  linux,
}

class ModelInfo {
  final String id;
  final String name;
  final String displayName;
  final ModelType type;
  final ModelVariant variant;
  final ModelFormat format;
  final SupportedPlatform platform;
  final String filePath;
  final double sizeMB;
  final bool bundled;
  final bool downloaded;
  final bool isCustom;
  final String? addedByAdminId;
  final Map<String, dynamic> metadata;

  // Performance indicators (0.0 - 1.0)
  final double accuracyRating;
  final double speedRating;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type,
    required this.variant,
    required this.format,
    required this.platform,
    required this.filePath,
    required this.sizeMB,
    this.bundled = false,
    this.downloaded = false,
    this.isCustom = false,
    this.addedByAdminId,
    this.metadata = const {},
    this.accuracyRating = 0.5,
    this.speedRating = 0.5,
  });

  ModelInfo copyWith({
    String? id,
    String? name,
    String? displayName,
    ModelType? type,
    ModelVariant? variant,
    ModelFormat? format,
    SupportedPlatform? platform,
    String? filePath,
    double? sizeMB,
    bool? bundled,
    bool? downloaded,
    bool? isCustom,
    String? addedByAdminId,
    Map<String, dynamic>? metadata,
    double? accuracyRating,
    double? speedRating,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      variant: variant ?? this.variant,
      format: format ?? this.format,
      platform: platform ?? this.platform,
      filePath: filePath ?? this.filePath,
      sizeMB: sizeMB ?? this.sizeMB,
      bundled: bundled ?? this.bundled,
      downloaded: downloaded ?? this.downloaded,
      isCustom: isCustom ?? this.isCustom,
      addedByAdminId: addedByAdminId ?? this.addedByAdminId,
      metadata: metadata ?? this.metadata,
      accuracyRating: accuracyRating ?? this.accuracyRating,
      speedRating: speedRating ?? this.speedRating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'type': type.name,
      'variant': variant.name,
      'format': format.name,
      'platform': platform.name,
      'filePath': filePath,
      'sizeMB': sizeMB,
      'bundled': bundled,
      'downloaded': downloaded,
      'isCustom': isCustom,
      'addedByAdminId': addedByAdminId,
      'metadata': metadata,
      'accuracyRating': accuracyRating,
      'speedRating': speedRating,
    };
  }

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'],
      name: json['name'],
      displayName: json['displayName'],
      type: ModelType.values.firstWhere((e) => e.name == json['type']),
      variant: ModelVariant.values.firstWhere((e) => e.name == json['variant']),
      format: ModelFormat.values.firstWhere((e) => e.name == json['format']),
      platform: SupportedPlatform.values.firstWhere((e) => e.name == json['platform']),
      filePath: json['filePath'],
      sizeMB: (json['sizeMB'] as num).toDouble(),
      bundled: json['bundled'] ?? false,
      downloaded: json['downloaded'] ?? false,
      isCustom: json['isCustom'] ?? false,
      addedByAdminId: json['addedByAdminId'],
      metadata: json['metadata'] ?? {},
      accuracyRating: (json['accuracyRating'] as num?)?.toDouble() ?? 0.5,
      speedRating: (json['speedRating'] as num?)?.toDouble() ?? 0.5,
    );
  }

  /// Get a human-readable description of performance
  String get performanceDescription {
    if (speedRating > 0.8 && accuracyRating > 0.8) {
      return 'Excellent (Fast & Accurate)';
    } else if (speedRating > 0.7) {
      return 'Fast';
    } else if (accuracyRating > 0.7) {
      return 'Accurate';
    } else if (speedRating > 0.5 && accuracyRating > 0.5) {
      return 'Balanced';
    } else {
      return 'Basic';
    }
  }

  /// Get variant display name
  String get variantDisplayName {
    switch (variant) {
      case ModelVariant.nano:
        return 'Nano';
      case ModelVariant.small:
        return 'Small';
      case ModelVariant.medium:
        return 'Medium';
      case ModelVariant.large:
        return 'Large';
      case ModelVariant.xlarge:
        return 'X-Large';
      case ModelVariant.standard:
        return '';
    }
  }

  /// Get full display name with variant
  String get fullDisplayName {
    if (variant == ModelVariant.standard) {
      return displayName;
    }
    return '$displayName ($variantDisplayName)';
  }

  /// Check if model is available (bundled or downloaded)
  bool get isAvailable => bundled || downloaded;

  /// Get file size as human-readable string
  String get sizeString {
    if (sizeMB < 1) {
      return '${(sizeMB * 1024).toStringAsFixed(0)} KB';
    } else if (sizeMB < 1000) {
      return '${sizeMB.toStringAsFixed(1)} MB';
    } else {
      return '${(sizeMB / 1024).toStringAsFixed(2)} GB';
    }
  }
}

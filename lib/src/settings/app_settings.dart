import 'dart:convert';

enum CompressionMethod { lossless, lossy }

enum CompressionPriority { compatibility, efficiency }

enum PreferredCodec { png, jpeg, webp, avif, jxl }

extension PreferredCodecCapabilities on PreferredCodec {
  bool get supportsTransparency {
    return switch (this) {
      PreferredCodec.jpeg => false,
      _ => true,
    };
  }
}

class AppSettings {
  const AppSettings({
    required this.compressionMethod,
    required this.compressionPriority,
    required this.advancedMode,
    required this.preferredCodec,
    required this.quality,
    required this.developerModeEnabled,
    required this.timingLogsEnabled,
  });

  final CompressionMethod compressionMethod;
  final CompressionPriority compressionPriority;
  final bool advancedMode;
  final PreferredCodec preferredCodec;
  final int quality;
  final bool developerModeEnabled;
  final bool timingLogsEnabled;

  static const defaults = AppSettings(
    compressionMethod: CompressionMethod.lossy,
    compressionPriority: CompressionPriority.compatibility,
    advancedMode: false,
    preferredCodec: PreferredCodec.jpeg,
    quality: 80,
    developerModeEnabled: false,
    timingLogsEnabled: false,
  );

  PreferredCodec get effectiveCodec {
    if (advancedMode) {
      return preferredCodec;
    }

    return switch ((compressionMethod, compressionPriority)) {
      (CompressionMethod.lossless, CompressionPriority.compatibility) =>
        PreferredCodec.png,
      (CompressionMethod.lossless, CompressionPriority.efficiency) =>
        PreferredCodec.jxl,
      (CompressionMethod.lossy, CompressionPriority.compatibility) =>
        PreferredCodec.jpeg,
      (CompressionMethod.lossy, CompressionPriority.efficiency) =>
        PreferredCodec.avif,
    };
  }

  bool get showsQualityControl {
    if (!advancedMode) {
      return compressionMethod == CompressionMethod.lossy;
    }

    return switch (preferredCodec) {
      PreferredCodec.png => false,
      PreferredCodec.jpeg => true,
      PreferredCodec.webp => true,
      PreferredCodec.avif => true,
      PreferredCodec.jxl => true,
    };
  }

  bool get qualitySupportsLosslessAtMax {
    if (!showsQualityControl) {
      return false;
    }

    return switch (advancedMode ? preferredCodec : effectiveCodec) {
      PreferredCodec.webp => true,
      PreferredCodec.jxl => true,
      _ => false,
    };
  }

  AppSettings copyWith({
    CompressionMethod? compressionMethod,
    CompressionPriority? compressionPriority,
    bool? advancedMode,
    PreferredCodec? preferredCodec,
    int? quality,
    bool? developerModeEnabled,
    bool? timingLogsEnabled,
  }) {
    return AppSettings(
      compressionMethod: compressionMethod ?? this.compressionMethod,
      compressionPriority: compressionPriority ?? this.compressionPriority,
      advancedMode: advancedMode ?? this.advancedMode,
      preferredCodec: preferredCodec ?? this.preferredCodec,
      quality: quality ?? this.quality,
      developerModeEnabled: developerModeEnabled ?? this.developerModeEnabled,
      timingLogsEnabled: timingLogsEnabled ?? this.timingLogsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'compressionMethod': compressionMethod.name,
      'compressionPriority': compressionPriority.name,
      'advancedMode': advancedMode,
      'preferredCodec': preferredCodec.name,
      'quality': quality,
      'developerModeEnabled': developerModeEnabled,
      'timingLogsEnabled': timingLogsEnabled,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static AppSettings fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Settings JSON must be an object.');
    }
    return fromJson(decoded);
  }

  static AppSettings fromJson(Map<String, dynamic> json) {
    return AppSettings(
      compressionMethod: CompressionMethod.values.byName(
        json['compressionMethod'] as String,
      ),
      compressionPriority: CompressionPriority.values.byName(
        json['compressionPriority'] as String,
      ),
      advancedMode: json['advancedMode'] as bool,
      preferredCodec: PreferredCodec.values.byName(
        json['preferredCodec'] as String,
      ),
      quality: json['quality'] as int? ?? defaults.quality,
      developerModeEnabled:
          json['developerModeEnabled'] as bool? ??
          defaults.developerModeEnabled,
      timingLogsEnabled:
          json['timingLogsEnabled'] as bool? ?? defaults.timingLogsEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.compressionMethod == compressionMethod &&
        other.compressionPriority == compressionPriority &&
        other.advancedMode == advancedMode &&
        other.preferredCodec == preferredCodec &&
        other.quality == quality &&
        other.developerModeEnabled == developerModeEnabled &&
        other.timingLogsEnabled == timingLogsEnabled;
  }

  @override
  int get hashCode => Object.hash(
    compressionMethod,
    compressionPriority,
    advancedMode,
    preferredCodec,
    quality,
    developerModeEnabled,
    timingLogsEnabled,
  );
}

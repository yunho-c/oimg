import 'dart:convert';

enum CompressionMethod { lossless, lossy }

enum CompressionPriority { compatibility, efficiency }

enum PreferredCodec { png, jpeg, webp, avif, jxl }

enum StorageDestinationMode { sameFolder, differentLocation }

enum SameFolderAction { replaceSource, keepSource }

const Object _noAppSettingsValue = Object();

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
    required this.storageDestinationMode,
    required this.sameFolderAction,
    required this.preserveFolderStructure,
    required this.preserveOriginalDate,
    required this.preserveExif,
    required this.preserveColorProfile,
    required this.developerModeEnabled,
    required this.timingLogsEnabled,
    this.differentLocationPath,
    this.previewPathHeaderEnabled = false,
  });

  final CompressionMethod compressionMethod;
  final CompressionPriority compressionPriority;
  final bool advancedMode;
  final PreferredCodec preferredCodec;
  final int quality;
  final StorageDestinationMode storageDestinationMode;
  final SameFolderAction sameFolderAction;
  final String? differentLocationPath;
  final bool preserveFolderStructure;
  final bool preserveOriginalDate;
  final bool preserveExif;
  final bool preserveColorProfile;
  final bool developerModeEnabled;
  final bool timingLogsEnabled;
  final bool previewPathHeaderEnabled;

  static const defaults = AppSettings(
    compressionMethod: CompressionMethod.lossy,
    compressionPriority: CompressionPriority.compatibility,
    advancedMode: false,
    preferredCodec: PreferredCodec.jpeg,
    quality: 80,
    storageDestinationMode: StorageDestinationMode.sameFolder,
    sameFolderAction: SameFolderAction.replaceSource,
    preserveFolderStructure: true,
    preserveOriginalDate: false,
    preserveExif: false,
    preserveColorProfile: false,
    developerModeEnabled: false,
    timingLogsEnabled: false,
    previewPathHeaderEnabled: false,
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
    StorageDestinationMode? storageDestinationMode,
    SameFolderAction? sameFolderAction,
    Object? differentLocationPath = _noAppSettingsValue,
    bool? preserveFolderStructure,
    bool? preserveOriginalDate,
    bool? preserveExif,
    bool? preserveColorProfile,
    bool? developerModeEnabled,
    bool? timingLogsEnabled,
    bool? previewPathHeaderEnabled,
  }) {
    return AppSettings(
      compressionMethod: compressionMethod ?? this.compressionMethod,
      compressionPriority: compressionPriority ?? this.compressionPriority,
      advancedMode: advancedMode ?? this.advancedMode,
      preferredCodec: preferredCodec ?? this.preferredCodec,
      quality: quality ?? this.quality,
      storageDestinationMode:
          storageDestinationMode ?? this.storageDestinationMode,
      sameFolderAction: sameFolderAction ?? this.sameFolderAction,
      differentLocationPath: identical(
        differentLocationPath,
        _noAppSettingsValue,
      )
          ? this.differentLocationPath
          : differentLocationPath as String?,
      preserveFolderStructure:
          preserveFolderStructure ?? this.preserveFolderStructure,
      preserveOriginalDate: preserveOriginalDate ?? this.preserveOriginalDate,
      preserveExif: preserveExif ?? this.preserveExif,
      preserveColorProfile:
          preserveColorProfile ?? this.preserveColorProfile,
      developerModeEnabled: developerModeEnabled ?? this.developerModeEnabled,
      timingLogsEnabled: timingLogsEnabled ?? this.timingLogsEnabled,
      previewPathHeaderEnabled:
          previewPathHeaderEnabled ?? this.previewPathHeaderEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'compressionMethod': compressionMethod.name,
      'compressionPriority': compressionPriority.name,
      'advancedMode': advancedMode,
      'preferredCodec': preferredCodec.name,
      'quality': quality,
      'storageDestinationMode': storageDestinationMode.name,
      'sameFolderAction': sameFolderAction.name,
      'differentLocationPath': differentLocationPath,
      'preserveFolderStructure': preserveFolderStructure,
      'preserveOriginalDate': preserveOriginalDate,
      'preserveExif': preserveExif,
      'preserveColorProfile': preserveColorProfile,
      'developerModeEnabled': developerModeEnabled,
      'timingLogsEnabled': timingLogsEnabled,
      'previewPathHeaderEnabled': previewPathHeaderEnabled,
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
      storageDestinationMode: StorageDestinationMode.values.byName(
        json['storageDestinationMode'] as String? ??
            defaults.storageDestinationMode.name,
      ),
      sameFolderAction: SameFolderAction.values.byName(
        json['sameFolderAction'] as String? ?? defaults.sameFolderAction.name,
      ),
      differentLocationPath:
          json['differentLocationPath'] as String? ??
          defaults.differentLocationPath,
      preserveFolderStructure:
          json['preserveFolderStructure'] as bool? ??
          defaults.preserveFolderStructure,
      preserveOriginalDate:
          json['preserveOriginalDate'] as bool? ?? defaults.preserveOriginalDate,
      preserveExif: json['preserveExif'] as bool? ?? defaults.preserveExif,
      preserveColorProfile:
          json['preserveColorProfile'] as bool? ??
          defaults.preserveColorProfile,
      developerModeEnabled:
          json['developerModeEnabled'] as bool? ??
          defaults.developerModeEnabled,
      timingLogsEnabled:
          json['timingLogsEnabled'] as bool? ?? defaults.timingLogsEnabled,
      previewPathHeaderEnabled:
          json['previewPathHeaderEnabled'] as bool? ??
          defaults.previewPathHeaderEnabled,
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
        other.storageDestinationMode == storageDestinationMode &&
        other.sameFolderAction == sameFolderAction &&
        other.differentLocationPath == differentLocationPath &&
        other.preserveFolderStructure == preserveFolderStructure &&
        other.preserveOriginalDate == preserveOriginalDate &&
        other.preserveExif == preserveExif &&
        other.preserveColorProfile == preserveColorProfile &&
        other.developerModeEnabled == developerModeEnabled &&
        other.timingLogsEnabled == timingLogsEnabled &&
        other.previewPathHeaderEnabled == previewPathHeaderEnabled;
  }

  @override
  int get hashCode => Object.hash(
    compressionMethod,
    compressionPriority,
    advancedMode,
    preferredCodec,
    quality,
    storageDestinationMode,
    sameFolderAction,
    differentLocationPath,
    preserveFolderStructure,
    preserveOriginalDate,
    preserveExif,
    preserveColorProfile,
    developerModeEnabled,
    timingLogsEnabled,
    previewPathHeaderEnabled,
  );
}

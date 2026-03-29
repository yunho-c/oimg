import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/src/settings/app_settings.dart';

void main() {
  group('AppSettings.effectiveCodec', () {
    test('uses intuitive mapping when advanced mode is off', () {
      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.avif,
          quality: 80,
        ).effectiveCodec,
        PreferredCodec.png,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.efficiency,
          advancedMode: false,
          preferredCodec: PreferredCodec.png,
          quality: 80,
        ).effectiveCodec,
        PreferredCodec.jxl,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.avif,
          quality: 80,
        ).effectiveCodec,
        PreferredCodec.jpeg,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.efficiency,
          advancedMode: false,
          preferredCodec: PreferredCodec.jpeg,
          quality: 80,
        ).effectiveCodec,
        PreferredCodec.avif,
      );
    });

    test('uses the preferred codec when advanced mode is on', () {
      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: true,
          preferredCodec: PreferredCodec.webp,
          quality: 80,
        ).effectiveCodec,
        PreferredCodec.webp,
      );
    });
  });

  group('AppSettings quality helpers', () {
    test('shows quality control only for lossy selections', () {
      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.jpeg,
          quality: 80,
        ).showsQualityControl,
        isFalse,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.png,
          quality: 80,
        ).showsQualityControl,
        isTrue,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: true,
          preferredCodec: PreferredCodec.png,
          quality: 80,
        ).showsQualityControl,
        isFalse,
      );
    });

    test('only webp and jpeg xl support lossless at max quality', () {
      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: true,
          preferredCodec: PreferredCodec.webp,
          quality: 100,
        ).qualitySupportsLosslessAtMax,
        isTrue,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: true,
          preferredCodec: PreferredCodec.jxl,
          quality: 100,
        ).qualitySupportsLosslessAtMax,
        isTrue,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: true,
          preferredCodec: PreferredCodec.jpeg,
          quality: 100,
        ).qualitySupportsLosslessAtMax,
        isFalse,
      );
    });
  });
}

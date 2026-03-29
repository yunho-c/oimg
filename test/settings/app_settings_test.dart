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
        ).effectiveCodec,
        PreferredCodec.png,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.efficiency,
          advancedMode: false,
          preferredCodec: PreferredCodec.png,
        ).effectiveCodec,
        PreferredCodec.jxl,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.avif,
        ).effectiveCodec,
        PreferredCodec.jpeg,
      );

      expect(
        const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.efficiency,
          advancedMode: false,
          preferredCodec: PreferredCodec.jpeg,
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
        ).effectiveCodec,
        PreferredCodec.webp,
      );
    });
  });
}

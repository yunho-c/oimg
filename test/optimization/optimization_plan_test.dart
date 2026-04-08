import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/src/file_open/opened_image_file.dart';
import 'package:oimg/src/optimization/optimization_plan.dart';
import 'package:oimg/src/rust/types.dart';
import 'package:oimg/src/settings/app_settings.dart';

void main() {
  group('buildOptimizationPlan', () {
    test('uses optimize when the selected codec matches the source format', () {
      final plan = buildOptimizationPlan(
        file: OpenedImageFile(
          path: '/tmp/photo.jpg',
          metadata: ImageMetadata(
            width: 48,
            height: 32,
            format: 'jpeg',
            fileSize: BigInt.from(2000),
            hasTransparency: false,
          ),
        ),
        settings: AppSettings.defaults,
      );

      expect(plan.usesSourceCodec, isTrue);
      expect(plan.useSourceImageForPreview, isFalse);
      expect(plan.processRequest.outputPath, isNull);
      plan.processRequest.operation.when(
        convert: (_) => fail('expected optimize'),
        optimize: (options) {
          expect(options.quality, 80);
          expect(options.writeOnlyIfSmaller, isTrue);
        },
        resize: (_) => fail('unexpected resize'),
        crop: (_) => fail('unexpected crop'),
        extend: (_) => fail('unexpected extend'),
      );
    });

    test('uses convert and optimized sibling output when codec changes', () {
      final plan = buildOptimizationPlan(
        file: OpenedImageFile(
          path: '/tmp/photo.png',
          metadata: ImageMetadata(
            width: 48,
            height: 32,
            format: 'png',
            fileSize: BigInt.from(3000),
            hasTransparency: false,
          ),
        ),
        settings: AppSettings.defaults,
      );

      expect(plan.usesSourceCodec, isFalse);
      expect(plan.useSourceImageForPreview, isFalse);
      expect(plan.processRequest.outputPath, '/tmp/photo.optimized.jpeg');
      plan.processRequest.operation.when(
        convert: (options) {
          expect(options.targetFormat, 'jpeg');
          expect(options.quality, 80);
        },
        optimize: (_) => fail('expected convert'),
        resize: (_) => fail('unexpected resize'),
        crop: (_) => fail('unexpected crop'),
        extend: (_) => fail('unexpected extend'),
      );
    });

    test('uses source image for lossless preview targets', () {
      final losslessPngPlan = buildOptimizationPlan(
        file: OpenedImageFile(
          path: '/tmp/photo.jpeg',
          metadata: ImageMetadata(
            width: 48,
            height: 32,
            format: 'jpeg',
            fileSize: BigInt.from(2000),
            hasTransparency: false,
          ),
        ),
        settings: const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.jpeg,
          quality: 80,
          storageDestinationMode: StorageDestinationMode.sameFolder,
          sameFolderAction: SameFolderAction.replaceSource,
          preserveFolderStructure: true,
          preserveOriginalDate: false,
          developerModeEnabled: false,
          timingLogsEnabled: false,
        ),
      );

      final losslessWebpPlan = buildOptimizationPlan(
        file: OpenedImageFile(
          path: '/tmp/photo.jpeg',
          metadata: ImageMetadata(
            width: 48,
            height: 32,
            format: 'jpeg',
            fileSize: BigInt.from(2000),
            hasTransparency: false,
          ),
        ),
        settings: const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: true,
          preferredCodec: PreferredCodec.webp,
          quality: 100,
          storageDestinationMode: StorageDestinationMode.sameFolder,
          sameFolderAction: SameFolderAction.replaceSource,
          preserveFolderStructure: true,
          preserveOriginalDate: false,
          developerModeEnabled: false,
          timingLogsEnabled: false,
        ),
      );

      expect(losslessPngPlan.useSourceImageForPreview, isTrue);
      expect(losslessWebpPlan.useSourceImageForPreview, isTrue);
    });

    test('keeps original by suffixing optimize output when same codec is kept', () {
      final plan = buildOptimizationPlan(
        file: OpenedImageFile(
          path: '/tmp/photo.jpg',
          metadata: ImageMetadata(
            width: 48,
            height: 32,
            format: 'jpeg',
            fileSize: BigInt.from(2000),
            hasTransparency: false,
          ),
        ),
        settings: const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.jpeg,
          quality: 80,
          storageDestinationMode: StorageDestinationMode.sameFolder,
          sameFolderAction: SameFolderAction.keepSource,
          preserveFolderStructure: true,
          preserveOriginalDate: false,
          developerModeEnabled: false,
          timingLogsEnabled: false,
        ),
      );

      expect(plan.processRequest.outputPath, isNull);
      expect(plan.processRequest.overwrite, isFalse);
      expect(plan.keepSourceEntry, isTrue);
      expect(plan.deleteSourceAfterSuccess, isFalse);
    });

    test('removes the original after a successful same-folder conversion', () {
      final plan = buildOptimizationPlan(
        file: OpenedImageFile(
          path: '/tmp/photo.png',
          metadata: ImageMetadata(
            width: 48,
            height: 32,
            format: 'png',
            fileSize: BigInt.from(3000),
            hasTransparency: false,
          ),
        ),
        settings: const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.jpeg,
          quality: 80,
          storageDestinationMode: StorageDestinationMode.sameFolder,
          sameFolderAction: SameFolderAction.replaceSource,
          preserveFolderStructure: true,
          preserveOriginalDate: false,
          developerModeEnabled: false,
          timingLogsEnabled: false,
        ),
      );

      expect(plan.processRequest.outputPath, '/tmp/photo.optimized.jpeg');
      expect(plan.processRequest.overwrite, isTrue);
      expect(plan.keepSourceEntry, isFalse);
      expect(plan.deleteSourceAfterSuccess, isTrue);
    });

    test('writes under the selected output root while preserving folder structure', () {
      final plan = buildOptimizationPlan(
        file: OpenedImageFile(
          path: '/tmp/input/animals/cat.png',
          metadata: ImageMetadata(
            width: 48,
            height: 32,
            format: 'png',
            fileSize: BigInt.from(3000),
            hasTransparency: false,
          ),
        ),
        settings: const AppSettings(
          compressionMethod: CompressionMethod.lossy,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.jpeg,
          quality: 80,
          storageDestinationMode: StorageDestinationMode.differentLocation,
          sameFolderAction: SameFolderAction.replaceSource,
          differentLocationPath: '/tmp/output',
          preserveFolderStructure: true,
          preserveOriginalDate: false,
          developerModeEnabled: false,
          timingLogsEnabled: false,
        ),
        sourceRootPath: '/tmp/input',
      );

      expect(
        plan.processRequest.outputPath,
        '/tmp/output/animals/cat.optimized.jpeg',
      );
      expect(plan.processRequest.overwrite, isTrue);
      expect(plan.keepSourceEntry, isTrue);
      expect(plan.deleteSourceAfterSuccess, isFalse);
    });
  });
}

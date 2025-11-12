import 'package:flutter_test/flutter_test.dart';
import 'package:eyeball_tracking/models/model_info.dart';

void main() {
  group('ModelInfo', () {
    test('creates instance with all required fields', () {
      final model = ModelInfo(
        id: 'test_model',
        name: 'test',
        displayName: 'Test Model',
        type: ModelType.yolo,
        variant: ModelVariant.medium,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path/to/model.onnx',
        sizeMB: 38.0,
        bundled: true,
        downloaded: true,
        accuracyRating: 0.85,
        speedRating: 0.75,
      );

      expect(model.id, 'test_model');
      expect(model.name, 'test');
      expect(model.displayName, 'Test Model');
      expect(model.type, ModelType.yolo);
      expect(model.variant, ModelVariant.medium);
      expect(model.format, ModelFormat.onnx);
      expect(model.platform, SupportedPlatform.all);
      expect(model.filePath, '/path/to/model.onnx');
      expect(model.sizeMB, 38.0);
      expect(model.bundled, true);
      expect(model.downloaded, true);
      expect(model.accuracyRating, 0.85);
      expect(model.speedRating, 0.75);
    });

    test('toJson and fromJson work correctly', () {
      final original = ModelInfo(
        id: 'yolo11m',
        name: 'yolo11m',
        displayName: 'YOLO11 Medium',
        type: ModelType.yolo,
        variant: ModelVariant.medium,
        format: ModelFormat.mlpackage,
        platform: SupportedPlatform.macos,
        filePath: 'yolo11m.mlpackage',
        sizeMB: 38.0,
        bundled: true,
        downloaded: true,
        isCustom: false,
        metadata: {'description': 'Test model', 'inputSize': '640x640'},
        accuracyRating: 0.88,
        speedRating: 0.75,
      );

      final json = original.toJson();
      final restored = ModelInfo.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.displayName, original.displayName);
      expect(restored.type, original.type);
      expect(restored.variant, original.variant);
      expect(restored.format, original.format);
      expect(restored.platform, original.platform);
      expect(restored.filePath, original.filePath);
      expect(restored.sizeMB, original.sizeMB);
      expect(restored.bundled, original.bundled);
      expect(restored.downloaded, original.downloaded);
      expect(restored.isCustom, original.isCustom);
      expect(restored.metadata, original.metadata);
      expect(restored.accuracyRating, original.accuracyRating);
      expect(restored.speedRating, original.speedRating);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = ModelInfo(
        id: 'test',
        name: 'test',
        displayName: 'Test',
        type: ModelType.yolo,
        variant: ModelVariant.nano,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 10.0,
        downloaded: false,
      );

      final updated = original.copyWith(
        downloaded: true,
        sizeMB: 12.0,
      );

      expect(updated.id, original.id);
      expect(updated.downloaded, true);
      expect(updated.sizeMB, 12.0);
      expect(updated.filePath, original.filePath);
    });

    test('performanceDescription returns correct descriptions', () {
      final excellentModel = ModelInfo(
        id: '1',
        name: 'excellent',
        displayName: 'Excellent',
        type: ModelType.yolo,
        variant: ModelVariant.medium,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 10.0,
        accuracyRating: 0.9,
        speedRating: 0.85,
      );
      expect(excellentModel.performanceDescription, 'Excellent (Fast & Accurate)');

      final fastModel = ModelInfo(
        id: '2',
        name: 'fast',
        displayName: 'Fast',
        type: ModelType.yolo,
        variant: ModelVariant.nano,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 5.0,
        accuracyRating: 0.6,
        speedRating: 0.95,
      );
      expect(fastModel.performanceDescription, 'Fast');

      final accurateModel = ModelInfo(
        id: '3',
        name: 'accurate',
        displayName: 'Accurate',
        type: ModelType.yolo,
        variant: ModelVariant.xlarge,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 100.0,
        accuracyRating: 0.95,
        speedRating: 0.4,
      );
      expect(accurateModel.performanceDescription, 'Accurate');

      final balancedModel = ModelInfo(
        id: '4',
        name: 'balanced',
        displayName: 'Balanced',
        type: ModelType.yolo,
        variant: ModelVariant.small,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 15.0,
        accuracyRating: 0.7,
        speedRating: 0.7,
      );
      expect(balancedModel.performanceDescription, 'Balanced');

      final basicModel = ModelInfo(
        id: '5',
        name: 'basic',
        displayName: 'Basic',
        type: ModelType.haar,
        variant: ModelVariant.standard,
        format: ModelFormat.xml,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 1.0,
        accuracyRating: 0.4,
        speedRating: 0.4,
      );
      expect(basicModel.performanceDescription, 'Basic');
    });

    test('variantDisplayName returns correct names', () {
      expect(
        ModelInfo(
          id: '1',
          name: 'test',
          displayName: 'Test',
          type: ModelType.yolo,
          variant: ModelVariant.nano,
          format: ModelFormat.onnx,
          platform: SupportedPlatform.all,
          filePath: '/path',
          sizeMB: 5.0,
        ).variantDisplayName,
        'Nano',
      );

      expect(
        ModelInfo(
          id: '2',
          name: 'test',
          displayName: 'Test',
          type: ModelType.yolo,
          variant: ModelVariant.xlarge,
          format: ModelFormat.onnx,
          platform: SupportedPlatform.all,
          filePath: '/path',
          sizeMB: 100.0,
        ).variantDisplayName,
        'X-Large',
      );

      expect(
        ModelInfo(
          id: '3',
          name: 'test',
          displayName: 'Test',
          type: ModelType.yunet,
          variant: ModelVariant.standard,
          format: ModelFormat.onnx,
          platform: SupportedPlatform.all,
          filePath: '/path',
          sizeMB: 0.5,
        ).variantDisplayName,
        '',
      );
    });

    test('fullDisplayName includes variant for non-standard models', () {
      final withVariant = ModelInfo(
        id: '1',
        name: 'yolo11m',
        displayName: 'YOLO11',
        type: ModelType.yolo,
        variant: ModelVariant.medium,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 38.0,
      );
      expect(withVariant.fullDisplayName, 'YOLO11 (Medium)');

      final noVariant = ModelInfo(
        id: '2',
        name: 'yunet',
        displayName: 'YuNet',
        type: ModelType.yunet,
        variant: ModelVariant.standard,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 0.5,
      );
      expect(noVariant.fullDisplayName, 'YuNet');
    });

    test('isAvailable returns true when bundled or downloaded', () {
      final bundled = ModelInfo(
        id: '1',
        name: 'test',
        displayName: 'Test',
        type: ModelType.yolo,
        variant: ModelVariant.medium,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 10.0,
        bundled: true,
        downloaded: false,
      );
      expect(bundled.isAvailable, true);

      final downloaded = ModelInfo(
        id: '2',
        name: 'test',
        displayName: 'Test',
        type: ModelType.yolo,
        variant: ModelVariant.medium,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 10.0,
        bundled: false,
        downloaded: true,
      );
      expect(downloaded.isAvailable, true);

      final notAvailable = ModelInfo(
        id: '3',
        name: 'test',
        displayName: 'Test',
        type: ModelType.yolo,
        variant: ModelVariant.medium,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 10.0,
        bundled: false,
        downloaded: false,
      );
      expect(notAvailable.isAvailable, false);
    });

    test('sizeString formats sizes correctly', () {
      final kbModel = ModelInfo(
        id: '1',
        name: 'small',
        displayName: 'Small',
        type: ModelType.haar,
        variant: ModelVariant.standard,
        format: ModelFormat.xml,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 0.5,
      );
      expect(kbModel.sizeString, '512 KB');

      final mbModel = ModelInfo(
        id: '2',
        name: 'medium',
        displayName: 'Medium',
        type: ModelType.yolo,
        variant: ModelVariant.medium,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 38.5,
      );
      expect(mbModel.sizeString, '38.5 MB');

      final gbModel = ModelInfo(
        id: '3',
        name: 'huge',
        displayName: 'Huge',
        type: ModelType.yolo,
        variant: ModelVariant.xlarge,
        format: ModelFormat.onnx,
        platform: SupportedPlatform.all,
        filePath: '/path',
        sizeMB: 1500.0,
      );
      expect(gbModel.sizeString, '1.46 GB');
    });
  });

  group('ModelType enum', () {
    test('has correct values', () {
      expect(ModelType.values.length, 4);
      expect(ModelType.yolo.name, 'yolo');
      expect(ModelType.yunet.name, 'yunet');
      expect(ModelType.haar.name, 'haar');
      expect(ModelType.mediaPipe.name, 'mediaPipe');
    });
  });

  group('ModelVariant enum', () {
    test('has correct values', () {
      expect(ModelVariant.values.length, 6);
      expect(ModelVariant.nano.name, 'nano');
      expect(ModelVariant.small.name, 'small');
      expect(ModelVariant.medium.name, 'medium');
      expect(ModelVariant.large.name, 'large');
      expect(ModelVariant.xlarge.name, 'xlarge');
      expect(ModelVariant.standard.name, 'standard');
    });
  });

  group('ModelFormat enum', () {
    test('has correct values', () {
      expect(ModelFormat.values.length, 4);
      expect(ModelFormat.onnx.name, 'onnx');
      expect(ModelFormat.mlpackage.name, 'mlpackage');
      expect(ModelFormat.tflite.name, 'tflite');
      expect(ModelFormat.xml.name, 'xml');
    });
  });

  group('SupportedPlatform enum', () {
    test('has correct values', () {
      expect(SupportedPlatform.values.length, 6);
      expect(SupportedPlatform.all.name, 'all');
      expect(SupportedPlatform.macos.name, 'macos');
      expect(SupportedPlatform.ios.name, 'ios');
      expect(SupportedPlatform.android.name, 'android');
      expect(SupportedPlatform.windows.name, 'windows');
      expect(SupportedPlatform.linux.name, 'linux');
    });
  });
}

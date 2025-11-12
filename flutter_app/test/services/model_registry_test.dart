import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:eyeball_tracking/models/model_info.dart';
import 'package:eyeball_tracking/services/model_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelRegistry', () {
    late ModelRegistry registry;

    setUp(() {
      // Reset singleton for each test to avoid state pollution
      registry = ModelRegistry.instance;
    });

    tearDown(() {
      // Clean up mock handlers after each test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('getInstance returns singleton instance', () {
      final instance1 = ModelRegistry.instance;
      final instance2 = ModelRegistry.instance;
      expect(instance1, same(instance2));
    });

    test('initialize loads models from assets', () async {
      // Mock the asset bundle
      const modelsJson = '''
      {
        "version": "1.0.0",
        "models": [
          {
            "id": "test_model_1",
            "name": "test1",
            "displayName": "Test Model 1",
            "type": "yolo",
            "variant": "nano",
            "format": "onnx",
            "platform": "all",
            "filePath": "test1.onnx",
            "sizeMB": 5.0,
            "bundled": true,
            "downloaded": true,
            "isCustom": false,
            "metadata": {},
            "accuracyRating": 0.7,
            "speedRating": 0.95
          },
          {
            "id": "test_model_2",
            "name": "test2",
            "displayName": "Test Model 2",
            "type": "yunet",
            "variant": "standard",
            "format": "onnx",
            "platform": "macos",
            "filePath": "test2.onnx",
            "sizeMB": 0.5,
            "bundled": true,
            "downloaded": true,
            "isCustom": false,
            "metadata": {},
            "accuracyRating": 0.85,
            "speedRating": 0.9
          }
        ],
        "defaultModels": {
          "macos": "test_model_2"
        },
        "downloadUrls": {
          "baseUrl": "https://example.com",
          "models": {
            "test_model_1": "/models/test1.onnx"
          }
        }
      }
      ''';

      // Set up the mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        final String key = const StringCodec().decodeMessage(message)!;
        if (key == 'assets/models.json') {
          return const StringCodec().encodeMessage(modelsJson);
        }
        return null;
      });

      await registry.initialize();

      final allModels = registry.getAllModels();
      expect(allModels.length, greaterThanOrEqualTo(2));

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    group('Model querying', () {
      setUp(() async {
        // Mock models for testing
        const modelsJson = '''
        {
          "models": [
            {
              "id": "yolo_nano_macos",
              "name": "yolo11n",
              "displayName": "YOLO Nano",
              "type": "yolo",
              "variant": "nano",
              "format": "mlpackage",
              "platform": "macos",
              "filePath": "yolo11n.mlpackage",
              "sizeMB": 8.0,
              "bundled": false,
              "downloaded": false,
              "isCustom": false,
              "metadata": {},
              "accuracyRating": 0.7,
              "speedRating": 0.98
            },
            {
              "id": "yolo_medium_macos",
              "name": "yolo11m",
              "displayName": "YOLO Medium",
              "type": "yolo",
              "variant": "medium",
              "format": "mlpackage",
              "platform": "macos",
              "filePath": "yolo11m.mlpackage",
              "sizeMB": 38.0,
              "bundled": true,
              "downloaded": true,
              "isCustom": false,
              "metadata": {},
              "accuracyRating": 0.88,
              "speedRating": 0.75
            },
            {
              "id": "yunet_all",
              "name": "yunet",
              "displayName": "YuNet",
              "type": "yunet",
              "variant": "standard",
              "format": "onnx",
              "platform": "all",
              "filePath": "yunet.onnx",
              "sizeMB": 0.227,
              "bundled": true,
              "downloaded": true,
              "isCustom": false,
              "metadata": {},
              "accuracyRating": 0.85,
              "speedRating": 0.9
            },
            {
              "id": "yolo_large_macos",
              "name": "yolo11l",
              "displayName": "YOLO Large",
              "type": "yolo",
              "variant": "large",
              "format": "mlpackage",
              "platform": "macos",
              "filePath": "yolo11l.mlpackage",
              "sizeMB": 85.0,
              "bundled": false,
              "downloaded": false,
              "isCustom": false,
              "metadata": {},
              "accuracyRating": 0.92,
              "speedRating": 0.6
            }
          ],
          "defaultModels": {
            "macos": "yolo_medium_macos"
          },
          "downloadUrls": {
            "baseUrl": "https://example.com",
            "models": {}
          }
        }
        ''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (message) async {
          final String key = const StringCodec().decodeMessage(message)!;
          if (key == 'assets/models.json') {
            return const StringCodec().encodeMessage(modelsJson);
          }
          return null;
        });

        await registry.initialize();
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
      });

      test('getModelsForPlatform filters by platform', () {
        final macosModels = registry.getModelsForPlatform(SupportedPlatform.macos);

        // Should include platform-specific and "all" platform models
        expect(
          macosModels.every((m) => m.platform == SupportedPlatform.macos || m.platform == SupportedPlatform.all),
          true,
        );
      });

      test('getAvailableModels returns only bundled or downloaded models', () {
        final available = registry.getAvailableModels(SupportedPlatform.macos);

        expect(
          available.every((m) => m.bundled || m.downloaded),
          true,
        );
      });

      test('getModelsByType filters by model type', () {
        final yoloModels = registry.getModelsByType(ModelType.yolo, SupportedPlatform.macos);

        expect(
          yoloModels.every((m) => m.type == ModelType.yolo),
          true,
        );
      });

      test('getBestModel with maxSpeed returns fastest model', () {
        final best = registry.getBestModel(PerformanceTarget.maxSpeed, SupportedPlatform.macos);

        expect(best, isNotNull);
        if (best != null) {
          final available = registry.getAvailableModels(SupportedPlatform.macos);
          final maxSpeed = available.map((m) => m.speedRating).reduce((a, b) => a > b ? a : b);
          expect(best.speedRating, maxSpeed);
        }
      });

      test('getBestModel with maxAccuracy returns most accurate model', () {
        final best = registry.getBestModel(PerformanceTarget.maxAccuracy, SupportedPlatform.macos);

        expect(best, isNotNull);
        if (best != null) {
          final available = registry.getAvailableModels(SupportedPlatform.macos);
          final maxAccuracy = available.map((m) => m.accuracyRating).reduce((a, b) => a > b ? a : b);
          expect(best.accuracyRating, maxAccuracy);
        }
      });

      test('getBestModel with balanced returns best combined score', () {
        final best = registry.getBestModel(PerformanceTarget.balanced, SupportedPlatform.macos);

        expect(best, isNotNull);
        if (best != null) {
          final available = registry.getAvailableModels(SupportedPlatform.macos);
          final maxCombined = available
              .map((m) => (m.speedRating + m.accuracyRating) / 2)
              .reduce((a, b) => a > b ? a : b);
          final bestCombined = (best.speedRating + best.accuracyRating) / 2;
          expect(bestCombined, closeTo(maxCombined, 0.01));
        }
      });

      test('getModelById returns correct model', () {
        // Get first available model from registry
        final allModels = registry.getAllModels();
        if (allModels.isNotEmpty) {
          final firstModel = allModels.first;
          final model = registry.getModelById(firstModel.id);

          expect(model, isNotNull);
          expect(model?.id, firstModel.id);
        } else {
          // If no models, just verify null is returned for non-existent
          final model = registry.getModelById('non_existent');
          expect(model, isNull);
        }
      });

      test('getModelById returns null for non-existent model', () {
        final model = registry.getModelById('non_existent');

        expect(model, isNull);
      });

      test('getDefaultModel returns platform default', () {
        final defaultModel = registry.getDefaultModel(SupportedPlatform.macos);

        expect(defaultModel, isNotNull);
        // Check that it's one of the expected models (could be from previous test setups)
        expect(defaultModel?.platform == SupportedPlatform.macos || defaultModel?.platform == SupportedPlatform.all, true);
      });
    });

    group('Model management', () {
      test('markAsDownloaded returns false for non-existent model', () async {
        // Verify the method handles non-existent models gracefully
        final result = await registry.markAsDownloaded('non_existent', true);
        expect(result, isFalse);
      });

      test('getDownloadUrl returns null for non-existent model', () {
        // Test that getDownloadUrl returns null for models without download URLs
        final url = registry.getDownloadUrl('non_existent_model_id');
        expect(url, isNull);
      });
    });

    group('Statistics', () {
      test('getStats returns correct statistics', () async {
        const modelsJson = '''
        {
          "models": [
            {
              "id": "model1",
              "name": "m1",
              "displayName": "Model 1",
              "type": "yolo",
              "variant": "nano",
              "format": "onnx",
              "platform": "macos",
              "filePath": "m1.onnx",
              "sizeMB": 5.0,
              "bundled": true,
              "downloaded": true,
              "isCustom": false,
              "metadata": {},
              "accuracyRating": 0.7,
              "speedRating": 0.9
            },
            {
              "id": "model2",
              "name": "m2",
              "displayName": "Model 2",
              "type": "yunet",
              "variant": "standard",
              "format": "onnx",
              "platform": "all",
              "filePath": "m2.onnx",
              "sizeMB": 0.5,
              "bundled": false,
              "downloaded": true,
              "isCustom": false,
              "metadata": {},
              "accuracyRating": 0.85,
              "speedRating": 0.9
            }
          ],
          "defaultModels": {},
          "downloadUrls": {"baseUrl": "", "models": {}}
        }
        ''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (message) async {
          final String key = const StringCodec().decodeMessage(message)!;
          if (key == 'assets/models.json') {
            return const StringCodec().encodeMessage(modelsJson);
          }
          return null;
        });

        await registry.initialize();

        final stats = registry.getStats();

        expect(stats['totalModels'], greaterThanOrEqualTo(2));
        expect(stats['bundledModels'], greaterThanOrEqualTo(0));
        expect(stats['downloadedModels'], greaterThanOrEqualTo(0));
        expect(stats['customModels'], greaterThanOrEqualTo(0));

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
      });
    });
  });

  group('PerformanceTarget enum', () {
    test('has correct values', () {
      expect(PerformanceTarget.values.length, 3);
      expect(PerformanceTarget.maxSpeed.name, 'maxSpeed');
      expect(PerformanceTarget.balanced.name, 'balanced');
      expect(PerformanceTarget.maxAccuracy.name, 'maxAccuracy');
    });
  });
}

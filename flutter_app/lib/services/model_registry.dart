import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/model_info.dart';

enum PerformanceTarget {
  maxSpeed,      // Prioritize speed over accuracy
  balanced,      // Balance between speed and accuracy
  maxAccuracy,   // Prioritize accuracy over speed
}

class ModelRegistry {
  static ModelRegistry? _instance;
  static Database? _database;

  List<ModelInfo> _models = [];
  Map<String, String> _defaultModels = {};
  Map<String, String> _downloadUrls = {};
  String _baseDownloadUrl = '';

  ModelRegistry._();

  static ModelRegistry get instance {
    _instance ??= ModelRegistry._();
    return _instance!;
  }

  /// Initialize the model registry
  Future<void> initialize({Database? database}) async {
    _database = database;
    await _loadModelsFromAsset();
    if (_database != null) {
      await _loadCustomModels();
    }
  }

  /// Load models from assets/models.json
  Future<void> _loadModelsFromAsset() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/models.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      // Parse models
      final List<dynamic> modelsJson = data['models'] ?? [];
      _models = modelsJson.map((m) => ModelInfo.fromJson(m)).toList();

      // Parse default models
      final Map<String, dynamic> defaults = data['defaultModels'] ?? {};
      _defaultModels = defaults.map((key, value) => MapEntry(key, value.toString()));

      // Parse download URLs
      final Map<String, dynamic> downloadConfig = data['downloadUrls'] ?? {};
      _baseDownloadUrl = downloadConfig['baseUrl'] ?? '';
      final Map<String, dynamic> urls = downloadConfig['models'] ?? {};
      _downloadUrls = urls.map((key, value) => MapEntry(key, value.toString()));

    } catch (e) {
      print('Error loading models.json: $e');
      _models = [];
    }
  }

  /// Load custom models from database
  Future<void> _loadCustomModels() async {
    if (_database == null) return;

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'models',
        where: 'isCustom = ?',
        whereArgs: [1],
      );

      for (final map in maps) {
        final model = ModelInfo.fromJson({
          'id': map['id'],
          'name': map['name'],
          'displayName': map['displayName'],
          'type': map['type'],
          'variant': map['variant'],
          'format': map['format'],
          'platform': map['platform'],
          'filePath': map['filePath'],
          'sizeMB': map['sizeMB'],
          'bundled': false,
          'downloaded': map['downloaded'] == 1,
          'isCustom': true,
          'addedByAdminId': map['addedByAdminId'],
          'metadata': json.decode(map['metadata'] ?? '{}'),
          'accuracyRating': map['accuracyRating'] ?? 0.5,
          'speedRating': map['speedRating'] ?? 0.5,
        });

        // Add if not already in list
        if (!_models.any((m) => m.id == model.id)) {
          _models.add(model);
        }
      }
    } catch (e) {
      print('Error loading custom models from database: $e');
    }
  }

  /// Get all models
  List<ModelInfo> getAllModels() => List.unmodifiable(_models);

  /// Get models for current platform
  List<ModelInfo> getModelsForPlatform([SupportedPlatform? platform]) {
    platform ??= _getCurrentPlatform();
    return _models.where((m) =>
      m.platform == SupportedPlatform.all || m.platform == platform
    ).toList();
  }

  /// Get available models (bundled or downloaded) for platform
  List<ModelInfo> getAvailableModels([SupportedPlatform? platform]) {
    return getModelsForPlatform(platform).where((m) => m.isAvailable).toList();
  }

  /// Get models by type
  List<ModelInfo> getModelsByType(ModelType type, [SupportedPlatform? platform]) {
    return getModelsForPlatform(platform).where((m) => m.type == type).toList();
  }

  /// Get best model for given criteria
  ModelInfo? getBestModel(PerformanceTarget target, [SupportedPlatform? platform]) {
    final available = getAvailableModels(platform);
    if (available.isEmpty) return null;

    switch (target) {
      case PerformanceTarget.maxSpeed:
        available.sort((a, b) => b.speedRating.compareTo(a.speedRating));
        return available.first;

      case PerformanceTarget.maxAccuracy:
        available.sort((a, b) => b.accuracyRating.compareTo(a.accuracyRating));
        return available.first;

      case PerformanceTarget.balanced:
        // Balanced: prefer models with highest combined score
        available.sort((a, b) {
          final scoreA = (a.speedRating + a.accuracyRating) / 2;
          final scoreB = (b.speedRating + b.accuracyRating) / 2;
          return scoreB.compareTo(scoreA);
        });
        return available.first;
    }
  }

  /// Get model by ID
  ModelInfo? getModelById(String id) {
    try {
      return _models.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get default model for platform
  ModelInfo? getDefaultModel([SupportedPlatform? platform]) {
    platform ??= _getCurrentPlatform();
    final defaultId = _defaultModels[platform.name];
    if (defaultId == null) return null;
    return getModelById(defaultId);
  }

  /// Add custom model (admin only)
  Future<bool> addCustomModel(ModelInfo model) async {
    if (_database == null) return false;

    try {
      await _database!.insert('models', {
        'id': model.id,
        'name': model.name,
        'displayName': model.displayName,
        'type': model.type.name,
        'variant': model.variant.name,
        'format': model.format.name,
        'platform': model.platform.name,
        'filePath': model.filePath,
        'sizeMB': model.sizeMB,
        'downloaded': model.downloaded ? 1 : 0,
        'addedByAdminId': model.addedByAdminId,
        'metadata': json.encode(model.metadata),
        'accuracyRating': model.accuracyRating,
        'speedRating': model.speedRating,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Add to in-memory list
      final existingIndex = _models.indexWhere((m) => m.id == model.id);
      if (existingIndex >= 0) {
        _models[existingIndex] = model;
      } else {
        _models.add(model);
      }

      return true;
    } catch (e) {
      print('Error adding custom model: $e');
      return false;
    }
  }

  /// Remove custom model (admin only)
  Future<bool> removeCustomModel(String modelId) async {
    if (_database == null) return false;

    final model = getModelById(modelId);
    if (model == null || !model.isCustom) return false;

    try {
      await _database!.delete('models', where: 'id = ?', whereArgs: [modelId]);

      // Remove from in-memory list
      _models.removeWhere((m) => m.id == modelId);

      // Delete model file if it exists
      final file = File(model.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      return true;
    } catch (e) {
      print('Error removing custom model: $e');
      return false;
    }
  }

  /// Mark model as downloaded
  Future<bool> markAsDownloaded(String modelId, bool downloaded) async {
    final model = getModelById(modelId);
    if (model == null) return false;

    final updated = model.copyWith(downloaded: downloaded);

    if (_database != null && model.isCustom) {
      try {
        await _database!.update(
          'models',
          {'downloaded': downloaded ? 1 : 0},
          where: 'id = ?',
          whereArgs: [modelId],
        );
      } catch (e) {
        print('Error updating model download status: $e');
      }
    }

    // Update in-memory list
    final index = _models.indexWhere((m) => m.id == modelId);
    if (index >= 0) {
      _models[index] = updated;
    }

    return true;
  }

  /// Get download URL for model
  String? getDownloadUrl(String modelId) {
    final relativePath = _downloadUrls[modelId];
    if (relativePath == null) return null;
    return _baseDownloadUrl + relativePath;
  }

  /// Check if model file exists locally
  Future<bool> isModelFileAvailable(ModelInfo model) async {
    try {
      final file = File(model.filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get current platform
  SupportedPlatform _getCurrentPlatform() {
    if (Platform.isMacOS) return SupportedPlatform.macos;
    if (Platform.isIOS) return SupportedPlatform.ios;
    if (Platform.isAndroid) return SupportedPlatform.android;
    if (Platform.isWindows) return SupportedPlatform.windows;
    if (Platform.isLinux) return SupportedPlatform.linux;
    return SupportedPlatform.all;
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    final platform = _getCurrentPlatform();
    final platformModels = getModelsForPlatform(platform);
    final available = platformModels.where((m) => m.isAvailable).length;
    final custom = _models.where((m) => m.isCustom).length;

    return {
      'totalModels': _models.length,
      'platformModels': platformModels.length,
      'availableModels': available,
      'customModels': custom,
      'bundledModels': _models.where((m) => m.bundled).length,
      'downloadedModels': _models.where((m) => m.downloaded && !m.bundled).length,
    };
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calibration_data.dart';
import '../models/calibration_profile.dart';

/// Service for managing calibration profiles including creation, persistence,
/// and application of tracking corrections.
class CalibrationService extends ChangeNotifier {
  static const String _profileKeyPrefix = 'calibration_profile_';
  static const String _activeProfileKey = 'active_calibration_profile';

  CalibrationProfile? _activeProfile;
  final Map<String, CalibrationProfile> _profiles = {};

  CalibrationProfile? get activeProfile => _activeProfile;
  List<CalibrationProfile> get allProfiles => _profiles.values.toList();

  /// Initializes the service and loads saved profiles
  Future<void> initialize() async {
    await _loadProfiles();
    await _loadActiveProfile();
  }

  /// Creates a new calibration profile from a completed session
  Future<CalibrationProfile> createProfile(CalibrationSession session) async {
    final profile = CalibrationProfile.fromSession(session);

    _profiles[profile.id] = profile;
    await _saveProfile(profile);

    // Auto-activate if it's the first profile or better than current
    if (_activeProfile == null || profile.qualityScore > _activeProfile!.qualityScore) {
      await setActiveProfile(profile.id);
    }

    notifyListeners();
    return profile;
  }

  /// Sets the active calibration profile
  Future<void> setActiveProfile(String profileId) async {
    final profile = _profiles[profileId];
    if (profile == null) {
      throw Exception('Profile not found: $profileId');
    }

    if (!profile.isValid) {
      throw Exception('Cannot activate invalid profile (quality: ${profile.qualityScore})');
    }

    _activeProfile = profile;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profileId);

    notifyListeners();
  }

  /// Deletes a calibration profile
  Future<void> deleteProfile(String profileId) async {
    _profiles.remove(profileId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_profileKeyPrefix$profileId');

    // Clear active profile if it was deleted
    if (_activeProfile?.id == profileId) {
      _activeProfile = null;
      await prefs.remove(_activeProfileKey);
    }

    notifyListeners();
  }

  /// Gets a profile by ID
  CalibrationProfile? getProfile(String profileId) {
    return _profiles[profileId];
  }

  /// Gets all profiles for a specific user
  List<CalibrationProfile> getProfilesForUser(String userId) {
    return _profiles.values
        .where((profile) => profile.userId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
  }

  /// Applies calibration correction to raw tracking result
  ///
  /// NOTE: This is a simplified implementation. Future phases will implement:
  /// - Polynomial gaze offset correction
  /// - Homography-based eye-to-screen mapping
  /// - Confidence-weighted corrections
  ExtendedTrackingResult applyCorrection(ExtendedTrackingResult raw) {
    if (_activeProfile == null) {
      return raw; // No correction without active profile
    }

    // Apply simple head pose baseline normalization
    final correctedHeadPose = Vector3(
      raw.headPose.x - _activeProfile!.headPoseBaseline.x,
      raw.headPose.y - _activeProfile!.headPoseBaseline.y,
      raw.headPose.z - _activeProfile!.headPoseBaseline.z,
    );

    // Apply simple gaze offset correction
    final offsetX = _activeProfile!.gazeOffsets['offsetX'] ?? 0.0;
    final offsetY = _activeProfile!.gazeOffsets['offsetY'] ?? 0.0;

    final correctedGazeVector = Vector3(
      raw.gazeVector.x - offsetX,
      raw.gazeVector.y - offsetY,
      raw.gazeVector.z,
    );

    // Create corrected result
    return ExtendedTrackingResult(
      faceDistance: raw.faceDistance,
      gazeAngleX: raw.gazeAngleX,
      gazeAngleY: raw.gazeAngleY,
      eyesFocused: raw.eyesFocused,
      headMoving: raw.headMoving,
      shouldersMoving: raw.shouldersMoving,
      faceDetected: raw.faceDetected,
      faceRect: raw.faceRect,
      faceLandmarks: raw.faceLandmarks,
      leftEyeLandmarks: raw.leftEyeLandmarks,
      rightEyeLandmarks: raw.rightEyeLandmarks,
      headPose: correctedHeadPose,
      gazeVector: correctedGazeVector,
      shoulderLandmarks: raw.shoulderLandmarks,
      confidence: raw.confidence,
    );
  }

  /// Determines if recalibration is recommended
  bool shouldRecalibrate() {
    if (_activeProfile == null) return true;

    // Recommend recalibration if:
    // 1. Profile is older than 30 days
    final daysSinceCalibration = DateTime.now().difference(_activeProfile!.createdAt).inDays;
    if (daysSinceCalibration > 30) return true;

    // 2. Quality score is below "Good" threshold
    if (_activeProfile!.qualityScore < 60) return true;

    return false;
  }

  /// Clears all calibration data (for testing or reset)
  Future<void> clearAllProfiles() async {
    _profiles.clear();
    _activeProfile = null;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_profileKeyPrefix) || key == _activeProfileKey) {
        await prefs.remove(key);
      }
    }

    notifyListeners();
  }

  // Private helper methods

  Future<void> _saveProfile(CalibrationProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(profile.toJson());
    await prefs.setString('$_profileKeyPrefix${profile.id}', json);
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_profileKeyPrefix)) {
        try {
          final jsonString = prefs.getString(key);
          if (jsonString != null) {
            final json = jsonDecode(jsonString) as Map<String, dynamic>;
            final profile = CalibrationProfile.fromJson(json);
            _profiles[profile.id] = profile;
          }
        } catch (e) {
          // Ignore corrupted profiles
          debugPrint('Failed to load profile $key: $e');
        }
      }
    }
  }

  Future<void> _loadActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final activeProfileId = prefs.getString(_activeProfileKey);

    if (activeProfileId != null && _profiles.containsKey(activeProfileId)) {
      _activeProfile = _profiles[activeProfileId];
    }
  }
}

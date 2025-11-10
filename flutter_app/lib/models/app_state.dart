import 'package:flutter/foundation.dart';

enum UserRole { user, admin }

class User {
  final String id;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      role: UserRole.values.firstWhere((e) => e.toString() == 'UserRole.${json['role']}'),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

enum TestType { random, horizontal, vertical }

class TestConfiguration {
  final Duration duration;
  final TestType type;
  final double circleSize;
  final int movementSpeed;

  const TestConfiguration({
    this.duration = const Duration(minutes: 1),
    this.type = TestType.random,
    this.circleSize = 50.0,
    this.movementSpeed = 2,
  });

  Map<String, dynamic> toJson() {
    return {
      'duration': duration.inMilliseconds,
      'type': type.toString().split('.').last,
      'circleSize': circleSize,
      'movementSpeed': movementSpeed,
    };
  }

  factory TestConfiguration.fromJson(Map<String, dynamic> json) {
    return TestConfiguration(
      duration: Duration(milliseconds: json['duration']),
      type: TestType.values.firstWhere((e) => e.toString() == 'TestType.${json['type']}'),
      circleSize: json['circleSize'],
      movementSpeed: json['movementSpeed'],
    );
  }
}

class TrackingData {
  final DateTime timestamp;
  final double faceDistance;
  final double gazeX;
  final double gazeY;
  final bool eyesFocused;
  final bool headMoving;
  final bool shouldersMoving;
  final double targetX;
  final double targetY;

  TrackingData({
    required this.timestamp,
    required this.faceDistance,
    required this.gazeX,
    required this.gazeY,
    required this.eyesFocused,
    required this.headMoving,
    required this.shouldersMoving,
    required this.targetX,
    required this.targetY,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'faceDistance': faceDistance,
      'gazeX': gazeX,
      'gazeY': gazeY,
      'eyesFocused': eyesFocused,
      'headMoving': headMoving,
      'shouldersMoving': shouldersMoving,
      'targetX': targetX,
      'targetY': targetY,
    };
  }

  factory TrackingData.fromJson(Map<String, dynamic> json) {
    return TrackingData(
      timestamp: DateTime.parse(json['timestamp']),
      faceDistance: json['faceDistance'],
      gazeX: json['gazeX'],
      gazeY: json['gazeY'],
      eyesFocused: json['eyesFocused'],
      headMoving: json['headMoving'],
      shouldersMoving: json['shouldersMoving'],
      targetX: json['targetX'],
      targetY: json['targetY'],
    );
  }
}

class TestSession {
  final String id;
  final String userId;
  final TestConfiguration config;
  final DateTime startTime;
  final List<TrackingData> dataPoints;

  TestSession({
    required this.id,
    required this.userId,
    required this.config,
    required this.startTime,
    this.dataPoints = const [],
  });

  void addDataPoint(TrackingData data) {
    dataPoints.add(data);
  }

  TestResults calculateResults() {
    if (dataPoints.isEmpty) {
      return TestResults(
        accuracy: 0.0,
        reactionTime: 0.0,
        movementAnalysis: {},
        overallAssessment: 'No data collected',
      );
    }

    // Calculate accuracy based on gaze vs target position
    int correctGazes = dataPoints.where((point) {
      final distance = _calculateDistance(point.gazeX, point.gazeY, point.targetX, point.targetY);
      return distance < 0.1; // Within 10% of screen considered correct
    }).length;

    final accuracy = correctGazes / dataPoints.length;

    // Calculate average reaction time (simplified)
    final reactionTime = dataPoints.length > 1 
        ? dataPoints.last.timestamp.difference(dataPoints.first.timestamp).inMilliseconds / dataPoints.length
        : 0.0;

    // Movement analysis
    final movementAnalysis = {
      'headMovementCount': dataPoints.where((point) => point.headMoving).length,
      'shoulderMovementCount': dataPoints.where((point) => point.shouldersMoving).length,
      'totalDataPoints': dataPoints.length,
    };

    // Overall assessment
    String overallAssessment;
    if (accuracy > 0.8) {
      overallAssessment = 'Excellent tracking accuracy';
    } else if (accuracy > 0.6) {
      overallAssessment = 'Good tracking performance';
    } else if (accuracy > 0.4) {
      overallAssessment = 'Average tracking performance';
    } else {
      overallAssessment = 'Needs improvement';
    }

    return TestResults(
      accuracy: accuracy,
      reactionTime: reactionTime,
      movementAnalysis: movementAnalysis,
      overallAssessment: overallAssessment,
    );
  }

  double _calculateDistance(double x1, double y1, double x2, double y2) {
    return ((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'config': config.toJson(),
      'startTime': startTime.toIso8601String(),
      'dataPoints': dataPoints.map((point) => point.toJson()).toList(),
    };
  }

  factory TestSession.fromJson(Map<String, dynamic> json) {
    return TestSession(
      id: json['id'],
      userId: json['userId'],
      config: TestConfiguration.fromJson(json['config']),
      startTime: DateTime.parse(json['startTime']),
      dataPoints: (json['dataPoints'] as List)
          .map((point) => TrackingData.fromJson(point))
          .toList(),
    );
  }
}

class TestResults {
  final double accuracy;
  final double reactionTime;
  final Map<String, dynamic> movementAnalysis;
  final String overallAssessment;

  TestResults({
    required this.accuracy,
    required this.reactionTime,
    required this.movementAnalysis,
    required this.overallAssessment,
  });

  Map<String, dynamic> toJson() {
    return {
      'accuracy': accuracy,
      'reactionTime': reactionTime,
      'movementAnalysis': movementAnalysis,
      'overallAssessment': overallAssessment,
    };
  }
}

class AppSettings {
  final bool useCloudStorage;
  final bool enableAnalytics;
  final double processingQuality;

  const AppSettings({
    this.useCloudStorage = false,
    this.enableAnalytics = true,
    this.processingQuality = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'useCloudStorage': useCloudStorage,
      'enableAnalytics': enableAnalytics,
      'processingQuality': processingQuality,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      useCloudStorage: json['useCloudStorage'] ?? false,
      enableAnalytics: json['enableAnalytics'] ?? true,
      processingQuality: json['processingQuality'] ?? 1.0,
    );
  }
}

class AppState with ChangeNotifier {
  User? _currentUser;
  TestSession? _currentSession;
  AppSettings _settings = const AppSettings();
  bool _isTracking = false;

  User? get currentUser => _currentUser;
  TestSession? get currentSession => _currentSession;
  AppSettings get settings => _settings;
  bool get isTracking => _isTracking;

  void setUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  void startTestSession(TestConfiguration config) {
    _currentSession = TestSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _currentUser?.id ?? 'anonymous',
      config: config,
      startTime: DateTime.now(),
    );
    _isTracking = true;
    notifyListeners();
  }

  void stopTestSession() {
    _isTracking = false;
    notifyListeners();
  }

  void updateTrackingData(TrackingData data) {
    _currentSession?.addDataPoint(data);
    notifyListeners();
  }

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
  }
}

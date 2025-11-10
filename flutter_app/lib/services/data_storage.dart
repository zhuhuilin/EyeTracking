import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/app_state.dart';

abstract class DataStorage {
  Future<void> initialize();
  Future<void> saveTestSession(TestSession session);
  Future<List<TestSession>> getUserSessions(String userId);
  Future<List<TestSession>> getAllSessions();
  Future<void> deleteSession(String sessionId);
  Future<void> migrateToCloud();
  Future<void> migrateToLocal();
  Future<Map<String, dynamic>> getStorageStats();
}

class LocalStorage implements DataStorage {
  static Database? _database;
  static const String _databaseName = 'eyeball_tracking.db';
  static const int _databaseVersion = 1;

  @override
  Future<void> initialize() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), _databaseName),
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE sessions(
            id TEXT PRIMARY KEY,
            userId TEXT,
            config TEXT,
            startTime TEXT,
            dataPoints TEXT
          )
          ''');
      },
      version: _databaseVersion,
    );
  }

  @override
  Future<void> saveTestSession(TestSession session) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    await db.insert('sessions', {
      'id': session.id,
      'userId': session.userId,
      'config': jsonEncode(session.config.toJson()),
      'startTime': session.startTime.toIso8601String(),
      'dataPoints': jsonEncode(
        session.dataPoints.map((e) => e.toJson()).toList(),
      ),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<TestSession>> getUserSessions(String userId) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'startTime DESC',
    );

    return maps
        .map(
          (map) => TestSession.fromJson({
            'id': map['id'],
            'userId': map['userId'],
            'config': jsonDecode(map['config']),
            'startTime': map['startTime'],
            'dataPoints': jsonDecode(map['dataPoints']),
          }),
        )
        .toList();
  }

  @override
  Future<List<TestSession>> getAllSessions() async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      orderBy: 'startTime DESC',
    );

    return maps
        .map(
          (map) => TestSession.fromJson({
            'id': map['id'],
            'userId': map['userId'],
            'config': jsonDecode(map['config']),
            'startTime': map['startTime'],
            'dataPoints': jsonDecode(map['dataPoints']),
          }),
        )
        .toList();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  @override
  Future<void> migrateToCloud() async {
    // Export all local data for cloud migration
    final sessions = await getAllSessions();
    final cloudStorage = CloudStorage();
    await cloudStorage.initialize();

    for (final session in sessions) {
      await cloudStorage.saveTestSession(session);
    }

    // Update storage preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCloudStorage', true);
  }

  @override
  Future<void> migrateToLocal() async {
    // Import cloud data to local storage
    final cloudStorage = CloudStorage();
    await cloudStorage.initialize();
    final sessions = await cloudStorage.getAllSessions();

    for (final session in sessions) {
      await saveTestSession(session);
    }

    // Update storage preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCloudStorage', false);
  }

  @override
  Future<Map<String, dynamic>> getStorageStats() async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    final sessionsCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sessions'),
        ) ??
        0;

    final users = await db.rawQuery('SELECT DISTINCT userId FROM sessions');

    return {
      'totalSessions': sessionsCount,
      'totalUsers': users.length,
      'storageType': 'local',
      'sizeEstimate': '${sessionsCount * 2} KB', // Rough estimate
    };
  }
}

class CloudStorage implements DataStorage {
  static const String _baseUrl =
      'https://api.eyeballtracking.com'; // Example URL
  String? _authToken;

  @override
  Future<void> initialize() async {
    // Initialize cloud storage connection
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('authToken');

    // In a real implementation, we would validate the token
    // and refresh it if necessary
  }

  Future<Map<String, String>> _getHeaders() async {
    if (_authToken == null) {
      await initialize();
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_authToken',
    };
  }

  @override
  Future<void> saveTestSession(TestSession session) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/sessions'),
      headers: headers,
      body: jsonEncode(session.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save session to cloud: ${response.body}');
    }
  }

  @override
  Future<List<TestSession>> getUserSessions(String userId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/sessions?userId=$userId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => TestSession.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load user sessions: ${response.body}');
    }
  }

  @override
  Future<List<TestSession>> getAllSessions() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/sessions'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => TestSession.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load all sessions: ${response.body}');
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/sessions/$sessionId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete session: ${response.body}');
    }
  }

  @override
  Future<void> migrateToCloud() async {
    // Already in cloud, no migration needed
    return;
  }

  @override
  Future<void> migrateToLocal() async {
    // Export cloud data to local storage
    final localStorage = LocalStorage();
    await localStorage.initialize();
    final sessions = await getAllSessions();

    for (final session in sessions) {
      await localStorage.saveTestSession(session);
    }

    // Update storage preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCloudStorage', false);
  }

  @override
  Future<Map<String, dynamic>> getStorageStats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/stats'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        'totalSessions': 0,
        'totalUsers': 0,
        'storageType': 'cloud',
        'sizeEstimate': 'Unknown',
      };
    }
  }
}

class StorageManager {
  static DataStorage? _currentStorage;
  static bool _useCloudStorage = false;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _useCloudStorage = prefs.getBool('useCloudStorage') ?? false;

    _currentStorage = _useCloudStorage ? CloudStorage() : LocalStorage();
    await _currentStorage!.initialize();
  }

  static DataStorage get currentStorage {
    if (_currentStorage == null) {
      throw Exception('StorageManager not initialized');
    }
    return _currentStorage!;
  }

  static Future<void> switchStorage(bool useCloud) async {
    if (useCloud == _useCloudStorage) return;

    if (useCloud) {
      // Migrate from local to cloud
      await LocalStorage().migrateToCloud();
    } else {
      // Migrate from cloud to local
      await CloudStorage().migrateToLocal();
    }

    _useCloudStorage = useCloud;
    _currentStorage = useCloud ? CloudStorage() : LocalStorage();
    await _currentStorage!.initialize();

    // Update preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCloudStorage', useCloud);
  }

  static bool get isUsingCloud => _useCloudStorage;
}

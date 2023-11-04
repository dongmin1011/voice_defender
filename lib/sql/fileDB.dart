import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:voice_defender/sql/file.dart';

class FileDB {
  final tableName = 'files';
  late Database _database;

  Future<Database?> get database async {
    _database = await initDB();

    return _database;
  }

  initDB() async {
    String path = join(await getDatabasesPath(), 'file.db');
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute("""
CREATE TABLE IF NOT EXISTS $tableName (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  filename TEXT NOT NULL,
  created_at TEXT NOT NULL,
  is_phising BOOLEAN NOT NULL,
  confidence REAL NOT NULL,
  text TEXT NOT NULL,
  is_deep_voice BOOLEAN NOT NULL,
  deep_voice_confidence REAL NOT NULL,
  reasons TEXT
);
""");
    }, onUpgrade: (db, oldVersion, newVersion) {});
  }

  Future<List<Map<String, dynamic>>?> selectAll() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(tableName);

    final List<Map<String, dynamic>> processedData = maps.map((map) {
      // "reasons" 필드를 JSON 문자열로 파싱
      final reasonsJson = map['reasons'];
      final List<dynamic> reasonsList =
          reasonsJson != null ? jsonDecode(reasonsJson) : [];

      // "reasons" 필드를 리스트로 변환하여 맵에 추가
      final Map<String, dynamic> processedMap = {
        ...map,
        "reasons": reasonsList,
      };

      return processedMap;
    }).toList();

    return processedData;
  }

  Future<Map<String, dynamic>?> selectById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db!.query(tableName, where: 'id = ?', whereArgs: [id]);

    if (maps.isEmpty) return null;

    final map = maps.first;

    // "reasons" 필드를 JSON 문자열로 파싱
    final reasonsJson = map['reasons'];
    final List<dynamic> reasonsList =
        reasonsJson != null ? jsonDecode(reasonsJson) : [];

    final Map<String, dynamic> phisingResult = {
      "id": map["id"],
      'filename': map["filename"],
      'created_at': map["created_at"],
      "phising_result": {
        "is_phising": map["is_phising"],
        "confidence": map["confidence"],
        "reasons": reasonsList, // "reasons" 리스트 추가
        "text": map['text'],
        "deep_voice_result": {
          "is_deep_voice": map["is_deep_voice"],
          "deep_voice_confidence": map["deep_voice_confidence"],
        }
      }
    };

    return phisingResult;
  }

  Future<void> insert(File_table file) async {
    final db = await database;
    file.id = await db?.insert(tableName, file.toMap());
  }

  Future<void> delete(File_table file) async {
    final db = await database;
    await db?.delete(
      tableName,
      where: "id = ?",
      whereArgs: [file.id],
    );
  }
}

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
    final List<Map<String, dynamic>> maps =
        await db!.query(tableName, orderBy: "created_at DESC");

    final List<Map<String, dynamic>> processedData = maps.map((map) {
      // "reasons" 필드를 JSON 문자열로 파싱
      final reasonsJson = map['reasons'];
      List<dynamic> newList =
          reasonsJson == "[]" ? jsonDecode(reasonsJson) : [];

      // final List<dynamic> reasonsList =
      //     reasonsJson != null ? jsonDecode(reasonsJson) : [];

      // "reasons" 필드를 리스트로 변환하여 맵에 추가
      final Map<String, dynamic> processedMap = {
        ...map,
        "reasons": newList,
      };

      return processedMap;
    }).toList();

    return processedData;
  }

  Future<void> insert(File_table file) async {
    final db = await database;
    file.id = await db?.insert(tableName, file.toMap());
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db?.delete(
      tableName,
      where: "id = ?",
      whereArgs: [id],
    );
  }
}

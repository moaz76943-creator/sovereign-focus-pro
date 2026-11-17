import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String dbFileName = 'focus_studio_pro.db';
  static const int currentSchemaVersion = 2;

  final DatabaseExecutor _db;

  AppDatabase._(this._db);

  static Future<AppDatabase> open({DatabaseFactory? factory, String? customPath}) async {
    final dbFactory = factory ?? databaseFactory;
    final String path;
    if (customPath != null) {
      path = customPath;
    } else {
      final dbDir = await getDatabasesPath();
      path = p.join(dbDir, dbFileName);
    }

    final db = await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: currentSchemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _runMigrations(db, 0, version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (newVersion < oldVersion) {
            throw StateError('Destructive downgrade is strictly forbidden.');
          }
          await _runMigrations(db, oldVersion, newVersion);
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _runMigrations(Database db, int fromVersion, int toVersion) async {
    if (fromVersion < 1 && toVersion >= 1) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schema_migrations_log (
          version INTEGER PRIMARY KEY,
          applied_at_utc TEXT NOT NULL,
          notes TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS decks (
          id TEXT PRIMARY KEY,
          parent_id TEXT,
          title TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          category_path TEXT NOT NULL DEFAULT '',
          archived INTEGER NOT NULL DEFAULT 0,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS card_templates (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          fields_json TEXT NOT NULL,
          question_side_fields_json TEXT NOT NULL,
          answer_side_fields_json TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cards (
          id TEXT PRIMARY KEY,
          deck_id TEXT NOT NULL,
          template_id TEXT NOT NULL,
          fields_map_json TEXT NOT NULL,
          preserved_extra_fields_json TEXT NOT NULL DEFAULT '{}',
          target_languages_json TEXT NOT NULL DEFAULT '[]',
          tags_json TEXT NOT NULL DEFAULT '[]',
          is_favorite INTEGER NOT NULL DEFAULT 0,
          is_difficult INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          fsrs_state_json TEXT NOT NULL,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL,
          FOREIGN KEY (deck_id) REFERENCES decks(id) ON DELETE RESTRICT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS review_logs (
          event_id TEXT PRIMARY KEY,
          card_id TEXT NOT NULL,
          rating INTEGER NOT NULL,
          reviewed_at_utc TEXT NOT NULL,
          scheduled_days REAL NOT NULL,
          elapsed_days REAL NOT NULL,
          stability REAL NOT NULL,
          difficulty REAL NOT NULL,
          FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE RESTRICT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS tts_preferences (
          language_code TEXT PRIMARY KEY,
          engine_package TEXT,
          voice_name TEXT,
          gender_preference TEXT NOT NULL DEFAULT 'any',
          speech_speed REAL NOT NULL DEFAULT 1.0,
          repeat_count INTEGER NOT NULL DEFAULT 1,
          auto_pronounce INTEGER NOT NULL DEFAULT 0,
          updated_at_utc TEXT NOT NULL
        )
      ''');

      await db.insert('schema_migrations_log', {
        'version': 1,
        'applied_at_utc': DateTime.now().toUtc().toIso8601String(),
        'notes': 'Initial non-destructive core schema for decks, templates, cards, FSRS logs, and TTS prefs.',
      });
    }

    if (fromVersion < 2 && toVersion >= 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS focus_sessions (
          id TEXT PRIMARY KEY,
          mode TEXT NOT NULL,
          duration_seconds INTEGER NOT NULL,
          completed INTEGER NOT NULL DEFAULT 1,
          started_at_utc TEXT NOT NULL,
          ended_at_utc TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT ''
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS tasks_items (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT '',
          due_date_utc TEXT,
          completed INTEGER NOT NULL DEFAULT 0,
          priority INTEGER NOT NULL DEFAULT 2,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL
        )
      ''');

      await db.insert(
        'schema_migrations_log',
        {
          'version': 2,
          'applied_at_utc': DateTime.now().toUtc().toIso8601String(),
          'notes': 'Add focus_sessions and tasks_items tables.',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> ensureDefaultDeckAndTemplate() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      'decks',
      {
        'id': 'default_deck',
        'parent_id': null,
        'title': 'General Study Deck',
        'description': 'Default FSRS-4.5 Deck',
        'category_path': 'root',
        'archived': 0,
        'created_at_utc': now,
        'updated_at_utc': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _db.insert(
      'card_templates',
      {
        'id': 'default_tpl',
        'name': 'Standard QA + Example',
        'fields_json': '["question","answer","example"]',
        'question_side_fields_json': '["question"]',
        'answer_side_fields_json': '["answer","example"]',
        'updated_at_utc': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateCardTemplateSafely({
    required String templateId,
    required String name,
    required List<Map<String, dynamic>> fields,
    required List<String> questionSideFields,
    required List<String> answerSideFields,
    Map<String, String> renamedFieldsMap = const {},
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      'card_templates',
      {
        'id': templateId,
        'name': name,
        'fields_json': jsonEncode(fields),
        'question_side_fields_json': jsonEncode(questionSideFields),
        'answer_side_fields_json': jsonEncode(answerSideFields),
        'updated_at_utc': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (renamedFieldsMap.isNotEmpty) {
      final existingCards = await _db.query(
        'cards',
        where: 'template_id = ?',
        whereArgs: [templateId],
      );
      for (final row in existingCards) {
        final Map<String, dynamic> fieldsMap =
            jsonDecode(row['fields_map_json'] as String) as Map<String, dynamic>;
        final Map<String, dynamic> preservedMap =
            jsonDecode(row['preserved_extra_fields_json'] as String) as Map<String, dynamic>;

        renamedFieldsMap.forEach((oldKey, newKey) {
          if (fieldsMap.containsKey(oldKey)) {
            preservedMap[oldKey] = fieldsMap[oldKey];
            fieldsMap[newKey] = fieldsMap[oldKey];
          }
        });

        await _db.update(
          'cards',
          {
            'fields_map_json': jsonEncode(fieldsMap),
            'preserved_extra_fields_json': jsonEncode(preservedMap),
            'updated_at_utc': now,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  Future<void> upsertDeck(Map<String, Object?> deckRow) async {
    await _db.insert('decks', deckRow, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertCard(Map<String, Object?> cardRow) async {
    await _db.insert('cards', cardRow, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteById(String table, String id) async {
    await _db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertTaskItem(Map<String, Object?> taskRow) async {
    await _db.insert('tasks_items', taskRow, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertFocusSession(Map<String, Object?> sessionRow) async {
    await _db.insert('focus_sessions', sessionRow, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertReviewLog(Map<String, Object?> logRow) async {
    await _db.insert('review_logs', logRow, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<Map<String, Object?>>> queryAll(String table) async {
    return _db.query(table);
  }

  Future<Map<String, dynamic>> exportFullSnapshot() async {
    return {
      'schema_version': currentSchemaVersion,
      'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
      'decks': await queryAll('decks'),
      'card_templates': await queryAll('card_templates'),
      'cards': await queryAll('cards'),
      'review_logs': await queryAll('review_logs'),
      'tts_preferences': await queryAll('tts_preferences'),
      'focus_sessions': await queryAll('focus_sessions'),
      'tasks_items': await queryAll('tasks_items'),
    };
  }

  Future<void> restoreSnapshotAtomically(Map<String, dynamic> snapshot) async {
    final db = _db as Database;
    await db.transaction((txn) async {
      for (final table in [
        'decks',
        'card_templates',
        'cards',
        'review_logs',
        'tts_preferences',
        'focus_sessions',
        'tasks_items',
      ]) {
        final rows = snapshot[table];
        if (rows is List) {
          for (final item in rows) {
            if (item is! Map) {
              throw FormatException('Invalid row in table $table');
            }
            await txn.insert(
              table,
              Map<String, Object?>.from(item),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    });
  }
}

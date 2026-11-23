import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focus_studio_pro/core/storage/app_database.dart';
import 'package:focus_studio_pro/features/backup/backup_service.dart';

void main() {
  sqfliteFfiInit();

  test('Restore rejects invalid row types and remains consistent', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    final badSnapshot = {
      'schema_version': 3,
      'decks': [
        {'id': 'ok', 'title': 'Good', 'description': '', 'category_path': '', 'archived': 0, 'created_at_utc': '2026-01-01T00:00:00Z', 'updated_at_utc': '2026-01-01T00:00:00Z'},
        'not-a-map', // invalid
      ],
    };
    expect(
      () => db.restoreSnapshotAtomically(badSnapshot),
      throwsA(isA<FormatException>()),
    );
    // Transaction should have rolled back; no partial data
    final decks = await db.queryAll('decks');
    expect(decks, isEmpty);
    await db.close();
  });

  test('Foreign key constraint prevents orphan cards', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    // Try to insert card without deck
    expect(
      () => db.upsertCard({
        'id': 'orphan',
        'deck_id': 'missing_deck',
        'template_id': 'tpl',
        'fields_map_json': '{}',
        'preserved_extra_fields_json': '{}',
        'target_languages_json': '[]',
        'tags_json': '[]',
        'is_favorite': 0,
        'is_difficult': 0,
        'is_archived': 0,
        'fsrs_state_json': '{}',
        'created_at_utc': now,
        'updated_at_utc': now,
      }),
      throwsA(anything), // SQLite FK constraint
    );
    await db.close();
  });

  test('CSV import preview safely handles formula-like and special characters', () {
    const malicious = '''front,back
=CMD|'/C calc'!A0,normal
"quoted ""with"" quotes",line
with
newline,ok
''';
    final preview = BackupService.previewDelimitedImport(malicious, delimiter: ',');
    // Should parse without crashing; formula is just a string
    expect(preview.rowCount, greaterThan(0));
    expect(preview.parsedRows.any((r) => r['front']?.contains('=CMD') == true), isTrue);
    // Unbalanced or multi-line is handled by the splitter
  });

  test('Empty or header-only import is invalid', () {
    final empty = BackupService.previewDelimitedImport('', delimiter: ',');
    expect(empty.isValid, isFalse);
    expect(empty.errors, isNotEmpty);

    final headerOnly = BackupService.previewDelimitedImport('a,b,c\n', delimiter: ',');
    expect(headerOnly.isValid, isFalse);
  });
}

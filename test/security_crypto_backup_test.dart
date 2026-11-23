import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focus_studio_pro/core/storage/app_database.dart';
import 'package:focus_studio_pro/features/backup/backup_service.dart';

void main() {
  sqfliteFfiInit();

  test('Encrypted backup rejects empty passphrase', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    expect(
      () => BackupService.createEncryptedBackup(db: db, passphrase: ''),
      throwsA(isA<ArgumentError>()),
    );
    await db.close();
  });

  test('Restore with wrong passphrase fails authentication (AES-GCM MAC)', () async {
    final db1 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await db1.upsertDeck({
      'id': 'secure_deck',
      'parent_id': null,
      'title': 'Sensitive Data',
      'description': 'Must not restore with wrong key',
      'category_path': '',
      'archived': 0,
      'created_at_utc': now,
      'updated_at_utc': now,
    });

    final encrypted = await BackupService.createEncryptedBackup(
      db: db1,
      passphrase: 'correct-horse-battery-staple',
    );
    await db1.close();

    final db2 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    expect(
      () => BackupService.restoreEncryptedBackup(
        db: db2,
        encryptedPayload: encrypted,
        passphrase: 'wrong-passphrase',
      ),
      throwsA(anything), // SecretBoxAuthenticationError or similar from cryptography package
    );
    // Ensure no data was restored
    final decks = await db2.queryAll('decks');
    expect(decks, isEmpty);
    await db2.close();
  });

  test('Tampered ciphertext or MAC is rejected', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    final encrypted = await BackupService.createEncryptedBackup(
      db: db,
      passphrase: 'valid-key',
    );
    await db.close();

    final envelope = jsonDecode(encrypted) as Map<String, dynamic>;
    // Flip one byte in cipher text
    final cipher = base64Decode(envelope['cipher_b64'] as String);
    if (cipher.isNotEmpty) cipher[0] = cipher[0] ^ 0xFF;
    envelope['cipher_b64'] = base64Encode(cipher);
    final tampered = jsonEncode(envelope);

    final db2 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    expect(
      () => BackupService.restoreEncryptedBackup(
        db: db2,
        encryptedPayload: tampered,
        passphrase: 'valid-key',
      ),
      throwsA(anything),
    );
    await db2.close();
  });

  test('Unsupported magic header is rejected', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    final encrypted = await BackupService.createEncryptedBackup(
      db: db,
      passphrase: 'key',
    );
    await db.close();

    final envelope = jsonDecode(encrypted) as Map<String, dynamic>;
    envelope['magic'] = 'WRONG_MAGIC';
    final bad = jsonEncode(envelope);

    final db2 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    expect(
      () => BackupService.restoreEncryptedBackup(
        db: db2,
        encryptedPayload: bad,
        passphrase: 'key',
      ),
      throwsA(isA<FormatException>()),
    );
    await db2.close();
  });
}

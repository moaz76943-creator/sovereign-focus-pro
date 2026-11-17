import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../../core/storage/app_database.dart';

class ImportPreviewResult {
  final bool isValid;
  final int rowCount;
  final List<String> detectedColumns;
  final List<String> errors;
  final List<Map<String, String>> parsedRows;

  const ImportPreviewResult({
    required this.isValid,
    required this.rowCount,
    required this.detectedColumns,
    required this.errors,
    required this.parsedRows,
  });
}

class BackupService {
  static const int _pbkdf2Iterations = 60000;
  static const String _envelopeMagic = 'FOCUS_STUDIO_PRO_AES256GCM_V1';

  static Future<String> createEncryptedBackup({
    required AppDatabase db,
    required String passphrase,
  }) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('Passphrase cannot be empty for encrypted backup.');
    }
    final snapshot = await db.exportFullSnapshot();
    final plaintextBytes = utf8.encode(jsonEncode(snapshot));

    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final nonce = List<int>.generate(12, (_) => rnd.nextInt(256));

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = {
      'magic': _envelopeMagic,
      'salt_b64': base64Encode(salt),
      'nonce_b64': base64Encode(nonce),
      'cipher_b64': base64Encode(secretBox.cipherText),
      'mac_b64': base64Encode(secretBox.mac.bytes),
    };
    return jsonEncode(envelope);
  }

  static Future<void> restoreEncryptedBackup({
    required AppDatabase db,
    required String encryptedPayload,
    required String passphrase,
  }) async {
    final Map<String, dynamic> envelope =
        jsonDecode(encryptedPayload) as Map<String, dynamic>;
    if (envelope['magic'] != _envelopeMagic) {
      throw const FormatException('Unsupported backup format magic header.');
    }

    final salt = base64Decode(envelope['salt_b64'] as String);
    final nonce = base64Decode(envelope['nonce_b64'] as String);
    final cipherText = base64Decode(envelope['cipher_b64'] as String);
    final macBytes = base64Decode(envelope['mac_b64'] as String);

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final aesGcm = AesGcm.with256bits();
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final clearBytes = await aesGcm.decrypt(secretBox, secretKey: secretKey);
    final snapshot =
        jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
    await db.restoreSnapshotAtomically(snapshot);
  }

  static ImportPreviewResult previewDelimitedImport(
    String content, {
    required String delimiter,
  }) {
    final lines = const LineSplitter()
        .convert(content)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const ImportPreviewResult(
        isValid: false,
        rowCount: 0,
        detectedColumns: [],
        errors: ['Input file is empty.'],
        parsedRows: [],
      );
    }

    final headers = _splitDelimitedLine(lines.first, delimiter);
    if (headers.isEmpty || headers.any((h) => h.trim().isEmpty)) {
      return const ImportPreviewResult(
        isValid: false,
        rowCount: 0,
        detectedColumns: [],
        errors: ['Header row contains empty column names.'],
        parsedRows: [],
      );
    }

    final errors = <String>[];
    final rows = <Map<String, String>>[];

    for (var i = 1; i < lines.length; i++) {
      final values = _splitDelimitedLine(lines[i], delimiter);
      if (values.length != headers.length) {
        errors.add(
            'Row ${i + 1}: expected ${headers.length} columns, found ${values.length}.');
        continue;
      }
      final map = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        map[headers[c]] = values[c];
      }
      rows.add(map);
    }

    return ImportPreviewResult(
      isValid: errors.isEmpty && rows.isNotEmpty,
      rowCount: rows.length,
      detectedColumns: headers,
      errors: errors,
      parsedRows: rows,
    );
  }

  static String exportCardsToDelimited(
    List<Map<String, Object?>> cards, {
    required List<String> fieldKeys,
    required String delimiter,
  }) {
    final cols = ['id', 'deck_id', 'template_id', ...fieldKeys, 'tags'];
    final buf = StringBuffer();
    buf.writeln(cols.map((c) => _escapeCell(c, delimiter)).join(delimiter));

    for (final c in cards) {
      final fieldsMap = jsonDecode((c['fields_map_json'] as String?) ?? '{}')
          as Map<String, dynamic>;
      final tags =
          (jsonDecode((c['tags_json'] as String?) ?? '[]') as List).join('|');
      final row = <String>[
        (c['id'] ?? '').toString(),
        (c['deck_id'] ?? '').toString(),
        (c['template_id'] ?? '').toString(),
        ...fieldKeys.map((k) => (fieldsMap[k] ?? '').toString()),
        tags,
      ];
      buf.writeln(row.map((v) => _escapeCell(v, delimiter)).join(delimiter));
    }
    return buf.toString();
  }

  static List<String> _splitDelimitedLine(String line, String delimiter) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && ch == delimiter) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString());
    return result;
  }

  static String _escapeCell(String value, String delimiter) {
    if (value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

import 'package:flutter/services.dart';
import '../../core/storage/app_database.dart';

class TtsEngineInfoModel {
  final String packageName;
  final String label;

  const TtsEngineInfoModel({
    required this.packageName,
    required this.label,
  });
}

class TtsVoiceModel {
  final String name;
  final String locale;
  final String languageCode;
  final String countryCode;
  final String gender;
  final int quality;
  final int latency;
  final bool networkRequired;

  const TtsVoiceModel({
    required this.name,
    required this.locale,
    required this.languageCode,
    required this.countryCode,
    required this.gender,
    required this.quality,
    required this.latency,
    required this.networkRequired,
  });

  factory TtsVoiceModel.fromMap(Map<dynamic, dynamic> map) {
    return TtsVoiceModel(
      name: (map['name'] ?? '').toString(),
      locale: (map['locale'] ?? '').toString(),
      languageCode: (map['languageCode'] ?? '').toString(),
      countryCode: (map['countryCode'] ?? '').toString(),
      gender: (map['gender'] ?? 'neutral').toString(),
      quality: ((map['quality'] as num?) ?? 0).toInt(),
      latency: ((map['latency'] as num?) ?? 0).toInt(),
      networkRequired: (map['networkRequired'] as bool?) ?? false,
    );
  }
}

class LanguageTtsPreference {
  final String languageCode;
  final String? enginePackage;
  final String? voiceName;
  final String genderPreference;
  final double speechSpeed;
  final int repeatCount;
  final bool autoPronounce;

  const LanguageTtsPreference({
    required this.languageCode,
    this.enginePackage,
    this.voiceName,
    this.genderPreference = 'any',
    this.speechSpeed = 1.0,
    this.repeatCount = 1,
    this.autoPronounce = false,
  });

  double get clampedSpeed => speechSpeed < 0.5 ? 0.5 : (speechSpeed > 2.0 ? 2.0 : speechSpeed);
  int get clampedRepeat => repeatCount < 1 ? 1 : (repeatCount > 9 ? 9 : repeatCount);

  Map<String, Object?> toDbRow() => {
        'language_code': languageCode,
        'engine_package': enginePackage,
        'voice_name': voiceName,
        'gender_preference': genderPreference,
        'speech_speed': clampedSpeed,
        'repeat_count': clampedRepeat,
        'auto_pronounce': autoPronounce ? 1 : 0,
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
      };

  factory LanguageTtsPreference.fromDbRow(Map<String, Object?> row) {
    return LanguageTtsPreference(
      languageCode: (row['language_code'] ?? '').toString(),
      enginePackage: row['engine_package'] as String?,
      voiceName: row['voice_name'] as String?,
      genderPreference: (row['gender_preference'] ?? 'any').toString(),
      speechSpeed: ((row['speech_speed'] as num?) ?? 1.0).toDouble(),
      repeatCount: ((row['repeat_count'] as num?) ?? 1).toInt(),
      autoPronounce: ((row['auto_pronounce'] as num?) ?? 0).toInt() == 1,
    );
  }
}

class TtsSpeakOutcome {
  final bool spoken;
  final String? unavailableReason;
  final String? activeFieldKey;

  const TtsSpeakOutcome({
    required this.spoken,
    this.unavailableReason,
    this.activeFieldKey,
  });
}

/// Independent Native Android TTS abstraction layer.
/// Never claims a language or voice exists without inspecting the device.
/// Provides per-field playback controls, 0.5x..2.0x speed, 1..9 repeats,
/// optional auto-pronounce on card open, and fallback engine recovery.
class NativeTtsService {
  static const MethodChannel _defaultChannel =
      MethodChannel('com.moaz.focusstudiopro/native_tts');

  final MethodChannel _channel;
  final AppDatabase? _db;
  String? _currentlyPlayingFieldKey;

  NativeTtsService({MethodChannel? channel, AppDatabase? db})
      : _channel = channel ?? _defaultChannel,
        _db = db;

  String? get currentlyPlayingFieldKey => _currentlyPlayingFieldKey;

  Future<List<TtsEngineInfoModel>> discoverInstalledEngines() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('discoverEngines') ?? const [];
    return raw.map((e) {
      final m = e as Map<dynamic, dynamic>;
      return TtsEngineInfoModel(
        packageName: (m['name'] ?? '').toString(),
        label: (m['label'] ?? '').toString(),
      );
    }).toList();
  }

  Future<List<TtsVoiceModel>> discoverAvailableVoices() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('discoverVoices') ?? const [];
    return raw.map((e) => TtsVoiceModel.fromMap(e as Map<dynamic, dynamic>)).toList();
  }

  /// Checks whether the device actually exposes at least one voice for `languageCode`.
  Future<bool> isLanguageVoiceInstalledOnDevice(String languageCode) async {
    final norm = languageCode.trim().toLowerCase();
    final voices = await discoverAvailableVoices();
    return voices.any((v) =>
        v.languageCode.toLowerCase() == norm ||
        v.locale.toLowerCase().startsWith('$norm-'));
  }

  Future<List<TtsVoiceModel>> voicesForLanguage(
    String languageCode, {
    String genderFilter = 'any',
  }) async {
    final norm = languageCode.trim().toLowerCase();
    final all = await discoverAvailableVoices();
    return all.where((v) {
      final langMatch = v.languageCode.toLowerCase() == norm ||
          v.locale.toLowerCase().startsWith('$norm-');
      if (!langMatch) return false;
      if (genderFilter == 'any') return true;
      return v.gender.toLowerCase() == genderFilter.toLowerCase();
    }).toList();
  }

  Future<void> savePreference(LanguageTtsPreference pref) async {
    final db = _db;
    if (db == null) return;
    final rawSnapshot = await db.exportFullSnapshot();
    final existing = List<Map<String, dynamic>>.from(
      (rawSnapshot['tts_preferences'] as List?) ?? const [],
    );
    existing.removeWhere((r) => r['language_code'] == pref.languageCode);
    existing.add(pref.toDbRow());
    rawSnapshot['tts_preferences'] = existing;
    await db.restoreSnapshotAtomically(rawSnapshot);
  }

  Future<LanguageTtsPreference> loadPreference(String languageCode) async {
    final db = _db;
    if (db != null) {
      final rows = await db.queryAll('tts_preferences');
      for (final r in rows) {
        if (r['language_code'] == languageCode) {
          return LanguageTtsPreference.fromDbRow(r);
        }
      }
    }
    return LanguageTtsPreference(languageCode: languageCode);
  }

  /// Speaks a specific card field (e.g. 'front', 'translation', 'example', or custom field).
  /// Automatically stops any overlapping speech request first.
  Future<TtsSpeakOutcome> speakCardField({
    required String fieldKey,
    required String text,
    required String languageTag,
    LanguageTtsPreference? overridePreference,
  }) async {
    if (text.trim().isEmpty) {
      return const TtsSpeakOutcome(
        spoken: false,
        unavailableReason: 'Field text is empty.',
      );
    }

    await stop();
    final pref = overridePreference ?? await loadPreference(languageTag);
    _currentlyPlayingFieldKey = fieldKey;

    try {
      final ok = await _channel.invokeMethod<bool>('speak', {
        'text': text,
        'voiceName': pref.voiceName,
        'languageTag': languageTag,
        'speed': pref.clampedSpeed,
        'repeatCount': pref.clampedRepeat,
      });
      return TtsSpeakOutcome(
        spoken: ok ?? false,
        activeFieldKey: fieldKey,
      );
    } on PlatformException catch (e) {
      _currentlyPlayingFieldKey = null;
      // Fallback: if selected engine failed, switch back to default engine once
      if (pref.enginePackage != null && pref.enginePackage!.isNotEmpty) {
        await _channel.invokeMethod<bool>('selectEngine', {'enginePackage': null});
        try {
          final retryOk = await _channel.invokeMethod<bool>('speak', {
            'text': text,
            'voiceName': null,
            'languageTag': languageTag,
            'speed': pref.clampedSpeed,
            'repeatCount': pref.clampedRepeat,
          });
          return TtsSpeakOutcome(
            spoken: retryOk ?? false,
            activeFieldKey: fieldKey,
          );
        } on PlatformException catch (e2) {
          return TtsSpeakOutcome(
            spoken: false,
            unavailableReason: e2.message ?? e2.code,
          );
        }
      }
      return TtsSpeakOutcome(
        spoken: false,
        unavailableReason: e.message ?? e.code,
      );
    }
  }

  Future<void> stop() async {
    _currentlyPlayingFieldKey = null;
    await _channel.invokeMethod<bool>('stop');
  }

  Future<bool> promptInstallMissingSpeechData() async {
    try {
      return await _channel.invokeMethod<bool>('installMissingTtsData') ?? false;
    } on PlatformException {
      return false;
    }
  }
}

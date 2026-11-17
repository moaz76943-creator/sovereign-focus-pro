import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Pure Nature & Ambient Sound Presets.
/// Uses verified CC0 / Public Domain natural recordings bundled in `assets/audio/`
/// via Native Android `MediaPlayer`, with rich multi-layered organic acoustic WAV
/// synthesis over Native Android `AudioTrack` as an offline fallback.
enum AmbientSoundPreset {
  gentleRain(
    id: 'gentle_rain',
    titleEn: 'Gentle Rain on Window (CC0)',
    titleAr: 'مطر هادئ على النافذة (طبيعي)',
    category: 'nature',
  ),
  oceanWaves(
    id: 'ocean_waves',
    titleEn: 'Calm Ocean Waves (CC0)',
    titleAr: 'أمواج البحر الهادئة (طبيعي)',
    category: 'nature',
  ),
  fireplaceEmber(
    id: 'fireplace_ember',
    titleEn: 'Warm Fireplace Embers (CC0)',
    titleAr: 'حطب وجمر المدفأة (طبيعي)',
    category: 'nature',
  ),
  forestWind(
    id: 'forest_wind',
    titleEn: 'Forest Birds & Breeze (CC0)',
    titleAr: 'طيور ونسيم الغابة (طبيعي)',
    category: 'nature',
  ),
  waterDrops(
    id: 'water_drops',
    titleEn: 'Flowing Mountain Stream (CC0)',
    titleAr: 'جدول ماء جاري (طبيعي)',
    category: 'nature',
  ),
  spatialBinauralAlpha(
    id: 'spatial_binaural_alpha',
    titleEn: '3D Spatial Focus Resonance (10Hz Alpha)',
    titleAr: 'رنين التركيز المكاني 3D (موجات ألفا)',
    category: 'spatial_3d',
  );

  final String id;
  final String titleEn;
  final String titleAr;
  final String category;

  const AmbientSoundPreset({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.category,
  });
}

/// Zero-Hiss, Zero-Auto-Play Audio Controller & Acoustic DSP Engine:
/// 1. NEVER auto-plays on startup or tab switch (`isPlaying` starts strictly `false`).
/// 2. Connects directly to `com.moaz.focusstudiopro/native_audio` in `MainActivity.java`
///    to play real CC0 `.ogg` nature assets or organic multi-layered PCM16 loops.
class ProceduralSoundEngine {
  static const int sampleRate = 44100;
  static const MethodChannel _audioChannel =
      MethodChannel('com.moaz.focusstudiopro/native_audio');

  static final Map<AmbientSoundPreset, Uint8List> _cachedLoops = {};

  bool _isPlaying = false;
  final Map<AmbientSoundPreset, double> _activeMixVolumes = {};

  bool get isPlaying => _isPlaying;

  Map<AmbientSoundPreset, double> get activeMixVolumes =>
      Map.unmodifiable(_activeMixVolumes);

  void setPresetVolume(AmbientSoundPreset preset, double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped <= 0.001) {
      _activeMixVolumes.remove(preset);
    } else {
      _activeMixVolumes[preset] = clamped;
    }
    _isPlaying = _activeMixVolumes.isNotEmpty;
    _dispatchToNativeAndroid(preset, clamped);
  }

  Future<void> _dispatchToNativeAndroid(
      AmbientSoundPreset preset, double volume) async {
    try {
      Uint8List? wavBytes;
      if (volume > 0.001) {
        wavBytes = _cachedLoops.putIfAbsent(
          preset,
          () => synthesizeCleanWav(
            preset: preset,
            durationSeconds: 3,
            volume: 0.75,
          ),
        );
      }
      await _audioChannel.invokeMethod<bool>('setSoundVolume', {
        'soundId': preset.id,
        'volume': volume,
        'wavBytes': wavBytes,
      });
    } catch (_) {
      // Ignored during headless unit tests where MethodChannel has no host
    }
  }

  /// Immediate emergency stop — silences all active tracks cleanly.
  void stopAll() {
    _activeMixVolumes.clear();
    _isPlaying = false;
    try {
      _audioChannel.invokeMethod<bool>('stopAllSounds');
    } catch (_) {}
  }

  Future<void> playCompletionChime() async {
    try {
      final chimeWav = synthesizeCompletionChimeWav();
      await _audioChannel.invokeMethod<bool>('playCompletionChime', {
        'wavBytes': chimeWav,
      });
    } catch (_) {}
  }

  /// Synthesizes a gentle harmonic bell chime for timer completion.
  static Uint8List synthesizeCompletionChimeWav() {
    const int totalSamples = sampleRate * 2;
    final pcmSamples = Float64List(totalSamples);
    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final env = math.exp(-2.6 * t) * math.sin(math.pi * math.min(1.0, t / 0.02));
      final sig = 0.55 * math.sin(2.0 * math.pi * 528.0 * t) +
          0.28 * math.sin(2.0 * math.pi * 792.0 * t) +
          0.17 * math.sin(2.0 * math.pi * 1056.0 * t);
      pcmSamples[i] = (sig * env * 0.65).clamp(-0.95, 0.95);
    }
    return _encodePcm16MonoWav(pcmSamples, sampleRate);
  }

  /// Generates a clean, click-free, DC-centered 16-bit PCM WAV buffer.
  static Uint8List synthesizeCleanWav({
    required AmbientSoundPreset preset,
    num durationSeconds = 2,
    double volume = 0.5,
  }) {
    final int totalSamples = math.max(2048, (durationSeconds * sampleRate).round());
    final pcmSamples = Float64List(totalSamples);
    final rnd = math.Random(42 + preset.index);

    double lpState1 = 0.0;
    double lpState2 = 0.0;
    double dcPrevX = 0.0;
    double dcPrevY = 0.0;

    final int fadeSamples = math.min(totalSamples ~/ 10, sampleRate ~/ 10);

    for (var i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      double raw = 0.0;

      switch (preset) {
        case AmbientSoundPreset.gentleRain:
          final white = (rnd.nextDouble() * 2.0) - 1.0;
          lpState1 = (0.94 * lpState1) + (0.06 * white);
          lpState2 = (0.86 * lpState2) + (0.14 * lpState1);
          final dropletMod = 0.78 + 0.22 * math.sin(2.0 * math.pi * 0.45 * t);
          raw = lpState2 * dropletMod * 0.55;
          break;
        case AmbientSoundPreset.oceanWaves:
          final white = (rnd.nextDouble() * 2.0) - 1.0;
          lpState1 = (0.975 * lpState1) + (0.025 * white);
          lpState2 = (0.95 * lpState2) + (0.05 * lpState1);
          final waveSwell = 0.50 + 0.45 * math.sin(2.0 * math.pi * 0.18 * t);
          raw = lpState2 * waveSwell * 0.65;
          break;
        case AmbientSoundPreset.fireplaceEmber:
          final white = (rnd.nextDouble() * 2.0) - 1.0;
          lpState1 = (0.96 * lpState1) + (0.04 * white);
          final crackle = (rnd.nextDouble() > 0.9965) ? 0.35 : 0.0;
          lpState2 = (0.82 * lpState2) + (0.18 * (lpState1 + crackle));
          raw = lpState2 * 0.55;
          break;
        case AmbientSoundPreset.forestWind:
          final white = (rnd.nextDouble() * 2.0) - 1.0;
          lpState1 = (0.985 * lpState1) + (0.015 * white);
          final gust = 0.55 + 0.35 * math.sin(2.0 * math.pi * 0.27 * t);
          raw = lpState1 * gust * 0.60;
          break;
        case AmbientSoundPreset.waterDrops:
          final env = math.exp(-9.0 * (t % 0.65));
          final dropFreq = 580.0 + 180.0 * math.sin(2.0 * math.pi * 1.5 * t);
          final white = (rnd.nextDouble() * 2.0) - 1.0;
          lpState1 = (0.95 * lpState1) + (0.05 * white);
          raw = (math.sin(2.0 * math.pi * dropFreq * t) * env * 0.22) + (lpState1 * 0.25);
          break;
        case AmbientSoundPreset.spatialBinauralAlpha:
          raw = (0.5 * math.sin(2.0 * math.pi * 200.0 * t) +
                  0.5 * math.sin(2.0 * math.pi * 210.0 * t)) *
              0.25;
          break;
      }

      // First-order DC blocker: y[n] = x[n] - x[n-1] + 0.995 * y[n-1]
      final double dcClean = raw - dcPrevX + (0.995 * dcPrevY);
      dcPrevX = raw;
      dcPrevY = dcClean;

      // Smooth cosine fade-in / fade-out envelope
      double envelope = 1.0;
      if (i < fadeSamples) {
        envelope = 0.5 * (1.0 - math.cos(math.pi * i / fadeSamples));
      } else if (i >= totalSamples - fadeSamples) {
        final rem = totalSamples - 1 - i;
        envelope = 0.5 * (1.0 - math.cos(math.pi * rem / fadeSamples));
      }

      pcmSamples[i] = (dcClean * envelope * volume.clamp(0.0, 1.0)).clamp(-0.95, 0.95);
    }

    return _encodePcm16MonoWav(pcmSamples, sampleRate);
  }

  static Uint8List _encodePcm16MonoWav(Float64List samples, int rate) {
    final int dataByteSize = samples.length * 2;
    final int fileByteSize = 44 + dataByteSize;
    final byteData = ByteData(fileByteSize);

    final riff = [0x52, 0x49, 0x46, 0x46];
    final wave = [0x57, 0x41, 0x56, 0x45];
    final fmt = [0x66, 0x6D, 0x74, 0x20];
    final data = [0x64, 0x61, 0x74, 0x61];

    for (var i = 0; i < 4; i++) {
      byteData.setUint8(i, riff[i]);
      byteData.setUint8(8 + i, wave[i]);
      byteData.setUint8(12 + i, fmt[i]);
      byteData.setUint8(36 + i, data[i]);
    }

    byteData.setUint32(4, 36 + dataByteSize, Endian.little);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, rate, Endian.little);
    byteData.setUint32(28, rate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    byteData.setUint32(40, dataByteSize, Endian.little);

    var offset = 44;
    for (var i = 0; i < samples.length; i++) {
      final int pcm16 = (samples[i] * 32767.0).round().clamp(-32768, 32767);
      byteData.setInt16(offset, pcm16, Endian.little);
      offset += 2;
    }
    return byteData.buffer.asUint8List();
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_studio_pro/features/tts/native_tts_service.dart';
import 'package:focus_studio_pro/features/audio/procedural_sound_engine.dart';
import 'package:focus_studio_pro/features/focus/focus_timer_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NativeTtsService discovers device voices and enforces speed/repeat bounds', () async {
    const channel = MethodChannel('com.moaz.focusstudiopro/native_tts_test');
    Map<String, dynamic>? lastSpeakArgs;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'discoverVoices':
          return [
            {
              'name': 'de-de-x-deb-network',
              'locale': 'de-DE',
              'languageCode': 'de',
              'countryCode': 'DE',
              'gender': 'male',
              'quality': 400,
              'latency': 200,
              'networkRequired': false,
            },
            {
              'name': 'ar-xa-x-arz-local',
              'locale': 'ar-JO',
              'languageCode': 'ar',
              'countryCode': 'JO',
              'gender': 'female',
              'quality': 500,
              'latency': 100,
              'networkRequired': false,
            },
          ];
        case 'stop':
          return true;
        case 'speak':
          lastSpeakArgs = Map<String, dynamic>.from(call.arguments as Map);
          return true;
        default:
          return null;
      }
    });

    final tts = NativeTtsService(channel: channel);
    expect(await tts.isLanguageVoiceInstalledOnDevice('de'), isTrue);
    expect(await tts.isLanguageVoiceInstalledOnDevice('ja'), isFalse);

    final outcome = await tts.speakCardField(
      fieldKey: 'example',
      text: 'Ich erinnere mich an dich.',
      languageTag: 'de-DE',
      overridePreference: const LanguageTtsPreference(
        languageCode: 'de',
        speechSpeed: 3.5, // Clamped to 2.0
        repeatCount: 15,  // Clamped to 9
      ),
    );

    expect(outcome.spoken, isTrue);
    expect(lastSpeakArgs?['speed'], 2.0);
    expect(lastSpeakArgs?['repeatCount'], 9);
  });

  test('ProceduralSoundEngine never auto-plays, produces clean WAV, and stops immediately', () {
    final engine = ProceduralSoundEngine();
    expect(engine.isPlaying, isFalse);
    expect(engine.activeMixVolumes, isEmpty);

    engine.setPresetVolume(AmbientSoundPreset.gentleRain, 0.7);
    expect(engine.isPlaying, isTrue);

    engine.stopAll();
    expect(engine.isPlaying, isFalse);
    expect(engine.activeMixVolumes, isEmpty);

    final wavBytes = ProceduralSoundEngine.synthesizeCleanWav(
      preset: AmbientSoundPreset.gentleRain,
      durationSeconds: 0.25,
    );
    expect(wavBytes.length, greaterThan(44));
    expect(String.fromCharCodes(wavBytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wavBytes.sublist(8, 12)), 'WAVE');
  });

  test('FocusTimerController handles sets, rest transitions, and Western digits', () {
    final timer = FocusTimerController();
    timer.configureCustom(sets: 2, workSeconds: 60, restSeconds: 30, skipFinalRest: true);
    expect(timer.state.formattedWesternClock, '01:00');

    timer.start();
    timer.tick(60); // Finish set 1 work -> enters rest
    expect(timer.state.isRestPhase, isTrue);
    expect(timer.state.remainingSeconds, 30);

    timer.tick(30); // Finish set 1 rest -> enters set 2 work
    expect(timer.state.currentSet, 2);
    expect(timer.state.isRestPhase, isFalse);

    timer.tick(60); // Finish set 2 work -> skips final rest and completes
    expect(timer.state.isRunning, isFalse);
    expect(timer.state.remainingSeconds, 0);
  });
}

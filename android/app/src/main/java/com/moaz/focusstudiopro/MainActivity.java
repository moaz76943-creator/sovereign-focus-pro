package com.moaz.focusstudiopro;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.res.AssetFileDescriptor;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.speech.tts.Voice;
import android.view.Display;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_SYSTEM = "com.moaz.focusstudiopro/system_insets";
    private static final String CHANNEL_TTS = "com.moaz.focusstudiopro/native_tts";
    private static final String CHANNEL_AUDIO = "com.moaz.focusstudiopro/native_audio";
    private static final String CHANNEL_SAF = "com.moaz.focusstudiopro/saf_storage";

    private static final int REQ_CREATE_DOC = 9101;
    private static final int REQ_OPEN_DOC = 9102;

    private TextToSpeech tts;
    private boolean ttsReady = false;
    private String activeEnginePackage = null;
    private Insets lastSystemBarInsets = Insets.NONE;

    // Multi-track CC0 MediaPlayers + Procedural AudioTrack fallback
    private final Map<String, MediaPlayer> mediaPlayers = new ConcurrentHashMap<>();
    private final Map<String, AudioTrack> synthTracks = new ConcurrentHashMap<>();
    private final Map<String, Float> activeVolumes = new ConcurrentHashMap<>();

    private MethodChannel.Result pendingSafResult = null;
    private String pendingSafContentToWrite = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureEdgeToEdgeSystemBars();
        enableHighRefreshRate120Hz();
        initDefaultTts(null);
    }

    private void configureEdgeToEdgeSystemBars() {
        Window window = getWindow();
        if (window == null) return;
        WindowCompat.setDecorFitsSystemWindows(window, false);
        View decorView = window.getDecorView();
        ViewCompat.setOnApplyWindowInsetsListener(decorView, (v, windowInsets) -> {
            lastSystemBarInsets = windowInsets.getInsets(
                WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout()
            );
            return WindowInsetsCompat.CONSUMED;
        });
    }

    private void enableHighRefreshRate120Hz() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Window window = getWindow();
            if (window == null) return;
            Display display = getDisplayCompat();
            if (display == null) return;
            Display.Mode[] modes = display.getSupportedModes();
            Display.Mode bestMode = null;
            float maxHz = 60.0f;
            for (Display.Mode mode : modes) {
                if (mode.getRefreshRate() > maxHz) {
                    maxHz = mode.getRefreshRate();
                    bestMode = mode;
                }
            }
            if (bestMode != null) {
                WindowManager.LayoutParams params = window.getAttributes();
                params.preferredDisplayModeId = bestMode.getModeId();
                window.setAttributes(params);
            }
        }
    }

    @SuppressWarnings("deprecation")
    private Display getDisplayCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return getDisplay();
        }
        return getWindowManager().getDefaultDisplay();
    }

    private synchronized void initDefaultTts(final String enginePkg) {
        if (tts != null) {
            try {
                tts.stop();
                tts.shutdown();
            } catch (Exception ignored) {}
        }
        ttsReady = false;
        activeEnginePackage = enginePkg;
        TextToSpeech.OnInitListener listener = status -> {
            ttsReady = (status == TextToSpeech.SUCCESS);
        };
        if (enginePkg != null && !enginePkg.trim().isEmpty()) {
            tts = new TextToSpeech(getApplicationContext(), listener, activeEnginePackage);
        } else {
            tts = new TextToSpeech(getApplicationContext(), listener);
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_SYSTEM)
            .setMethodCallHandler((call, result) -> {
                if ("getSystemBarInsets".equals(call.method)) {
                    Map<String, Integer> map = new HashMap<>();
                    map.put("top", lastSystemBarInsets.top);
                    map.put("bottom", lastSystemBarInsets.bottom);
                    map.put("left", lastSystemBarInsets.left);
                    map.put("right", lastSystemBarInsets.right);
                    result.success(map);
                } else if ("setKeepScreenOn".equals(call.method)) {
                    Boolean enable = call.argument("enable");
                    runOnUiThread(() -> {
                        Window w = getWindow();
                        if (w != null) {
                            if (Boolean.TRUE.equals(enable)) {
                                w.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                            } else {
                                w.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                            }
                        }
                    });
                    result.success(true);
                } else {
                    result.notImplemented();
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_TTS)
            .setMethodCallHandler(this::handleTtsCall);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_AUDIO)
            .setMethodCallHandler(this::handleAudioCall);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_SAF)
            .setMethodCallHandler(this::handleSafCall);
    }

    private void handleAudioCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "setSoundVolume": {
                String soundId = call.argument("soundId");
                Double volObj = call.argument("volume");
                byte[] wavBytes = call.argument("wavBytes");
                if (soundId == null) {
                    result.error("INVALID_SOUND", "soundId is required", null);
                    return;
                }
                float volume = volObj != null ? Math.max(0f, Math.min(1f, volObj.floatValue())) : 0f;
                if (volume <= 0.001f) {
                    stopSingleSound(soundId);
                    activeVolumes.remove(soundId);
                    result.success(true);
                    return;
                }
                activeVolumes.put(soundId, volume);
                boolean started = startOrUpdateCc0AssetOrTrack(soundId, volume, wavBytes);
                result.success(started);
                break;
            }
            case "stopAllSounds": {
                stopAllAudioInternal();
                result.success(true);
                break;
            }
            case "playCompletionChime": {
                byte[] wavBytes = call.argument("wavBytes");
                playOneShotWav(wavBytes);
                result.success(true);
                break;
            }
            default:
                result.notImplemented();
                break;
        }
    }

    private boolean startOrUpdateCc0AssetOrTrack(String soundId, float volume, byte[] wavBytes) {
        // 1. Check if already playing in MediaPlayer
        MediaPlayer existingMp = mediaPlayers.get(soundId);
        if (existingMp != null) {
            try {
                existingMp.setVolume(volume, volume);
                if (!existingMp.isPlaying()) {
                    existingMp.start();
                }
                return true;
            } catch (Exception ignored) {
                stopSingleSound(soundId);
            }
        }
        // 2. Check if already playing in AudioTrack
        AudioTrack existingAt = synthTracks.get(soundId);
        if (existingAt != null) {
            try {
                existingAt.setVolume(volume);
                if (existingAt.getPlayState() != AudioTrack.PLAYSTATE_PLAYING) {
                    existingAt.play();
                }
                return true;
            } catch (Exception ignored) {
                stopSingleSound(soundId);
            }
        }

        // 3. Try loading real CC0 .ogg recording from Flutter assets first
        String assetRelPath = "flutter_assets/assets/audio/" + mapSoundIdToAssetFile(soundId);
        try {
            AssetFileDescriptor afd = getAssets().openFd(assetRelPath);
            if (afd.getLength() > 4096) {
                MediaPlayer mp = new MediaPlayer();
                mp.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build());
                mp.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
                afd.close();
                mp.setLooping(true);
                mp.prepare();
                mp.setVolume(volume, volume);
                mp.start();
                mediaPlayers.put(soundId, mp);
                return true;
            }
            afd.close();
        } catch (Exception ignored) {
            // Fallback to native PCM16 looping AudioTrack below
        }

        // 4. Native PCM16 AudioTrack looping playback (guaranteed to work offline)
        if (wavBytes != null && wavBytes.length > 44) {
            try {
                int pcmLen = wavBytes.length - 44;
                int sampleRate = 44100;
                int totalFrames = pcmLen / 2;
                AudioTrack track = new AudioTrack.Builder()
                    .setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                    .setAudioFormat(new AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build())
                    .setBufferSizeInBytes(pcmLen)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build();
                track.write(wavBytes, 44, pcmLen);
                track.setLoopPoints(0, totalFrames, -1);
                track.setVolume(volume);
                track.play();
                synthTracks.put(soundId, track);
                return true;
            } catch (Exception e) {
                return false;
            }
        }
        return false;
    }

    private String mapSoundIdToAssetFile(String soundId) {
        switch (soundId) {
            case "gentle_rain":
            case "soft_rain":
                return "rain_window.ogg";
            case "forest_wind":
                return "forest_birds.ogg";
            case "water_drops":
            case "ocean_waves":
                return "flowing_water.ogg";
            case "fireplace_ember":
                return "fireplace_ember.ogg";
            default:
                return soundId + ".ogg";
        }
    }

    private void playOneShotWav(byte[] wavBytes) {
        if (wavBytes == null || wavBytes.length <= 44) return;
        try {
            int pcmLen = wavBytes.length - 44;
            AudioTrack track = new AudioTrack.Builder()
                .setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build())
                .setAudioFormat(new AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(44100)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build())
                .setBufferSizeInBytes(pcmLen)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build();
            track.write(wavBytes, 44, pcmLen);
            track.play();
        } catch (Exception ignored) {}
    }

    private void stopSingleSound(String soundId) {
        MediaPlayer mp = mediaPlayers.remove(soundId);
        if (mp != null) {
            try {
                if (mp.isPlaying()) mp.stop();
                mp.release();
            } catch (Exception ignored) {}
        }
        AudioTrack at = synthTracks.remove(soundId);
        if (at != null) {
            try {
                if (at.getPlayState() == AudioTrack.PLAYSTATE_PLAYING) at.stop();
                at.release();
            } catch (Exception ignored) {}
        }
    }

    private void stopAllAudioInternal() {
        for (String k : new ArrayList<>(mediaPlayers.keySet())) {
            stopSingleSound(k);
        }
        for (String k : new ArrayList<>(synthTracks.keySet())) {
            stopSingleSound(k);
        }
        activeVolumes.clear();
    }

    private void handleSafCall(MethodCall call, MethodChannel.Result result) {
        if ("saveDocument".equals(call.method)) {
            String suggestedName = call.argument("suggestedName");
            String mimeType = call.argument("mimeType");
            String content = call.argument("content");
            if (content == null) {
                result.error("NULL_CONTENT", "Content is required", null);
                return;
            }
            pendingSafResult = result;
            pendingSafContentToWrite = content;
            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType(mimeType != null ? mimeType : "application/octet-stream");
            intent.putExtra(Intent.EXTRA_TITLE, suggestedName != null ? suggestedName : "focus_studio_backup.fsp");
            startActivityForResult(intent, REQ_CREATE_DOC);
        } else if ("openDocument".equals(call.method)) {
            pendingSafResult = result;
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("*/*");
            startActivityForResult(intent, REQ_OPEN_DOC);
        } else {
            result.notImplemented();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (pendingSafResult == null) return;
        MethodChannel.Result res = pendingSafResult;
        pendingSafResult = null;

        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            pendingSafContentToWrite = null;
            res.success(null);
            return;
        }
        Uri uri = data.getData();
        if (requestCode == REQ_CREATE_DOC) {
            try (OutputStream os = getContentResolver().openOutputStream(uri, "wt")) {
                if (os != null && pendingSafContentToWrite != null) {
                    os.write(pendingSafContentToWrite.getBytes(StandardCharsets.UTF_8));
                    os.flush();
                }
                pendingSafContentToWrite = null;
                res.success(uri.toString());
            } catch (Exception e) {
                pendingSafContentToWrite = null;
                res.error("SAF_WRITE_ERR", e.getMessage(), null);
            }
        } else if (requestCode == REQ_OPEN_DOC) {
            try (InputStream is = getContentResolver().openInputStream(uri);
                 BufferedReader reader = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line).append("\n");
                }
                res.success(sb.toString());
            } catch (Exception e) {
                res.error("SAF_READ_ERR", e.getMessage(), null);
            }
        }
    }

    private void handleTtsCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "discoverEngines": {
                List<Map<String, String>> enginesList = new ArrayList<>();
                if (tts != null) {
                    for (TextToSpeech.EngineInfo info : tts.getEngines()) {
                        Map<String, String> item = new HashMap<>();
                        item.put("packageName", info.name);
                        item.put("label", info.label != null ? info.label : info.name);
                        enginesList.add(item);
                    }
                }
                result.success(enginesList);
                break;
            }
            case "selectEngine": {
                String pkg = call.argument("packageName");
                initDefaultTts(pkg);
                result.success(true);
                break;
            }
            case "discoverVoices": {
                List<Map<String, Object>> voicesList = new ArrayList<>();
                if (tts != null && ttsReady && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    Set<Voice> voices = tts.getVoices();
                    if (voices != null) {
                        for (Voice v : voices) {
                            Locale loc = v.getLocale();
                            if (loc == null) continue;
                            String lang = loc.getLanguage();
                            if ("he".equalsIgnoreCase(lang) || "iw".equalsIgnoreCase(lang)) {
                                continue;
                            }
                            Map<String, Object> vm = new HashMap<>();
                            vm.put("name", v.getName());
                            vm.put("locale", loc.toLanguageTag());
                            vm.put("languageCode", lang);
                            vm.put("countryCode", loc.getCountry());
                            vm.put("networkRequired", v.isNetworkConnectionRequired());
                            vm.put("installed", !v.getFeatures().contains("notInstalled"));
                            String vNameLower = v.getName().toLowerCase(Locale.ROOT);
                            String gender = "neutral";
                            if (vNameLower.contains("female") || vNameLower.contains("#female") || vNameLower.contains("-f-")) {
                                gender = "female";
                            } else if (vNameLower.contains("male") || vNameLower.contains("#male") || vNameLower.contains("-m-")) {
                                gender = "male";
                            }
                            vm.put("gender", gender);
                            voicesList.add(vm);
                        }
                    }
                }
                result.success(voicesList);
                break;
            }
            case "speak": {
                if (tts == null || !ttsReady) {
                    result.error("TTS_NOT_READY", "Native Android TTS engine is not initialized.", null);
                    return;
                }
                String text = call.argument("text");
                String langTag = call.argument("languageTag");
                String voiceName = call.argument("voiceName");
                Double rateObj = call.argument("rate");
                Double pitchObj = call.argument("pitch");
                Integer repeatObj = call.argument("repeatCount");

                if (text == null || text.trim().isEmpty()) {
                    result.success(false);
                    return;
                }
                float rate = rateObj != null ? rateObj.floatValue() : 1.0f;
                float pitch = pitchObj != null ? pitchObj.floatValue() : 1.0f;
                int repeatCount = repeatObj != null ? Math.max(1, Math.min(repeatObj, 10)) : 1;

                tts.setSpeechRate(Math.max(0.25f, Math.min(rate, 3.0f)));
                tts.setPitch(Math.max(0.5f, Math.min(pitch, 2.0f)));

                if (langTag != null && !langTag.isEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    Locale targetLocale = Locale.forLanguageTag(langTag);
                    int avail = tts.isLanguageAvailable(targetLocale);
                    if (avail < TextToSpeech.LANG_AVAILABLE) {
                        result.error("VOICE_MISSING", "Voice data for " + langTag + " is not installed on this device.", null);
                        return;
                    }
                    tts.setLanguage(targetLocale);
                    if (voiceName != null && !voiceName.isEmpty()) {
                        Set<Voice> voices = tts.getVoices();
                        if (voices != null) {
                            for (Voice v : voices) {
                                if (voiceName.equals(v.getName())) {
                                    tts.setVoice(v);
                                    break;
                                }
                            }
                        }
                    }
                }

                for (int i = 0; i < repeatCount; i++) {
                    int queueMode = (i == 0) ? TextToSpeech.QUEUE_FLUSH : TextToSpeech.QUEUE_ADD;
                    tts.speak(text, queueMode, null, UUID.randomUUID().toString());
                }
                result.success(true);
                break;
            }
            case "stop": {
                if (tts != null) {
                    tts.stop();
                }
                result.success(true);
                break;
            }
            case "openTtsInstallData": {
                try {
                    Intent installIntent = new Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA);
                    installIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(installIntent);
                    result.success(true);
                } catch (Exception e) {
                    result.error("INTENT_ERROR", e.getMessage(), null);
                }
                break;
            }
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    protected void onDestroy() {
        stopAllAudioInternal();
        if (tts != null) {
            tts.stop();
            tts.shutdown();
        }
        super.onDestroy();
    }
}

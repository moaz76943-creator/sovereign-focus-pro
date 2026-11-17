import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focus_studio_pro/core/storage/app_database.dart';
import 'package:focus_studio_pro/core/diagnostics/self_healing_guardian.dart';
import 'package:focus_studio_pro/features/audio/procedural_sound_engine.dart';
import 'package:focus_studio_pro/features/flashcards/active_recall_modesEngine.dart';
import 'package:focus_studio_pro/features/flashcards/fsrs_engine.dart';
import 'package:focus_studio_pro/features/monetization/ethical_pro_entitlement.dart';

void main() {
  sqfliteFfiInit();

  test('SelfHealingGuardian detects and repairs corrupted card FSRS state non-destructively', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: inMemoryDatabasePath,
    );
    final now = DateTime.now().toUtc().toIso8601String();

    await db.upsertDeck({
      'id': 'd1',
      'parent_id': null,
      'title': 'Test Deck',
      'description': '',
      'category_path': '',
      'archived': 0,
      'created_at_utc': now,
      'updated_at_utc': now,
    });

    await db.upsertCard({
      'id': 'c_corrupt',
      'deck_id': 'd1',
      'template_id': 't1',
      'fields_map_json': jsonEncode({'word': 'Test'}),
      'preserved_extra_fields_json': '{}',
      'target_languages_json': '[]',
      'tags_json': '[]',
      'is_favorite': 0,
      'is_difficult': 0,
      'is_archived': 0,
      'fsrs_state_json': jsonEncode({'stability': -99.0, 'difficulty': 99.0}),
      'created_at_utc': now,
      'updated_at_utc': now,
    });

    final soundEngine = ProceduralSoundEngine();
    final report = await SelfHealingGuardian.runFullDiagnosticAndHeal(
      db: db,
      soundEngine: soundEngine,
    );

    expect(report.allHealthy, isTrue);
    final dbStatus = report.subsystems.firstWhere((s) => s.subsystemId == 'sqlite_fsrs_integrity');
    expect(dbStatus.autoRepaired, isTrue);

    final cards = await db.queryAll('cards');
    final healedState = jsonDecode(cards.first['fsrs_state_json'] as String) as Map<String, dynamic>;
    expect(healedState['stability'], 0.0);
    expect(healedState['difficulty'], 5.0);
  });

  test('ActiveRecallModesEngine evaluates Arabic diacritic-insensitive dictation and suggests FSRS rating', () {
    final eval = ActiveRecallModesEngine.evaluateTypedAnswer(
      expectedAnswer: 'الْعِلْمُ نُورٌ',
      userTypedAnswer: 'العلم نور',
    );
    expect(eval.normalizedMatch, isTrue);
    expect(eval.suggestedRating, FsrsRating.good);

    expect(EthicalProEntitlementService.zeroAdsAndZeroTrackersGuaranteed, isTrue);
    expect(EthicalProEntitlementService.userDataAlwaysExportableForFree, isTrue);
  });
}

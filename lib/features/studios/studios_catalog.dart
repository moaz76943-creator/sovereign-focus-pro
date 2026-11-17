class StudioDefinition {
  final String id;
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
  final String iconName;

  const StudioDefinition({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.iconName,
  });
}

class StudiosCatalog {
  static const List<StudioDefinition> all10Studios = [
    StudioDefinition(
      id: 'deep_study',
      titleEn: 'Deep Study & Pomodoro Studio',
      titleAr: 'استوديو الدراسة العميقة والبومودورو',
      subtitleEn: 'Multi-set interval timer with distraction shield',
      subtitleAr: 'مؤقت جولات متعدد مع درع منع التشتت',
      iconName: 'timer',
    ),
    StudioDefinition(
      id: 'fsrs_flashcards',
      titleEn: 'FSRS-4.5 Polyglot Flashcards Studio',
      titleAr: 'استوديو البطاقات الذكية FSRS-4.5',
      subtitleEn: 'Customizable multi-field cards & native Android TTS',
      subtitleAr: 'حقول وقوالب مرنة مع نطق أندرويد الأصلي',
      iconName: 'style',
    ),
    StudioDefinition(
      id: 'stem_exam',
      titleEn: 'STEM & Strict Exam Simulator',
      titleAr: 'استوديو محاكاة الاختبارات والعلوم',
      subtitleEn: 'Timed exam blocks with question pacing tracker',
      subtitleAr: 'محاكاة امتحانات موقوتة مع متابعة سرعة الحل',
      iconName: 'science',
    ),
    StudioDefinition(
      id: 'active_recall',
      titleEn: 'Active Recall & Feynman Studio',
      titleAr: 'استوديو الاستذكار النشط وطريقة فاينمان',
      subtitleEn: 'Explain concepts simply and spot knowledge gaps',
      subtitleAr: 'اشرح المفاهيم ببساطة واكتشف الفجوات المعرفية',
      iconName: 'psychology',
    ),
    StudioDefinition(
      id: 'reading_synthesis',
      titleEn: 'Reading & Cornell Notes Studio',
      titleAr: 'استوديو القراءة وملاحظات كورنيل',
      subtitleEn: 'Structured chapter summaries and key takeaways',
      subtitleAr: 'تلخيص الفصول والملاحظات المنظمة',
      iconName: 'menu_book',
    ),
    StudioDefinition(
      id: 'acoustic_sanctuary',
      titleEn: 'Royalty-Free Acoustic Sanctuary',
      titleAr: 'الملاذ الصوتي النقي (بدون تشويش)',
      subtitleEn: 'Mathematical DSP rain, fire, wind & waves mixer',
      subtitleAr: 'توليد برمجي نقي للمطر والنار والنسيم والأمواج',
      iconName: 'graphic_eq',
    ),
    StudioDefinition(
      id: 'hiit_workout',
      titleEn: 'HIIT & Physical Vitality Studio',
      titleAr: 'استوديو التمارين والنشاط البدني',
      subtitleEn: 'Work-and-rest interval sequences for active breaks',
      subtitleAr: 'جولات تمرين وراحة منظمة لتجديد النشاط',
      iconName: 'fitness_center',
    ),
    StudioDefinition(
      id: 'habit_planner',
      titleEn: 'Daily Planner & Time-Blocking Studio',
      titleAr: 'استوديو التخطيط اليومي وتقسيم الوقت',
      subtitleEn: 'Prioritized tasks and calendar milestone tracking',
      subtitleAr: 'ترتيب أولويات المهام ومتابعة الإنجاز بالتقويم',
      iconName: 'event_available',
    ),
    StudioDefinition(
      id: 'pronunciation_lab',
      titleEn: 'Native Pronunciation & Shadowing Lab',
      titleAr: 'مختبر النطق الأصلي والمحاكاة الصوتية',
      subtitleEn: '0.5x–2.0x speed, 1–9 repeats & multi-voice comparison',
      subtitleAr: 'تحكم بالسرعة والتكرار ومقارنة أصوات الجهاز',
      iconName: 'record_voice_over',
    ),
    StudioDefinition(
      id: 'vault_backup',
      titleEn: 'Encrypted Vault & Data Integrity Studio',
      titleAr: 'استوديو الخزنة المشفّرة وسلامة البيانات',
      subtitleEn: 'AES-256-GCM backups & CSV/TSV/JSON dry-run import',
      subtitleAr: 'نسخ احتياطي مشفّر واستيراد/تصدير آمن مع معاينة',
      iconName: 'enhanced_encryption',
    ),
  ];
}

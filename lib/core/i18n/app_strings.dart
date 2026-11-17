class AppStrings {
  final String languageCode;
  final Map<String, String> _map;

  const AppStrings(this.languageCode, this._map);

  bool get isRtl => const {
        'ar', 'fa', 'ur', 'ps', 'ku', 'sd', 'ug', 'yi', 'dv'
      }.contains(languageCode);

  String tr(String key) => _map[key] ?? _fallbackEn[key] ?? key;

  static const Map<String, String> _fallbackEn = {
    'app_title': 'Focus Studio Pro',
    'subtitle': 'Focus, Productivity & FSRS-4.5 Learning Studio',
    'tab_focus': 'Focus',
    'tab_flashcards': 'Flashcards',
    'tab_tasks': 'Tasks',
    'tab_calendar': 'Calendar',
    'tab_notes': 'Notes',
    'tab_sounds': 'Sounds',
    'tab_analytics': 'Analytics',
    'studios_menu': 'Studios (10)',
    'start_focus': 'Start Focus',
    'pause_focus': 'Pause',
    'reset_focus': 'Reset',
    'sets_label': 'Sets',
    'work_label': 'Deep Work',
    'rest_label': 'Rest',
    'skip_final_rest': 'Skip final rest',
    'nature_sounds_top': 'Nature Soundscapes (100% Royalty-Free)',
    'spatial_audio_collapsible': '3D Spatial & Bio-Frequencies (Optional)',
    'stop_all_audio': 'Stop All Audio',
    'zero_hiss_badge': 'Zero Auto-Play • Zero Hiss DSP',
    'fsrs_review_title': 'FSRS-4.5 Spaced Repetition',
    'rating_again': 'Again',
    'rating_hard': 'Hard',
    'rating_good': 'Good',
    'rating_easy': 'Easy',
    'search_cards_hint': 'Search cards (Arabic diacritic-insensitive)...',
    'tts_speak_field': 'Pronounce Field',
    'tts_speed': 'Speech Speed',
    'tts_repeat': 'Repeat',
    'new_task_hint': 'Add a new task...',
    'save_btn': 'Save',
    'filter_today': 'Today',
    'filter_upcoming': 'Upcoming',
    'filter_completed': 'Completed',
    'notes_title': 'Notes & Structured Templates',
    'new_note_btn': 'New Note',
    'analytics_title': 'Retention & Focus Analytics',
    'forecast_30d': '30-Day Review Workload Forecast',
    'heatmap_title': 'Daily Consistency Heatmap',
    'export_csv': 'Export CSV',
    'encrypted_backup': 'Encrypted Backup (AES-256-GCM)',
  };

  static const Map<String, String> _arabicPack = {
    'app_title': 'استوديو التركيز الاحترافي',
    'subtitle': 'التركيز والإنتاجية والتعلّم المتباعد FSRS-4.5',
    'tab_focus': 'التركيز',
    'tab_flashcards': 'البطاقات',
    'tab_tasks': 'المهام',
    'tab_calendar': 'التقويم',
    'tab_notes': 'الملاحظات',
    'tab_sounds': 'الأصوات',
    'tab_analytics': 'الإحصائيات',
    'studios_menu': 'الاستوديوهات (10)',
    'start_focus': 'ابدأ التركيز',
    'pause_focus': 'إيقاف مؤقت',
    'reset_focus': 'إعادة ضبط',
    'sets_label': 'الجولات',
    'work_label': 'عمل عميق',
    'rest_label': 'راحة',
    'skip_final_rest': 'تخطي الراحة الأخيرة',
    'nature_sounds_top': 'أصوات الطبيعة النقية (ملكية 100%)',
    'spatial_audio_collapsible': 'الصوت المكاني والترددات الحيوية (اختياري)',
    'stop_all_audio': 'إيقاف كل الأصوات فوراً',
    'zero_hiss_badge': 'بدون تشغيل تلقائي • صفر تشويش',
    'fsrs_review_title': 'المراجعة المتباعدة FSRS-4.5',
    'rating_again': 'نسيت',
    'rating_hard': 'صعب',
    'rating_good': 'جيد',
    'rating_easy': 'سهل',
    'search_cards_hint': 'ابحث في البطاقات (يدعم البحث بدون تشكيل)...',
    'tts_speak_field': 'نطق الحقل',
    'tts_speed': 'سرعة النطق',
    'tts_repeat': 'التكرار',
    'new_task_hint': 'أضف مهمة جديدة...',
    'save_btn': 'حفظ',
    'filter_today': 'اليوم',
    'filter_upcoming': 'القادمة',
    'filter_completed': 'المكتملة',
    'notes_title': 'الملاحظات والقوالب المنظمة',
    'new_note_btn': 'ملاحظة جديدة',
    'analytics_title': 'إحصائيات الاستيعاب والتركيز',
    'forecast_30d': 'توقع عبء المراجعة لـ 30 يوماً',
    'heatmap_title': 'خريطة الالتزام اليومية',
    'export_csv': 'تصدير CSV',
    'encrypted_backup': 'نسخ احتياطي مشفّر (AES-256-GCM)',
  };

  static AppStrings forLanguage(String code, [Map<String, String>? loadedJson]) {
    if (loadedJson != null && loadedJson.isNotEmpty) {
      return AppStrings(code, loadedJson);
    }
    if (code == 'ar') {
      return const AppStrings('ar', _arabicPack);
    }
    return AppStrings(code, _fallbackEn);
  }
}

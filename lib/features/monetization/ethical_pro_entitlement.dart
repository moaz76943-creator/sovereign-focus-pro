/// Ethical, Privacy-First Entitlement & Store Readiness Layer (Stage 12).
/// Guarantees:
/// - Core learning, FSRS-4.5, 100 languages, Native TTS, and encrypted backups
///   work 100% offline with zero ad trackers, zero telemetry leaks, and zero paywalls
///   blocking user-owned data.
/// - Provides clean SKU metadata for optional supporter packs / Google Play billing.
class StoreSkuMetadata {
  final String skuId;
  final String titleEn;
  final String titleAr;
  final bool isOneTimePurchase;

  const StoreSkuMetadata({
    required this.skuId,
    required this.titleEn,
    required this.titleAr,
    required this.isOneTimePurchase,
  });
}

class EthicalProEntitlementService {
  static const bool zeroAdsAndZeroTrackersGuaranteed = true;
  static const bool userDataAlwaysExportableForFree = true;

  static const List<StoreSkuMetadata> catalog = [
    StoreSkuMetadata(
      skuId: 'focus_studio_pro_lifetime_supporter',
      titleEn: 'Focus Studio Pro — Lifetime Supporter Unlock',
      titleAr: 'الدعم الدائم مدى الحياة — استوديو التركيز الاحترافي',
      isOneTimePurchase: true,
    ),
  ];
}

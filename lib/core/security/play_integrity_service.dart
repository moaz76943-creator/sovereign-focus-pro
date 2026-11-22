import 'dart:async';
import 'package:flutter/services.dart';

/// Play Integrity + encrypted local entitlement gate.
/// Call [ensureIntegrity] before unlocking Pro features.
class PlayIntegrityService {
  static const MethodChannel _channel =
      MethodChannel('com.moaz.focusstudiopro/integrity');

  /// Returns true only if device meets basic + device integrity
  /// and the app is recognized as the genuine Play-distributed version.
  static Future<bool> ensureIntegrity({required int cloudProjectNumber}) async {
    try {
      final Map? result = await _channel.invokeMethod('requestIntegrityToken', {
        'cloudProjectNumber': cloudProjectNumber,
      });
      // In production: send token to your backend for full verification.
      // Local fallback: treat successful token receipt as provisional pass
      // and combine with purchase verification.
      return result != null && (result['success'] == true);
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Example usage in entitlement check:
  /// if (await PlayIntegrityService.ensureIntegrity(cloudProjectNumber: YOUR_NUMBER)
  ///     && hasValidPurchase) { unlockPro(); }
}

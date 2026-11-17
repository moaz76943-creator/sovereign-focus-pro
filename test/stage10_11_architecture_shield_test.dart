import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_studio_pro/core/architecture/plugin_feature_bus.dart';

void main() {
  test('SafeFeatureBus isolates module faults without crashing host app', () {
    final bus = SafeFeatureBus();
    bus.registerModule(const FeatureModuleDescriptor(
      id: 'experimental_studio',
      titleKey: 'studios_menu',
      enabledByDefault: true,
    ));

    final result = bus.runIsolated<String>(
      moduleId: 'experimental_studio',
      action: () {
        throw StateError('Simulated plugin error');
      },
      fallbackValue: 'SAFE_FALLBACK',
      autoDisableOnCrash: true,
    );

    expect(result, 'SAFE_FALLBACK');
    expect(bus.isEnabled('experimental_studio'), isFalse);
    expect(bus.isolatedFaultLog.length, 1);
  });

  test('Pre-commit security & 100-language shield passes on repository tree', () {
    final res = Process.runSync('python3', ['tools/pre_commit_shield.py']);
    expect(res.exitCode, 0, reason: 'Shield failed: ${res.stderr}');
  });
}

/// Zero-Regression Feature Flag & Studio Plugin Bus.
/// Allows adding, toggling, or isolating any future Studio or feature module
/// without modifying existing tabs, database tables, or core UI.
/// If a plugin throws an unexpected runtime error, the bus catches and isolates
/// the fault so the rest of the app continues running smoothly.
class FeatureModuleDescriptor {
  final String id;
  final String titleKey;
  final bool enabledByDefault;
  final int schemaRequirement;

  const FeatureModuleDescriptor({
    required this.id,
    required this.titleKey,
    this.enabledByDefault = true,
    this.schemaRequirement = 1,
  });
}

class SafeFeatureBus {
  final Map<String, FeatureModuleDescriptor> _modules = {};
  final Map<String, bool> _overrides = {};
  final List<String> _isolatedFaultLog = [];

  List<String> get isolatedFaultLog => List.unmodifiable(_isolatedFaultLog);

  void registerModule(FeatureModuleDescriptor descriptor) {
    _modules[descriptor.id] = descriptor;
  }

  bool isEnabled(String moduleId) {
    if (_overrides.containsKey(moduleId)) {
      return _overrides[moduleId]!;
    }
    return _modules[moduleId]?.enabledByDefault ?? false;
  }

  void setModuleEnabled(String moduleId, bool enabled) {
    _overrides[moduleId] = enabled;
  }

  /// Executes `action` inside a fault-isolated boundary.
  /// If `action` throws, records the fault, disables only the offending module if requested,
  /// and returns `fallbackValue` so the user's session is never crashed.
  T runIsolated<T>({
    required String moduleId,
    required T Function() action,
    required T fallbackValue,
    bool autoDisableOnCrash = false,
  }) {
    if (!isEnabled(moduleId)) {
      return fallbackValue;
    }
    try {
      return action();
    } catch (e) {
      _isolatedFaultLog.add('[$moduleId] ${e.runtimeType}: $e');
      if (autoDisableOnCrash) {
        _overrides[moduleId] = false;
      }
      return fallbackValue;
    }
  }
}

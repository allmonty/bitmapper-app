import '../models/preset.dart';

/// Persistence for the user's presets (built-ins are never stored).
abstract class PresetRepository {
  Future<List<AppPreset>> load();
  Future<void> save(List<AppPreset> presets);
}

/// Keeps presets in memory only; used in tests and as a fallback.
class InMemoryPresetRepository implements PresetRepository {
  InMemoryPresetRepository([List<AppPreset> initial = const []]) : _presets = List.of(initial);

  List<AppPreset> _presets;
  int saves = 0;

  @override
  Future<List<AppPreset>> load() async => List.of(_presets);

  @override
  Future<void> save(List<AppPreset> presets) async {
    saves++;
    _presets = List.of(presets);
  }
}

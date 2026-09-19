import 'dart:math';

import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter/foundation.dart';

import '../repositories/preset_repository.dart';
import 'labels.dart';
import 'preset.dart';

/// The user's saved presets (newest first) followed by the built-ins (from
/// `bitmapper_core`, read-only).
class PresetsModel extends ChangeNotifier {
  PresetsModel(this._repository, {Random? random}) : _random = random ?? Random();

  final PresetRepository _repository;
  final Random _random;

  static final List<AppPreset> builtIns = [
    for (final id in listPresets())
      AppPreset(
        id: 'builtin:$id',
        name: kPresetLabels[id] ?? id,
        config: getPreset(id),
        builtIn: true,
        columns: presetColumns(id),
      ),
  ];

  List<AppPreset> _user = const [];
  List<AppPreset> get userPresets => _user;
  List<AppPreset> get all => [..._user, ...builtIns];

  AppPreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    _user = await _repository.load();
    notifyListeners();
  }

  Future<AppPreset> add(String name, BitmapFilterConfig config) async {
    final id = 'user:${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}';
    final preset = AppPreset(id: id, name: name.trim(), config: config);
    _user = [preset, ..._user];
    notifyListeners();
    await _repository.save(_user);
    return preset;
  }

  Future<void> rename(String id, String name) async {
    _user = [for (final p in _user) p.id == id ? p.copyWith(name: name.trim()) : p];
    notifyListeners();
    await _repository.save(_user);
  }

  Future<void> remove(String id) async {
    _user = _user.where((p) => p.id != id).toList();
    notifyListeners();
    await _repository.save(_user);
  }
}

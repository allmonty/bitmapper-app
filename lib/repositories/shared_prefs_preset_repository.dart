import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preset.dart';
import 'preset_repository.dart';

/// Stores user presets as a list of JSON strings under [key].
class SharedPrefsPresetRepository implements PresetRepository {
  SharedPrefsPresetRepository({this.key = 'user_presets'});

  final String key;

  @override
  Future<List<AppPreset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? const [];
    final presets = <AppPreset>[];
    for (final entry in raw) {
      try {
        presets.add(AppPreset.fromJson((jsonDecode(entry) as Map).cast<String, Object?>()));
      } catch (e) {
        // Skip a corrupt entry rather than losing every preset.
        debugPrint('Skipping unreadable preset: $e');
      }
    }
    return presets;
  }

  @override
  Future<void> save(List<AppPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, [for (final p in presets) jsonEncode(p.toJson())]);
  }
}

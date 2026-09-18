import 'package:bitmapper_core/bitmapper_core.dart';

/// A named filter configuration. Built-ins come from `bitmapper_core` and
/// are read-only; user presets are persisted by a `PresetRepository`.
class AppPreset {
  const AppPreset({
    required this.id,
    required this.name,
    required this.config,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final BitmapFilterConfig config;
  final bool builtIn;

  AppPreset copyWith({String? name}) =>
      AppPreset(id: id, name: name ?? this.name, config: config, builtIn: builtIn);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'config': config.toJson()};

  factory AppPreset.fromJson(Map<String, Object?> json) => AppPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    config: BitmapFilterConfig.fromJson((json['config'] as Map).cast<String, Object?>()),
  );
}

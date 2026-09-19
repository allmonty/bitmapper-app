import 'package:bitmapper/models/editor_model.dart';
import 'package:bitmapper/models/labels.dart';
import 'package:bitmapper/models/preset.dart';
import 'package:bitmapper/models/presets_model.dart';
import 'package:bitmapper/repositories/preset_repository.dart';
import 'package:bitmapper/repositories/shared_prefs_preset_repository.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PresetsModel', () {
    late InMemoryPresetRepository repo;
    late PresetsModel model;

    setUp(() async {
      repo = InMemoryPresetRepository();
      model = PresetsModel(repo);
      await model.load();
    });

    test('lists user presets before the built-ins', () async {
      expect(PresetsModel.builtIns, hasLength(listPresets().length));
      expect(model.all.every((p) => p.builtIn), isTrue);
      expect(model.userPresets, isEmpty);
      await model.add('Mine', kDefaultConfig);
      expect(model.all.first.name, 'Mine');
      expect(model.all.skip(1).every((p) => p.builtIn), isTrue);
      expect(model.all.map((p) => p.name), contains('Game Boy Camera'));
    });

    test('add puts the newest first and persists', () async {
      await model.add(' First ', kDefaultConfig);
      final second = await model.add('Second', kDefaultConfig.copyWith(bitDepth: 2));
      expect(model.userPresets.map((p) => p.name), ['Second', 'First']);
      expect(model.byId(second.id)?.config.bitDepth, 2);
      expect(repo.saves, 2);
      expect((await repo.load()).map((p) => p.name), ['Second', 'First']);
    });

    test('ids are unique', () async {
      final a = await model.add('A', kDefaultConfig);
      final b = await model.add('B', kDefaultConfig);
      expect(a.id, isNot(b.id));
    });

    test('rename and remove', () async {
      final p = await model.add('Old', kDefaultConfig);
      await model.rename(p.id, 'New');
      expect(model.byId(p.id)?.name, 'New');
      await model.remove(p.id);
      expect(model.byId(p.id), isNull);
      expect(await repo.load(), isEmpty);
    });

    test('load restores saved presets', () async {
      final seeded = InMemoryPresetRepository([
        AppPreset(id: 'user:x', name: 'Saved', config: kDefaultConfig),
      ]);
      final m = PresetsModel(seeded);
      var notified = false;
      m.addListener(() => notified = true);
      await m.load();
      expect(m.userPresets.single.name, 'Saved');
      expect(notified, isTrue);
    });
  });

  group('SharedPrefsPresetRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('empty storage loads no presets', () async {
      expect(await SharedPrefsPresetRepository().load(), isEmpty);
    });

    test('round-trips presets with their full config', () async {
      final repo = SharedPrefsPresetRepository();
      const config = BitmapFilterConfig(
        gridCols: 77,
        paletteMode: PaletteMode.custom,
        customPalette: [0x112233, 0x445566],
        dither: 'sierra',
        scanlines: 0.5,
      );
      await repo.save([
        const AppPreset(id: 'user:1', name: 'One', config: config),
        AppPreset(id: 'user:2', name: 'Two', config: kDefaultConfig),
      ]);
      final loaded = await SharedPrefsPresetRepository().load();
      expect(loaded.map((p) => p.name), ['One', 'Two']);
      expect(loaded.first.config, config);
      expect(loaded.first.builtIn, isFalse);
    });

    test('skips corrupt entries', () async {
      SharedPreferences.setMockInitialValues({
        'user_presets': ['not json', '{"id":"user:ok","name":"Good","config":{"bitDepth":3}}'],
      });
      final loaded = await SharedPrefsPresetRepository().load();
      expect(loaded.single.name, 'Good');
      expect(loaded.single.config.bitDepth, 3);
    });
  });

  test('every palette, dither and preset has a display name', () {
    for (final id in listPalettes()) {
      expect(kPaletteLabels, contains(id), reason: id);
    }
    for (final id in listDitherMethods()) {
      expect(kDitherLabels, contains(id), reason: id);
    }
    for (final id in listPresets()) {
      expect(kPresetLabels, contains(id), reason: id);
    }
  });
}

import 'dart:async';

import 'package:bitmapper/models/editor_model.dart';
import 'package:bitmapper/services/filter_controller.dart';
import 'package:bitmapper_core/bitmapper_core.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A runner whose jobs complete only when the test says so.
class ControlledRunner {
  final jobs = <FilterJob>[];
  final _completers = <Completer<FilterResult>>[];

  Future<FilterResult> call(FilterJob job) {
    jobs.add(job);
    final c = Completer<FilterResult>();
    _completers.add(c);
    return c.future;
  }

  void complete(int index) => _completers[index].complete(
    FilterResult(
      output: jobs[index].source,
      grid: jobs[index].source,
      palette: jobs[index].source.data,
    ),
  );

  void fail(int index) => _completers[index].completeError(StateError('boom'));
}

void main() {
  final a = gradient(8, 6);
  final b = gradient(6, 8);
  const debounce = Duration(milliseconds: 100);

  test('debounces bursts of requests into one run with the latest config', () {
    fakeAsync((async) {
      final runner = ControlledRunner();
      final controller = FilterController(runner: runner.call, debounce: debounce);
      for (var i = 1; i <= 5; i++) {
        controller.request(a, kDefaultConfig.copyWith(bitDepth: i));
        async.elapse(const Duration(milliseconds: 20));
      }
      expect(runner.jobs, isEmpty);
      expect(controller.busy, isTrue);
      async.elapse(debounce);
      expect(runner.jobs, hasLength(1));
      expect(runner.jobs.single.config.bitDepth, 5);
      // Previews render just the grid: one pixel per cell, no gaps/scanlines.
      final job = runner.jobs.single;
      expect(
        (job.outputWidth, job.outputHeight),
        (kDefaultConfig.gridCols, kDefaultConfig.gridRows),
      );
      expect(job.config.gridGapPx, 0);
      expect(job.config.scanlines, 0);
      runner.complete(0);
      async.flushMicrotasks();
      expect(controller.result, isNotNull);
      expect(controller.busy, isFalse);
      expect(controller.lastDuration, isNotNull);
    });
  });

  test('only one run in flight; the latest pending request runs next', () {
    fakeAsync((async) {
      final runner = ControlledRunner();
      final controller = FilterController(runner: runner.call, debounce: debounce);
      controller.request(a, kDefaultConfig.copyWith(bitDepth: 1));
      async.elapse(debounce);
      expect(runner.jobs, hasLength(1));

      controller.request(a, kDefaultConfig.copyWith(bitDepth: 2));
      async.elapse(debounce);
      controller.request(a, kDefaultConfig.copyWith(bitDepth: 3));
      async.elapse(debounce);
      expect(runner.jobs, hasLength(1), reason: 'still waiting on the first run');

      runner.complete(0);
      async.flushMicrotasks();
      expect(runner.jobs, hasLength(2));
      expect(runner.jobs[1].config.bitDepth, 3, reason: 'bitDepth 2 was superseded');
      expect(controller.busy, isTrue);
      runner.complete(1);
      async.flushMicrotasks();
      expect(controller.busy, isFalse);
    });
  });

  test('drops results for a source that was replaced', () {
    fakeAsync((async) {
      final runner = ControlledRunner();
      final controller = FilterController(runner: runner.call, debounce: debounce);
      controller.request(a, kDefaultConfig);
      async.elapse(debounce);
      controller.request(b, kDefaultConfig); // new image while `a` renders
      runner.complete(0);
      async.flushMicrotasks();
      expect(controller.result, isNull, reason: 'result for the old image is stale');
      async.elapse(debounce);
      runner.complete(1);
      async.flushMicrotasks();
      expect(identical(controller.result!.output, b), isTrue);
    });
  });

  test('clear cancels pending work and drops in-flight results', () {
    fakeAsync((async) {
      final runner = ControlledRunner();
      final controller = FilterController(runner: runner.call, debounce: debounce);
      controller.request(a, kDefaultConfig);
      async.elapse(debounce);
      controller.clear();
      runner.complete(0);
      async.flushMicrotasks();
      expect(controller.result, isNull);

      controller.request(a, kDefaultConfig);
      controller.clear();
      async.elapse(debounce * 2);
      expect(runner.jobs, hasLength(1), reason: 'the cleared request never ran');
      expect(controller.busy, isFalse);
    });
  });

  test('reports errors and recovers on the next run', () {
    fakeAsync((async) {
      final runner = ControlledRunner();
      final controller = FilterController(runner: runner.call, debounce: debounce);
      controller.request(a, kDefaultConfig);
      async.elapse(debounce);
      runner.fail(0);
      async.flushMicrotasks();
      expect(controller.error, isA<StateError>());
      expect(controller.busy, isFalse);

      controller.request(a, kDefaultConfig.copyWith(bitDepth: 2));
      async.elapse(debounce);
      runner.complete(1);
      async.flushMicrotasks();
      expect(controller.error, isNull);
      expect(controller.result, isNotNull);
    });
  });

  test('notifies listeners as work starts and finishes', () {
    fakeAsync((async) {
      final runner = ControlledRunner();
      final controller = FilterController(runner: runner.call, debounce: debounce);
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.request(a, kDefaultConfig);
      async.elapse(debounce);
      runner.complete(0);
      async.flushMicrotasks();
      expect(notifications, greaterThanOrEqualTo(3));
    });
  });

  test('renderFull runs immediately at the source size', () async {
    final controller = FilterController(runner: syncRunner);
    final result = await controller.renderFull(
      gradient(40, 30),
      kDefaultConfig.copyWith(gridCols: 10, gridRows: 8, gridGapPx: 1),
    );
    expect(result.output.width, 40);
    expect(result.output.height, 30);
    expect(result.grid.width, 10);
  });

  test('the default runner uses a background isolate', () async {
    final result = await runInIsolate(
      FilterJob(
        source: gradient(20, 10),
        config: const BitmapFilterConfig(gridCols: 5, gridRows: 3, bitDepth: 2),
        outputWidth: 30,
        outputHeight: 15,
      ),
    );
    expect(result.output.width, 30);
    expect(result.paletteSize, 4);
  });
}

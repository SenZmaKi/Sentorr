import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/preview/controller.dart';
import 'package:sentorr/player/preview/extractor.dart';

class FakeExtractor extends PreviewExtractor {
  final calls = <Duration>[];
  final pending = <Completer<Uint8List?>>[];
  @override
  Future<Uint8List?> extract(String source, Duration target) {
    calls.add(target);
    framePosition = target - const Duration(seconds: 1);
    final next = Completer<Uint8List?>();
    pending.add(next);
    return next.future;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'stats count extraction, cache hits and failures without logging',
    (tester) async {
      final extractor = FakeExtractor();
      final controller = PreviewController(
        source: () => 'local',
        allowed: () => true,
        extractor: extractor,
      );
      expect(controller.metrics['averageExtractionMs'], isNull);
      controller.request(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 181));
      expect(controller.metrics['busy'], true);
      extractor.pending.last.complete(Uint8List.fromList([1, 2]));
      await tester.pump();
      expect(controller.metrics['attempts'], 1);
      expect(controller.metrics['cacheBytes'], 2);
      expect(controller.metrics['lastExtractionMs'], isA<int>());
      expect(controller.metrics['lastRequestMs'], isA<int>());
      controller.request(null);
      controller.request(const Duration(seconds: 11));
      expect(controller.metrics['cacheHits'], 1);
      controller.request(const Duration(seconds: 20));
      await tester.pump(const Duration(milliseconds: 181));
      extractor.pending.last.complete(null);
      await tester.pump();
      expect(controller.metrics['attempts'], 2);
      expect(controller.metrics['failures'], 1);
      expect(controller.metrics['busy'], false);
      controller.dispose();
    },
  );

  testWidgets(
    'availability is checked after retaining and ignores obsolete results',
    (tester) async {
      final extractor = FakeExtractor();
      final checks = <int, Completer<bool?>>{};
      final controller = PreviewController(
        source: () => 'local',
        allowed: () => true,
        extractor: extractor,
        available: (target) => target.inSeconds == 10
            ? true
            : checks.putIfAbsent(target.inSeconds, Completer<bool?>.new).future,
      );
      controller.request(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 181));
      extractor.pending.last.complete(Uint8List.fromList([1]));
      await tester.pump();
      controller.request(const Duration(seconds: 16));
      expect(controller.value, [1]);
      await tester.pump(const Duration(milliseconds: 181));
      expect(controller.value, [1]); // Held while validation is pending.
      controller.request(const Duration(seconds: 21));
      checks[15]!.complete(false); // Belongs to a position already left.
      await tester.pump();
      expect(controller.value, [1]);
      await tester.pump(const Duration(milliseconds: 181));
      checks[20]!.complete(false);
      await tester.pump();
      expect(controller.value, isNull);
      expect(extractor.calls.length, 1); // Missing region never decoded.
      controller.request(const Duration(seconds: 11));
      expect(controller.value, [1]);
      controller.request(const Duration(seconds: 26));
      await tester.pump(const Duration(milliseconds: 181));
      checks[25]!.complete(null); // Unknown coverage retains while decoding.
      await tester.pump();
      expect(controller.value, [1]);
      expect(extractor.calls.last, const Duration(seconds: 25));
      extractor.pending.last.complete(Uint8List.fromList([2]));
      await tester.pump();
      expect(controller.value, [2]);
      controller.dispose();
    },
  );

  testWidgets(
    'five-second buckets hold the last preview across short and far moves',
    (tester) async {
      final extractor = FakeExtractor();
      var source = 'first';
      final controller = PreviewController(
        source: () => source,
        allowed: () => true,
        extractor: extractor,
      );
      controller.request(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 181));
      expect(extractor.calls.single, const Duration(seconds: 10));
      extractor.pending.last.complete(Uint8List.fromList([1]));
      await tester.pump();
      final changes = <List<int>?>[];
      controller.addListener(() => changes.add(controller.value));
      controller.request(const Duration(seconds: 16));
      expect(controller.value, [1]);
      expect(controller.framePosition, const Duration(seconds: 9));
      await tester.pump(const Duration(milliseconds: 181));
      expect(extractor.calls.last, const Duration(seconds: 15));
      extractor.pending.last.complete(Uint8List.fromList([2]));
      await tester.pump();
      expect(controller.value, [2]);
      expect(changes, isNotEmpty);
      expect(changes.every((image) => image != null), isTrue);
      expect(changes.last, [2]); // Target changes never empty the image.
      controller.request(const Duration(seconds: 21));
      expect(controller.value, [2]);
      // Moving within a new bucket keeps the previously displayed image.
      controller.request(const Duration(seconds: 22));
      expect(controller.value, [2]);
      controller.request(const Duration(seconds: 2001));
      expect(controller.value, [2]);
      controller.request(const Duration(seconds: 16));
      expect(controller.value, [2]);
      source = 'second';
      controller.request(const Duration(seconds: 16));
      expect(controller.value, isNull);
      controller.dispose();
    },
  );

  testWidgets('extraction failures retain the image until the pointer leaves', (
    tester,
  ) async {
    final extractor = FakeExtractor();
    final controller = PreviewController(
      source: () => 'local',
      allowed: () => true,
      extractor: extractor,
    );
    controller.request(const Duration(seconds: 11));
    await tester.pump(const Duration(milliseconds: 181));
    extractor.pending.last.complete(Uint8List.fromList([1]));
    await tester.pump();
    controller.request(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 181));
    expect(controller.value, [1]);
    extractor.pending.last.complete(null);
    await tester.pump();
    expect(controller.value, [1]);
    controller.request(const Duration(seconds: 11));
    expect(controller.value, [1]);
    controller.request(const Duration(seconds: 21));
    await tester.pump(const Duration(milliseconds: 181));
    controller.request(null);
    expect(controller.value, isNull);
    extractor.pending.last.complete(Uint8List.fromList([3]));
    await tester.pump();
    expect(controller.value, isNull);
    controller.dispose();
  });

  testWidgets('precise requests retain the pointer timestamp', (tester) async {
    final extractor = FakeExtractor();
    final controller = PreviewController(
      source: () => 'local',
      allowed: () => true,
      extractor: extractor,
      bucket: const Duration(milliseconds: 1),
    );
    controller.request(const Duration(milliseconds: 12345));
    await tester.pump(const Duration(milliseconds: 181));
    expect(extractor.calls.single, const Duration(milliseconds: 12345));
    extractor.pending.single.complete(Uint8List.fromList([1]));
    await tester.pump();
    controller.dispose();
  });

  testWidgets(
    'debounces within buckets, serializes and discards stale results',
    (tester) async {
      final diagnostics = <Map<String, Object?>>[];
      final extractor = FakeExtractor();
      final controller = PreviewController(
        source: () => 'local',
        allowed: () => true,
        extractor: extractor,
        onDiagnostic: diagnostics.add,
      );
      controller.request(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 100));
      controller.request(const Duration(seconds: 12));
      await tester.pump(const Duration(milliseconds: 81));
      expect(extractor.calls, [const Duration(seconds: 10)]);
      controller.request(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 200));
      expect(extractor.calls.length, 1);
      extractor.pending.first.complete(Uint8List.fromList([1]));
      await tester.pump();
      expect(controller.value, isNull);
      await tester.pump(const Duration(milliseconds: 180));
      expect(extractor.calls.last, const Duration(seconds: 30));
      extractor.pending.last.complete(Uint8List.fromList([2]));
      await tester.pump();
      expect(controller.value, [2]);
      controller.request(const Duration(seconds: 11));
      expect(controller.value, [1]);
      expect(controller.hits, 1);
      expect(diagnostics.where((e) => e['event'] == 'start').length, 2);
      final ends = diagnostics.where((e) => e['event'] == 'end').toList();
      expect(ends.first['displayed'], isFalse);
      expect(ends.last['displayed'], isTrue);
      expect(controller.framePosition, const Duration(seconds: 9));
      controller.dispose();
    },
  );
}

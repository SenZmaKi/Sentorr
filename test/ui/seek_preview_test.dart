import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/seek_track.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

void main() {
  final image = File('assets/images/sentorr-icon.png').readAsBytesSync();
  for (final brightness in Brightness.values) {
    for (final width in [160.0, 600.0]) {
      testWidgets('seek preview stays inside $width track in $brightness', (
        tester,
      ) async {
        for (final fraction in [0.0, 1.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildSentorrTheme(brightness),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    key: const Key('track'),
                    width: width,
                    height: 300,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SeekTimeBubble(
                          image: image,
                          label: '7:38',
                          x: width * fraction,
                          width: width,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final track = tester.getRect(find.byKey(const Key('track')));
          final thumbnail = tester.getRect(find.byType(Image));
          final time = tester.getRect(find.text('7:38'));
          expect(thumbnail.left, greaterThanOrEqualTo(track.left));
          expect(thumbnail.right, lessThanOrEqualTo(track.right));
          expect(time.top, greaterThan(thumbnail.bottom));
          expect(find.textContaining('preview'), findsNothing);
          final backing = tester
              .widgetList<Container>(find.byType(Container))
              .where(
                (container) =>
                    container.decoration is BoxDecoration &&
                    (container.decoration! as BoxDecoration).color != null,
              )
              .map(
                (container) => (container.decoration! as BoxDecoration).color,
              );
          expect(backing, contains(const Color(0xFF000000)));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}

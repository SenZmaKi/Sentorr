import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/imdb/providers.dart';

import '../support/fake_imdb.dart';

class _Imdb extends FakeImdbRepository {
  int requests = 0;
  Completer<ImdbTitleDetails>? pending;
  CancelToken? token;
  @override
  Future<ImdbTitleDetails> getTitleDetails(
    String id, {
    int previewLimit = 10,
    bool refresh = false,
    CancelToken? cancelToken,
  }) {
    requests++;
    token = cancelToken;
    return pending?.future ?? super.getTitleDetails(id);
  }
}

void main() {
  testWidgets('unused details are released after their request completes', (
    tester,
  ) async {
    final imdb = _Imdb();
    final container = ProviderContainer(
      overrides: [imdbRepositoryProvider.overrideWithValue(imdb)],
    );
    addTearDown(container.dispose);
    final provider = titleDetailsProvider('tt1');
    await container.read(provider.future);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(container.exists(provider), isFalse);
    await container.read(provider.future);
    expect(imdb.requests, 2);
    container.dispose();
  });

  testWidgets(
    'an active title shares its request, then is released when left',
    (tester) async {
      final container = ProviderContainer(
        overrides: [imdbRepositoryProvider.overrideWithValue(_Imdb())],
      );
      addTearDown(container.dispose);
      final provider = titleDetailsProvider('tt1');
      final subscription = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      await tester.pump(const Duration(minutes: 3));
      expect(container.exists(provider), isTrue);
      subscription.close();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(container.exists(provider), isFalse);
      container.dispose();
    },
  );

  testWidgets('a listener-free queue request stays alive until it completes', (
    tester,
  ) async {
    final imdb = _Imdb()..pending = Completer<ImdbTitleDetails>();
    final container = ProviderContainer(
      overrides: [imdbRepositoryProvider.overrideWithValue(imdb)],
    );
    addTearDown(container.dispose);
    final pending = container.read(titleDetailsProvider('tt1').future);
    await tester.pump();
    await tester.pump();
    expect(imdb.token!.isCancelled, isFalse);
    imdb.pending!.complete(await FakeImdbRepository().getTitleDetails('tt1'));
    expect((await pending).title.id, 'tt1');
    container.dispose();
  });
}

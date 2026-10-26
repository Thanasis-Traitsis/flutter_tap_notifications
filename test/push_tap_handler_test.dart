import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_push_taps/articles/article_repository.dart';
import 'package:flutter_push_taps/navigation/app_router.dart';
import 'package:flutter_push_taps/notifications/push_tap_handler.dart';
import 'package:flutter_push_taps/splash/splash_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Harness {
  _Harness() {
    final articles = ArticleRepository(delay: Duration.zero);
    router = createRouter(articles);
    splashCubit = SplashCubit(
      prepare: () => startup.future,
      minDuration: Duration.zero,
    )..start();
    handler = PushTapHandler(
      router: router,
      splashCubit: splashCubit,
      articleRepository: articles,
      localNotificationTaps: const Stream.empty(),
    );
  }

  final startup = Completer<void>();
  late final GoRouter router;
  late final SplashCubit splashCubit;
  late final PushTapHandler handler;

  String get location => router.routerDelegate.currentConfiguration.uri.path;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Map<String, dynamic> data) async {
    unawaited(handler.handleTap(data));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('waits for the splash flow before navigating', (tester) async {
    final app = _Harness();
    await app.pump(tester);

    await app.tap(tester, {'type': 'schedule'});
    expect(app.location, '/live');

    app.startup.complete();
    await tester.pumpAndSettle();
    expect(app.location, '/schedule');
  });

  testWidgets('navigates right away when the app is already ready', (
    tester,
  ) async {
    final app = _Harness()..startup.complete();
    await app.pump(tester);

    await app.tap(tester, {'type': 'schedule'});

    expect(app.location, '/schedule');
  });

  testWidgets('fetches the article, then pushes its details', (tester) async {
    final app = _Harness()..startup.complete();
    await app.pump(tester);

    await app.tap(tester, {'type': 'article', 'reference_id': '2'});

    expect(find.text('New morning show starts next week'), findsOneWidget);
  });

  testWidgets('ignores missing articles and unknown types', (tester) async {
    final app = _Harness()..startup.complete();
    await app.pump(tester);

    await app.tap(tester, {'type': 'article', 'reference_id': '404'});
    await app.tap(tester, {'type': 'something_new'});
    await app.tap(tester, {});

    expect(app.location, '/live');
  });
}

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../articles/article_repository.dart';
import '../navigation/app_routes.dart';
import '../splash/splash_cubit.dart';
import 'notification_type.dart';

class PushTapHandler {
  PushTapHandler({
    required GoRouter router,
    required SplashCubit splashCubit,
    required ArticleRepository articleRepository,
    required Stream<String?> localNotificationTaps,
  }) : _router = router,
       _splashCubit = splashCubit,
       _articleRepository = articleRepository,
       _localNotificationTaps = localNotificationTaps;

  final GoRouter _router;
  final SplashCubit _splashCubit;
  final ArticleRepository _articleRepository;
  final Stream<String?> _localNotificationTaps;

  void listen() {
    // App was dead: the tap is what launched it.
    _handleInitialMessage();

    // App was in the background: the tap brings it back.
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => handleTap(message.data),
    );

    // App was open: we showed the push ourselves (Android).
    _localNotificationTaps.listen(_handleLocalNotificationTap);
  }

  Future<void> _handleInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) return;

    await handleTap(message.data);
  }

  void _handleLocalNotificationTap(String? payload) {
    if (payload == null) return;

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    handleTap(data);
  }

  @visibleForTesting
  Future<void> handleTap(Map<String, dynamic> data) async {
    await _waitUntilAppReady();
    await _navigate(data);
  }

  Future<void> _waitUntilAppReady() {
    // A Cubit's stream doesn't replay the current state, so check it first.
    if (_splashCubit.state is SplashReady) return Future.value();
    return _splashCubit.stream.firstWhere((state) => state is SplashReady);
  }

  Future<void> _navigate(Map<String, dynamic> data) async {
    final type = NotificationType.values.asNameMap()[data['type']];

    switch (type) {
      case NotificationType.live:
        _router.go(AppRoutes.live);
      case NotificationType.schedule:
        _router.go(AppRoutes.schedule);
      case NotificationType.article:
        final id = data['reference_id'] as String?;
        if (id == null) return;

        final article = await _articleRepository.getById(id);
        if (article == null) return;

        _router.push(AppRoutes.articleDetails, extra: article);
      case null:
        // Unknown type, e.g. sent to an older version of the app.
        return;
    }
  }
}

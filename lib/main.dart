import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'articles/article_repository.dart';
import 'firebase_options.dart';
import 'navigation/app_router.dart';
import 'notifications/notification_service.dart';
import 'notifications/push_tap_handler.dart';
import 'splash/splash_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationService = NotificationService();
  await notificationService.init();

  final articleRepository = ArticleRepository();
  final router = createRouter(articleRepository);
  final splashCubit = SplashCubit(
    prepare: notificationService.requestPermission,
  )..start();

  runApp(
    BlocProvider.value(
      value: splashCubit,
      child: App(router: router),
    ),
  );

  PushTapHandler(
    router: router,
    splashCubit: splashCubit,
    articleRepository: articleRepository,
    localNotificationTaps: notificationService.onTap,
  ).listen();
}

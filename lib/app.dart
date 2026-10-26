import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'splash/splash_cubit.dart';
import 'splash/splash_screen.dart';

class App extends StatelessWidget {
  const App({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(colorSchemeSeed: Colors.indigo);

    // The router only goes on screen once the splash flow is done, which is
    // why notification taps wait for SplashReady before navigating.
    return BlocBuilder<SplashCubit, SplashState>(
      builder: (context, state) => switch (state) {
        SplashLoading() => MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        ),
        SplashReady() => MaterialApp.router(
          theme: theme,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      },
    );
  }
}

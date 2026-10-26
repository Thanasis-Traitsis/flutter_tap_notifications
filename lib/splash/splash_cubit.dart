import 'package:flutter_bloc/flutter_bloc.dart';

sealed class SplashState {
  const SplashState();
}

class SplashLoading extends SplashState {
  const SplashLoading();
}

class SplashReady extends SplashState {
  const SplashReady();
}

class SplashCubit extends Cubit<SplashState> {
  SplashCubit({
    required Future<void> Function() prepare,
    Duration minDuration = const Duration(seconds: 2),
  }) : _prepare = prepare,
       _minDuration = minDuration,
       super(const SplashLoading());

  final Future<void> Function() _prepare;

  // Stands in for real startup work (config, version checks, etc.), so the
  // cold-start race is easy to see.
  final Duration _minDuration;

  Future<void> start() async {
    await Future.wait([_prepare(), Future<void>.delayed(_minDuration)]);
    emit(const SplashReady());
  }
}

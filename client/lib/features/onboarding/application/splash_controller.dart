import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';

final splashControllerProvider =
    Provider<SplashController>((ref) => SplashController(ref));

/// 시작 화면이 이동을 정하려고 읽는 저장소 값을 모았다. 세션 여부는 AuthSessionController 가 준다.
class SplashController {
  SplashController(this._ref);

  final Ref _ref;

  bool get isOnboardingCompleted => _ref.read(localStorageProvider).isOnboardingCompleted;

  bool get isElumiDevice => _ref.read(localStorageProvider).isElumiDevice;
}

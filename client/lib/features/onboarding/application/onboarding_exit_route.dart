import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/router/routes.dart';
import '../../link/application/linked_device_check.dart';
import '../../notification/application/push_permission_prompt.dart';

final onboardingExitRouteProvider = Provider<OnboardingExitRoute>(OnboardingExitRoute.new);

/// 온보딩 끝 순서: 이룸이 기기 연결 단계 > 알림 켜기 안내 > 보호자 홈
/// 비밀암호 저장 뒤 · 초대 코드 합류 뒤 · 연결 단계 뒤가 모두 여기서 다음 자리를 받음
class OnboardingExitRoute {
  OnboardingExitRoute(this._ref);

  final Ref _ref;

  /// 이룸이가 준비된 직후: 기기가 이미 붙어 있으면 연결 단계 건너뜀 (모르면 보여 줌, 건너뛸 수 있는 단계)
  Future<String> resolveAfterProfileReady() async {
    final bool? hasDevice;
    try {
      hasDevice = await _ref.read(linkedDeviceCheckProvider)();
    } catch (e, stack) {
      AppLogger.error('onboarding', e, stack, {'step': 'linkCheck'});
      return Routes.onboardingLinkDevice;
    }
    if (hasDevice == true) return resolveAfterLinkStep();
    return Routes.onboardingLinkDevice;
  }

  /// 연결 단계를 지난 뒤 (연결함 · 나중에): 알림 안내 차례면 안내, 아니면 홈
  Future<String> resolveAfterLinkStep() =>
      _ref.read(pushPermissionPromptProvider).resolveRouteAfterOnboarding();
}

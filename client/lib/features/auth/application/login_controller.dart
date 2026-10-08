import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../../child/application/child_routine_notifier.dart';
import '../../member/application/member_providers.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../profile/application/profile_session.dart';
import '../data/auth_repository.dart';
import '../data/oauth_sdk.dart';
import 'account_reset.dart';

final loginControllerProvider =
    Provider<LoginController>((ref) => LoginController(ref));

/// 로그인 화면이 쓰는 저장소·provider 호출을 모았다. 화면 분기와 mounted 확인은 화면이 한다.
class LoginController {
  LoginController(this._ref);

  final Ref _ref;

  /// 마지막으로 로그인한 제공자 이름.
  String? lastLoginProviderName() => _ref.read(localStorageProvider).lastLoginProvider;

  Future<AuthResult> signIn(OAuthProvider provider) =>
      _ref.read(authRepositoryProvider).signInWith(provider);

  /// 로그인 성공 뒤 이전 계정의 메모리 상태를 버린다.
  Future<void> resetPreviousAccount() async {
    _ref.invalidate(memberProvider);
    _ref.invalidate(profileSessionProvider);
    // 이룸이 설정도 이전 계정 값이라 함께 비운다
    _ref.invalidate(onboardingProvider);
    // 일과 목록도 이전 계정 것이다
    _ref.forgetPreviousAccountRoutines();
    // 메모리 큐까지 상속하지 않는다. 같은 계정은 로컬 큐에서 복원한다.
    _ref.invalidate(childRoutineProvider);
    await _ref.read(childRoutineProvider.notifier).hydrate();
  }

  /// 이전 계정의 이룸이 정보를 메모리에서 잊는다.
  void forgetPreviousChild() => _ref.invalidate(onboardingProvider);

  Future<bool> hasPin() => _ref.read(localStorageProvider).hasPin();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_role.dart';
import 'app_router.dart';
import '../storage/local_storage.dart';

/// 지금 상태의 홈. 앱 시작과 뒤로가기 안전망([PopOrHome])이 같은 판단을 쓴다.
String homeFor(ProviderContainer c) {
  final storage = c.read(localStorageProvider);
  return resolveDestination(
    hasSession: c.read(authRepositoryProvider).hasSession,
    onboardingCompleted: storage.isOnboardingCompleted,
    isElumiDevice: storage.isElumiDevice,
    selectedRole: storage.selectedRole,
    resumeOnElumiScreen: storage.resumeOnElumiScreen,
  );
}

/// 상태별 시작 자리.
///
/// 역할([selectedRole])과 연결 여부([isElumiDevice])는 **다른 값**이다.
/// 역할은 고른 순간, 연결은 성공한 순간 정해진다. 역할만 고르고 연결하지 않은
/// 채로 앱을 닫는 사람이 있으므로 둘을 따로 본다.
String resolveDestination({
  required bool hasSession,
  required bool onboardingCompleted,
  required bool isElumiDevice,
  required String? selectedRole,

  /// 보호자 휴대폰이 마지막에 이룸이 화면에 있었는가.
  bool resumeOnElumiScreen = false,
}) {
  if (!hasSession) {
    // 연결로 붙는 이룸이 휴대폰은 연결 화면에서 다시 시작한다
    return isElumiDevice ? Routes.linkEnter : Routes.login;
  }
  if (isElumiDevice) return Routes.child;

  // 보호자가 이룸이 화면으로 넘겨 준 채 앱이 꺼졌다. 보호자 홈을 열면 이룸이가 암호 없이
  // 보호자 화면을 보게 되므로, 넘겨 준 자리로 되돌린다.
  final home = resumeOnElumiScreen ? Routes.child : Routes.guardian;

  final role = AppRole.fromStorage(selectedRole);
  return switch (role) {
    // 역할이 없는데 온보딩을 마쳤다면 **역할이 생기기 전에 가입한 보호자**다.
    // 이미 답한 것을 다시 묻지 않는다.
    null => onboardingCompleted ? home : Routes.roleSelect,
    // 이룸이라고는 했는데 아직 연결 전이다
    AppRole.elumi => Routes.linkEnter,
    AppRole.guardian => onboardingCompleted ? home : Routes.onboardingName,
  };
}

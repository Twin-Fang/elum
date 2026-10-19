import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/character.dart';
import '../../member/application/member_providers.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../profile/application/profile_display_name.dart';
import '../../profile/application/profile_session.dart';

/// 보호자 화면이 보여 줄 이룸이 이름 + 캐릭터
@immutable
class GuardianChildIdentity {
  const GuardianChildIdentity({required this.name, required this.character});

  final String name;
  final CardCharacter character;
}

/// 고른 이룸이 이름·캐릭터: 회원 정보 > 고른 프로필 > 온보딩 값 (홈 인사말·태블릿 옆 메뉴 공통)
///
/// 캐릭터를 고르기 전(구버전 데이터 등)은 이룸이 홈과 같은 고양이로 둔다.
final guardianChildIdentityProvider = Provider<GuardianChildIdentity>((ref) {
  final onboarding = ref.watch(onboardingProvider);
  return GuardianChildIdentity(
    name: resolveProfileDisplayName(
      ref.watch(memberProvider).value,
      ref.watch(profileSessionProvider.select((session) => session.selectedId)),
      onboarding.displayName,
    ),
    character: onboarding.cardCharacter ?? CardCharacter.cat,
  );
});

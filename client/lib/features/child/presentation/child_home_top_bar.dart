import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'child_star_badge.dart';

import '../../../core/haptics/child_haptics.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/character_badge.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../../shared/models/character.dart';
import 'mode_switch_screen.dart';
import '../../../core/storage/local_storage.dart';
import '../../member/application/member_providers.dart';
import '../../../core/router/routes.dart';

/// 이룸이 홈 상단 줄. **휴대폰 종류에 따라 시안이 둘이다**.
///
/// | | 보호자 휴대폰 (`425:4392`) | 이룸이 휴대폰 (`1197:6774`) |
/// | --- | --- | --- |
/// | 별 배지 | x247 | x271 |
/// | 오른쪽 끝 | **캐릭터 배지** 56×56 (x313, y70) | **설정 톱니** 24×24 (x345, y86) |
/// | 누르면 | 비밀암호 → 보호자 화면 | 설정 페이지 (`약관` · `앱 정보` · `로그아웃` · `회원탈퇴`) |
///
/// 새 시안(`1197:6774`)은 **이룸이 휴대폰** 것이므로 보호자 휴대폰까지 톱니로 만들면 안 된다.
/// 보호자 휴대폰은 `425:4392` 그대로 캐릭터 배지를 쓴다.
///
/// 이룸이 휴대폰은 보호자 화면에 갈 곳이 없다 — 암호를 맞춰도 라우터가 막는다. 그래서 그 길(비밀암호
/// 화면)로 보내는 버튼 대신 설정을 둔다.
class ChildHomeTopBar extends ConsumerWidget {
  const ChildHomeTopBar({super.key});

  /// 안전영역(59) 아래 여백. 줄 윗변이 시안 y 에 서도록 휴대폰 종류별로 다르다.
  /// - 이룸이 휴대폰: 줄 높이가 별 배지(48)라 윗변이 곧 별 윗변 y74 → 59 + 15
  /// - 보호자 휴대폰: 줄 높이가 캐릭터 배지(56)라 윗변이 배지 윗변 y70 → 59 + 11.
  ///   별(48)은 세로 가운데에 서 y74 가 되고, 로고(30)도 가운데라 y83 이다.
  static const _elumiTop = 15.0;
  static const _guardianTop = 11.0;

  /// 톱니 그림 크기(24)와 누를 자리(48). 아동 화면은 터치 타겟을 넉넉히 잡는다.
  static const _gearIcon = 24.0;
  static const _gearHit = 48.0;

  /// 보호자 휴대폰에서 별 배지 오른쪽 끝(x297)과 캐릭터 배지(x313) 사이.
  static const _starToBadgeGap = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    // 별 개수. 값이 없을 때만 0으로 화면은 뜬다 (docs 원칙 6번).
    // 다시 받는 중이나 갱신 실패에는 마지막 정상 값을 그대로 쓴다 — 0 으로 되돌리지 않는다.
    final stars = ref.watch(memberProvider).value?.totalStars ?? 0;
    final isElumi = ref.watch(localStorageProvider).isElumiDevice;

    // 별 배지 — 탭하면 누적 별 화면으로 (Figma 364:8219)
    final star = AppPressable(
      onTap: () {
        playChildHaptic(context, ChildHapticKind.tap);
        context.push(Routes.childStars);
      },
      scaleDown: AppPressable.scaleIcon,
      // 배지 안 글자는 숫자뿐이라 그대로 두면 "10"만 읽힌다. 무엇이 10인지
      // 붙여 읽힌다 — 이름이 안의 숫자를 덮으므로 두 번 읽히지 않는다.
      semanticLabel: context.l10n.childStarsSemantics(stars),
      child: ChildStarBadge(count: stars),
    );

    if (!isElumi) {
      // 보호자 휴대폰 (425:4392) — 별 + 캐릭터 배지
      // 온보딩에서 고른 캐릭터. 배지 테두리 색이 캐릭터마다 다르다.
      // 아직 안 골랐으면 고양이(루루)로 둔다 — 화면은 떠야 한다.
      final character =
          ref.watch(onboardingProvider).cardCharacter ?? CardCharacter.cat;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          space.screenH,
          _guardianTop,
          space.screenH,
          0,
        ),
        child: Row(
          children: [
            SvgPicture.asset(AppAssets.homeLogo, width: 80.w, height: 30.h),
            const Spacer(),
            star,
            SizedBox(width: _starToBadgeGap.w),
            // 보호자로 돌아가려면 암호가 필요하다
            AppPressable(
              onTap: () {
                playChildHaptic(context, ChildHapticKind.tap);
                context.push(
                  '${Routes.modeSwitch}?to=${ModeSwitchTarget.guardian.name}',
                );
              },
              scaleDown: AppPressable.scaleIcon,
              semanticLabel: context.l10n.childHomeToGuardianLabel,
              // 여우 배지 자르기가 보호자 홈과 같아야 해 공용 위젯을 쓴다
              child: CharacterBadge(character: character),
            ),
          ],
        ),
      );
    }

    // 이룸이 휴대폰 (1197:6774) — 별 + 설정 톱니. 톱니가 별 오른쪽 x345 에 선다.
    // 누를 자리를 그림보다 12 씩 키운 만큼 바깥 여백·간격에서 뺀다.
    // 그림이 시안 자리(별 배지 오른쪽 끝 x321 → 톱니 x345~369)에 그대로 선다.
    const overhang = (_gearHit - _gearIcon) / 2;

    final gear = AppPressable(
      // 보호자 설정처럼 설정 페이지로 간다 (바텀시트가 아니다)
      onTap: () {
        playChildHaptic(context, ChildHapticKind.tap);
        context.push(Routes.childSettings);
      },
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: context.l10n.childHomeSettingsLabel,
      child: SizedBox(
        width: _gearHit.w,
        height: _gearHit.w,
        child: Center(
          child: SvgPicture.asset(
            AppAssets.iconSettings,
            // 정사각형 아이콘 — 가로세로 모두 .w
            width: _gearIcon.w,
            height: _gearIcon.w,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.screenH,
        _elumiTop,
        (space.screenH - overhang).w,
        0,
      ),
      child: Row(
        children: [
          SvgPicture.asset(AppAssets.homeLogo, width: 80.w, height: 30.h),
          const Spacer(),
          star,
          // 시안 별 배지(~x321)와 톱니(x345) 사이 24에서 누를 자리 몫을 뺀다.
          // 누를 자리끼리 12 떨어진다 (docs 7-1: 8 이상).
          SizedBox(width: (space.screenH - overhang).w),
          gear,
        ],
      ),
    );
  }
}

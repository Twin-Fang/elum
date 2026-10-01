import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/character_badge.dart';
import '../../../core/widgets/routine_progress_ring.dart';
import '../../../shared/utils/korean_particle.dart';
import '../../../shared/models/routine.dart';
import '../../guardian/application/routine_notifier.dart';
import '../../guardian/data/routine_repository.dart';
import '../../guardian/presentation/widgets/today_routine_section.dart'
    show routineProgress;
import '../../onboarding/application/onboarding_notifier.dart';
import '../../link/presentation/elumi_settings_sheet.dart';
import '../../onboarding/domain/character.dart';
import '../application/child_routine_notifier.dart';
import 'mode_switch_screen.dart';

/// 아이에게 보여줄 일과 목록.
///
/// `GET /api/routines/today`(이슈 #75)가 오늘 + CONFIRMED/COMPLETED만 준다.
/// 폴백(전체 조회)으로 내려올 수도 있으므로 **승인 여부를 한 번 더 거른다**
/// (docs 원칙 3번). 방금 만든 일과도 승인 전이면 목록에 없다.
final childRoutinesProvider = Provider<List<Routine>>((ref) {
  final current = ref.watch(routineFlowProvider).routine;
  // `.value`는 재조회 중에도 직전 목록을 유지한다 — 동기화 뒤 깜빡임 방지 (이슈 #140)
  final fetched = ref.watch(todayRoutinesProvider).value ?? const <Routine>[];

  return [
    if (current != null && current.isConfirmed && current.steps.isNotEmpty)
      current,
    ...fetched.where(
      (r) => r.id != current?.id && r.isVisibleToChild && r.steps.isNotEmpty,
    ),
  ];
});

/// Figma `아이_홈_리스트`(356:5079) / `아이_홈_아무것도X`(343:4543).
///
/// 일과 **목록**을 보여주고, 탭하면 카드 상세로 들어간다 (이슈 #69).
/// 카드 페이저는 [ChildRoutineDetailScreen]으로 내려갔다.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final routines = ref.watch(childRoutinesProvider);
    final routinesAsync = ref.watch(todayRoutinesProvider);
    final localName = ref.watch(onboardingProvider).displayName;
    final childName = ref
        .watch(memberProvider)
        .maybeWhen(
          data: (member) => member?.nickname ?? localName,
          orElse: () => localName,
        );
    // 온보딩에서 고른 캐릭터. 빈 상태 일러스트가 캐릭터마다 다르다.
    // 아직 안 골랐으면 고양이(루루)로 둔다 — 화면은 떠야 한다.
    final character =
        ref.watch(onboardingProvider).cardCharacter ?? CardCharacter.cat;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: routines.isEmpty
            ? Column(
                children: [
                  const _TopBar(),
                  Expanded(
                    child: _NoRoutine(
                      childName: childName,
                      character: character,
                      // 조회가 실패했으면 제보 추적용 코드를 함께 보여준다.
                      // 아동 화면이라 빨강·경고 아이콘은 쓰지 않는다.
                      // 코드는 실제로 무엇이 터졌는지를 쓴다 — 연결이 끊긴 것과
                      // 서버가 막은 것이 같은 코드로 보이면 제보를 못 가린다 (#352).
                      errorCode: routinesAsync.hasError
                          ? AppFailure.of(
                              routinesAsync.error,
                            ).badgeOr('E-CHLIST')
                          : null,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: EdgeInsets.only(bottom: space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TopBar(),
                    // 시안(1197:6810)은 인사말이 y150 에서 시작한다. 상단 줄 아래(122)에서 28.
                    SizedBox(height: 28.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: space.screenH),
                      child: Text(
                        // Figma 문구 (1197:6810 · 356:5197).
                        //
                        // 조사를 '가'로 박아 두었더니 받침 있는 이름에서 **민준가**가
                        // 나왔다. 이름은 보호자가 직접 적으므로 받침을 보고 고른다.
                        // 시안이 `할 일들이에요. 힘내봐요!`로 바뀌었다 (#445) — 해요체다.
                        '오늘 $childName${childName.subjectParticle}\n할 일들이에요. 힘내봐요!',
                        // 이 화면 인사말은 22다. 빈 상태 제목(24)과 다르다.
                        style: context.typo.childGreeting.copyWith(
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    // 인사말 아래(202) → 첫 타일(242)
                    SizedBox(height: 40.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: space.md),
                      child: _RoutineList(routines: routines),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// 이룸이 홈 상단 줄. **휴대폰 종류에 따라 시안이 둘이다** (#485).
///
/// | | 보호자 휴대폰 (`425:4392`) | 이룸이 휴대폰 (`1197:6774`) |
/// | --- | --- | --- |
/// | 별 배지 | x247 | x271 |
/// | 오른쪽 끝 | **캐릭터 배지** 56×56 (x313, y70) | **설정 톱니** 24×24 (x345, y86) |
/// | 누르면 | 비밀암호 → 보호자 화면 | 설정 시트 (`약관` · `앱 정보` · `로그아웃` · `회원탈퇴`) |
///
/// #445가 이룸이 화면을 새 시안(`1197:6774`)으로 맞출 때 이 시안이 **이룸이 휴대폰** 것이라는 것을 놓쳐
/// 보호자 휴대폰까지 톱니로 만들었다. 보호자 휴대폰은 `425:4392` 그대로 캐릭터 배지를 쓴다.
///
/// 이룸이 휴대폰은 보호자 화면에 갈 곳이 없다 — 암호를 맞춰도 라우터가 막는다. 그래서 그 길(비밀암호
/// 화면)로 보내는 버튼 대신 설정을 둔다 (#363).
class _TopBar extends ConsumerWidget {
  const _TopBar();

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
    // 별 개수. 조회 실패해도 0으로 화면은 뜬다 (docs 원칙 6번)
    final stars = ref
        .watch(memberProvider)
        .maybeWhen(data: (member) => member?.totalStars ?? 0, orElse: () => 0);
    final isElumi = ref.watch(localStorageProvider).isElumiDevice;

    // 별 배지 — 탭하면 누적 별 화면으로 (Figma 364:8219)
    final star = AppPressable(
      onTap: () => context.push(Routes.childStars),
      scaleDown: AppPressable.scaleIcon,
      // 배지 안 글자는 숫자뿐이라 그대로 두면 "10"만 읽힌다. 무엇이 10인지
      // 붙여 읽힌다 — 이름이 안의 숫자를 덮으므로 두 번 읽히지 않는다 (#339).
      semanticLabel: '별 $stars개 모았어요',
      child: _StarBadge(count: stars),
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
              onTap: () => context.push(
                '${Routes.modeSwitch}?to=${ModeSwitchTarget.guardian.name}',
              ),
              scaleDown: AppPressable.scaleIcon,
              semanticLabel: '보호자 화면으로 가기',
              // 여우 배지 자르기(#311)가 보호자 홈과 같아야 해 공용 위젯을 쓴다
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
      onTap: () => ElumiSettingsSheet.show(context),
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: '설정 열기',
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

/// 별 배지 (Figma 364:8531 — 50×48 SVG 위에 숫자를 겹친다).
class _StarBadge extends StatelessWidget {
  const _StarBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50.w,
      height: 48.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(AppAssets.starBadge, width: 50.w, height: 48.w),
          Padding(
            // 별 무게중심이 약간 위라 숫자를 살짝 내린다 (Figma y=91-74=17)
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              '$count',
              style: context.typo.subtitle.copyWith(
                color: context.colors.starCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일과 타일 목록 (Figma 361×68, 간격 16).
class _RoutineList extends ConsumerWidget {
  const _RoutineList({required this.routines});

  final List<Routine> routines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final progress = ref.watch(childRoutineProvider);

    return Column(
      children: [
        for (final (index, routine) in routines.indexed) ...[
          if (index > 0) SizedBox(height: space.md),
          _RoutineTile(
            routine: routine,
            progress: routineProgress(routine, progress),
          ),
        ],
      ],
    );
  }
}

/// 일과 한 줄 (Figma 356:5079).
///
/// 미완료는 회색 + 진행률 링, 전부 끝내면 민트 배경 + 채운 체크.
/// 탭하면 카드 상세로 들어간다.
class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.routine, required this.progress});

  final Routine routine;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final isDone = progress >= 1.0;

    return AppPressable(
      onTap: () => context.push(Routes.childRoutineDetail, extra: routine),
      scaleDown: AppPressable.scaleCard,
      child: Container(
        // 보상이 있으면 한 줄이 늘어 타일이 높아진다 (이슈 #239). 시안은 92 (#445).
        height: (routine.hasReward ? 92 : 68).h,
        // Figma 실측 — 제목 좌 24, 화살표 우 16
        padding: EdgeInsets.only(left: 24.w, right: 16.w),
        decoration: BoxDecoration(
          color: isDone ? colors.childTileDone : colors.routineTileBg,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 시안 제목은 18/800이다. 예전엔 w400이었다 (#445).
                    style: context.typo.childDetailTitle.copyWith(
                      color: colors.chipLabel,
                    ),
                  ),
                  // 목록에서부터 "다 하면 뭘 받는지"가 보인다 (이슈 #239).
                  // 들어가야 알 수 있으면 시작할 이유가 약해진다.
                  // 시안: `다하면`은 회색(#74757D), 보상은 검정 70% — 둘 다 16 (#445).
                  if (routine.hasReward) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Text(
                          '다하면',
                          style: context.typo.body.copyWith(
                            color: colors.routineTileLabel,
                          ),
                        ),
                        SizedBox(width: space.xs),
                        Expanded(
                          child: Text(
                            routine.rewardDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typo.body.copyWith(
                              color: Colors.black.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: space.xs),
            RoutineProgressRing(progress: progress, boldCheck: true),
            SizedBox(width: space.xs),
            // 아래 방향 원본을 반시계 90° 돌려 `>`로 만든다
            Transform.rotate(
              angle: -math.pi / 2,
              child: SvgPicture.asset(
                AppAssets.iconAngleSmall,
                width: 24.w,
                height: 24.w,
                // 시안 PNG 실측 #74757D (`다하면` 글자와 같은 회색)
                colorFilter: ColorFilter.mode(
                  colors.routineTileLabel,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보호자가 아직 일과를 만들지 않았다 (Figma 343:4543).
class _NoRoutine extends StatelessWidget {
  const _NoRoutine({
    required this.childName,
    required this.character,
    this.errorCode,
  });

  final String childName;

  /// 온보딩에서 고른 캐릭터. 시무룩한 일러스트·글로우 색이 갈린다.
  final CardCharacter character;

  /// 조회 실패 시 제보 추적용 코드. null이면 표시하지 않는다.
  final String? errorCode;

  /// 상단 줄 아래부터 제목까지 — 시안(343:4543)은 제목이 234 에서 시작한다.
  /// 상단 줄 아래 → 시무룩한 그림. 상단을 6 올린 만큼 여기서 되돌린다.
  static double get _emptyTop => 109.h;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 캐릭터별 일러스트·글로우 — 고양이는 파랑, 여우는 주황 (Figma 343:4543)
    final (glowColor, sadAsset) = switch (character) {
      CardCharacter.cat => (colors.catSelectedFill, AppAssets.ruruSad),
      CardCharacter.fox => (colors.foxSelectedFill, AppAssets.popoSad),
    };

    // 작은 화면·큰 글꼴에서도 넘치지 않게 스크롤로 감싼다.
    //
    // **`Center`가 아니다.** 세로 가운데에 두면 화면 높이에 따라 글자가 오르내려
    // 시안과 어긋난다 — 실제로 81 아래에 있었다. 시안(343:4543)은 제목이 234 에서
    // 시작하므로 위 여백을 고정한다 (#297).
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: _emptyTop),
          Text(
            '아직 $childName의\n일과가 없어요',
            textAlign: TextAlign.center,
            style: context.typo.greeting.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: 14.h),
          Text(
            '보호자 모드에서 일과를 만들 수 있어요',
            style: context.typo.body.copyWith(color: colors.textSecondary),
          ),
          if (errorCode != null) ...[
            SizedBox(height: 8.h),
            Text(
              '($errorCode)',
              style: context.typo.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          // 설명 → 시무룩한 그림. 48을 쓰면 그림이 15 내려간다 (#297).
          SizedBox(height: 35.h),
          // 캐릭터 뒤 은은한 빛 — 단순 원이라 코드로 그린다
          // (Figma blur 100 ≈ sigma 50)
          SizedBox(
            width: 200.w,
            height: 200.w,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50.w, sigmaY: 50.w),
                  child: Container(
                    width: 180.w,
                    height: 180.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glowColor,
                    ),
                  ),
                ),
                // 발밑 그림자 (Figma Ellipse 2 — 64×16). 캐릭터보다 뒤에 깐다
                Positioned(
                  bottom: 10.w,
                  child: ClipOval(
                    child: SizedBox(
                      width: 64.w,
                      height: 16.w,
                      child: ColoredBox(color: colors.childEmptyShadow),
                    ),
                  ),
                ),
                // 시무룩한 캐릭터 — 형태가 있는 일러스트는 반드시 에셋
                SvgPicture.asset(sadAsset, width: 164.w, height: 164.w),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

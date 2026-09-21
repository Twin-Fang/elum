import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../onboarding/domain/character.dart';
import '../application/routine_notifier.dart';
import '../data/routine_repository.dart';
import 'widgets/create_routine_button.dart';
import 'widgets/routine_summary_tile.dart';
import 'widgets/today_routine_section.dart';

/// Figma `보호자_홈`(931:3896 기본 / 931:4179 밀림 / 931:4879 삭제 확인 · 이슈 #258).
///
/// 개편으로 홈이 **오늘 일과 · 지난 일과 두 칸**으로 정리됐다.
///
/// - `추천 일과`가 빠졌다. 자리를 많이 쓰는 데 비해 눌리지 않았고, 그 자리에
///   지난 일과가 들어와 "전에 하던 것을 또 한다"는 실제 쓰임을 받는다.
/// - `새로운 일과 만들기`가 설명 붙은 카드에서 알약 버튼으로 줄었다.
/// - 섹션 순서가 상태에 따라 바뀌지 않는다. 오늘이 늘 먼저다 — 목록이 비었다고
///   자리가 뒤바뀌면 다음에 열었을 때 어디를 봐야 할지 다시 찾게 된다.
class GuardianHomeScreen extends ConsumerWidget {
  const GuardianHomeScreen({super.key});

  /// Figma 실측 — 카드·버튼은 화면 끝에서 16, 글은 24
  static const _listInset = 16.0;

  /// 머리말 묶음 ↔ 만들기 버튼 32 · 버튼 ↔ 일과 40 · 섹션 사이 32 · 제목 ↔ 카드 8
  static const _toCreateButton = 32.0;
  static const _toSections = 40.0;
  static const _betweenSections = 32.0;
  static const _titleToList = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;

    // 서버 호칭 → 로컬 온보딩 값 → 대체어 순으로 고른다.
    // 서버가 죽어도 화면은 떠야 한다 (docs 원칙 6번).
    final localName = ref.watch(onboardingProvider).displayName;
    final childName = ref.watch(memberProvider).maybeWhen(
          data: (member) => member?.nickname ?? localName,
          orElse: () => localName,
        );

    // 온보딩에서 고른 캐릭터(고양이/여우) — 홈 전역의 마스코트를 이 값으로 맞춘다.
    // 선택 전(구버전 데이터 등) 폴백은 이룸이 홈과 동일하게 고양이로 둔다.
    final character =
        ref.watch(onboardingProvider).cardCharacter ?? CardCharacter.cat;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(childName: childName, character: character),
              SizedBox(height: _toCreateButton.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _listInset.w),
                child: CreateRoutineButton(
                  onTap: () => _startRoutine(context, ref),
                ),
              ),
              SizedBox(height: _toSections.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _listInset.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const RoutineSectionTitle(
                      iconAsset: AppAssets.iconTodayRoutine,
                      label: '오늘 일과',
                    ),
                    SizedBox(height: _titleToList.h),
                    const TodayRoutineSection(),
                    SizedBox(height: _betweenSections.h),
                    const RoutineSectionTitle(
                      iconAsset: AppAssets.iconTimePast,
                      label: '지난 일과',
                    ),
                    SizedBox(height: _titleToList.h),
                    const PastRoutineSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 일과 만들기 시작. 이전 입력이 남아 있으면 안 되므로 항상 초기화한다.
  void _startRoutine(BuildContext context, WidgetRef ref) {
    ref.read(routineFlowProvider.notifier).reset();
    context.push(Routes.routineInput);
  }
}

/// 로고 + 캐릭터 배지 + 설정 + 인사말 (Figma y=70~223).
///
/// 셋이 y=98을 가운데로 나란히 선다. 크기가 제각각(30 · 56 · 24)이라
/// 위를 맞추면 어긋나 보인다.
class _Header extends StatelessWidget {
  const _Header({required this.childName, required this.character});

  final String childName;
  final CardCharacter character;

  /// Figma 실측 — 안전영역(59) 기준 상단 여백
  static const _top = 11.0;
  static const _logoW = 80.0;
  static const _logoH = 30.0;
  static const _badge = 56.0;

  /// 배지 모서리. 시안 356:5106 · 382:3257 이 16 이다.
  static const _badgeRadius = 16.0;
  static const _settings = 24.0;

  /// 배지 ↔ 설정 16 · 머리 줄 ↔ 인사말 11 · 인사말 ↔ 부제 12
  static const _badgeToSettings = 16.0;
  static const _rowToGreeting = 11.0;
  static const _greetingToSubtitle = 12.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: _top.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AppAssets.homeLogo,
                width: _logoW.w,
                height: _logoH.h,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 이룸이 화면으로 넘어가는 입구. 보호자→이룸이 방향은 암호 없이 바로 간다.
                  // (이룸이→보호자 방향만 PIN으로 막는다)
                  AppPressable(
                    onTap: () => context.go(Routes.child),
                    scaleDown: AppPressable.scaleIcon,
                    child: _CharacterBadge(character: character),
                  ),
                  SizedBox(width: _badgeToSettings.w),
                  // 설정 진입점 (#181). 개편 시안에서 배지 오른쪽으로 옮겨졌다.
                  AppPressable(
                    // push로 연다. go는 스택을 교체해 설정 화면의 뒤로가기가
                    // 돌아갈 곳을 잃는다 — 화살표도 기기 뒤로가기도 먹통이 된다 (이슈 #194).
                    onTap: () => context.push(Routes.guardianSettings),
                    scaleDown: AppPressable.scaleIcon,
                    child: SvgPicture.asset(
                      AppAssets.iconSettings,
                      // 정사각형 아이콘 — 가로세로 모두 .w
                      width: _settings.w,
                      height: _settings.w,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: _rowToGreeting.h),
          Text(
            // Figma 문구. 줄바꿈 위치도 디자인이 정한 대로다.
            '안녕하세요,\n$childName 보호자님 👋🏻',
            style: context.typo.greeting.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: _greetingToSubtitle.h),
          Text(
            '오늘은 어떤 일과를 준비할까요?',
            style: context.typo.body.copyWith(color: colors.routineTileLabel),
          ),
        ],
      ),
    );
  }
}

/// 오른쪽 위 캐릭터 배지.
///
/// **여우만 경계 밖을 잘라낸다** (#311). 여우 에셋은 시안에서 마스크가 셋 겹쳐
/// 나오는데 `flutter_svg` 가 그것을 온전히 그리지 못해 캐릭터가 둥근 사각형
/// 밖으로 삐져나온다. 시안에서 다시 받아도 마스크는 그대로 셋이라 에셋 교체로는
/// 풀리지 않는다.
///
/// **고양이에는 씌우지 않는다.** 멀쩡한 것을 잘라내면 모서리가 미세하게 깎여
/// 시안 대조 테스트가 어긋난다 — 실제로 그렇게 나왔다.
class _CharacterBadge extends StatelessWidget {
  const _CharacterBadge({required this.character});

  final CardCharacter character;

  @override
  Widget build(BuildContext context) {
    final badge = SvgPicture.asset(
      AppAssets.characterBadgeFramed(character),
      // 정사각형 배지 — 찌그러지지 않게 가로세로 모두 .w
      width: _Header._badge.w,
      height: _Header._badge.w,
    );
    if (character != CardCharacter.fox) return badge;
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        _Header._badgeRadius.r,
      ),
      child: badge,
    );
  }
}

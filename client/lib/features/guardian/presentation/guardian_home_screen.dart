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
import 'widgets/recommended_routine_strip.dart';
import 'widgets/today_routine_section.dart';

/// Figma `보호자_홈`(217:2655 빈 / 356:4688 접힘 / 309:3739 펼침).
///
/// **하단 고정 CTA가 없다.** Figma에서 "일과 만들기" 버튼이 본문의
/// `새로운 일과 만들기` 카드로 올라왔다. (이슈 #19)
///
/// **섹션 순서가 상태에 따라 다르다** (이슈 #69) —
/// 일과가 있으면 `오늘 일과`가 `추천 일과`보다 위로 온다.
class GuardianHomeScreen extends ConsumerWidget {
  const GuardianHomeScreen({super.key});

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

    final hasRoutines = ref.watch(homeRoutinesProvider).isNotEmpty;

    // 온보딩에서 고른 캐릭터(고양이/여우) — 홈 전역의 마스코트를 이 값으로 맞춘다.
    // 선택 전(구버전 데이터 등) 폴백은 아이 홈과 동일하게 고양이로 둔다.
    final character =
        ref.watch(onboardingProvider).cardCharacter ?? CardCharacter.cat;

    final todaySection = <Widget>[
      _SectionTitle(iconAsset: AppAssets.iconClock, label: '오늘 일과'),
      SizedBox(height: space.md),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: space.screenH),
        child: const TodayRoutineSection(),
      ),
    ];

    final recommendSection = <Widget>[
      _SectionTitle(iconAsset: AppAssets.iconSparkles, label: '추천 일과'),
      SizedBox(height: space.md),
      RecommendedRoutineStrip(
        // 타일 라벨("비 오는 날 등교")이 아니라 자연어 문장을 채운다.
        // 라벨은 명사구라 보호자가 직접 쓴 문장으로 보이지 않는다. (이슈 #39)
        onTap: (suggestion) =>
            _startRoutine(context, ref, prefill: suggestion.inputText),
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(childName: childName, character: character),
              SizedBox(height: space.lg),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: space.screenH),
                child: _NewRoutineCard(
                  childName: childName,
                  onTap: () => _startRoutine(context, ref),
                ),
              ),
              SizedBox(height: space.xl),
              // Figma 정합 — 일과가 있으면 오늘 일과가 먼저다 (356:4688).
              // 없으면 추천이 먼저다 (217:2655).
              ...hasRoutines
                  ? [...todaySection, SizedBox(height: space.xl), ...recommendSection]
                  : [...recommendSection, SizedBox(height: space.xl), ...todaySection],
            ],
          ),
        ),
      ),
    );
  }

  /// 일과 만들기 시작. 이전 입력이 남아 있으면 안 되므로 항상 초기화한다.
  void _startRoutine(BuildContext context, WidgetRef ref, {String? prefill}) {
    final notifier = ref.read(routineFlowProvider.notifier)..reset();
    // 추천 타일에서 왔으면 문구를 미리 채운다. 보호자가 손댈 수 있다.
    if (prefill != null) notifier.setRawInput(prefill);
    context.push(Routes.routineInput);
  }
}

/// 로고 + 캐릭터 배지 + 인사말 (Figma y=70~223)
class _Header extends StatelessWidget {
  const _Header({required this.childName, required this.character});

  final String childName;
  final CardCharacter character;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(AppAssets.homeLogo, width: 80.w, height: 30.h),
              // 아이 화면으로 넘어가는 입구. 보호자→아이 방향은 암호 없이 바로 간다.
              // (아이→보호자 방향만 PIN으로 막는다)
              AppPressable(
                onTap: () => context.go(Routes.child),
                scaleDown: AppPressable.scaleIcon,
                child: SvgPicture.asset(
                  AppAssets.characterBadgeFramed(character),
                  // 정사각형 배지 — 찌그러지지 않게 가로세로 모두 .w
                  width: 56.w,
                  height: 56.w,
                ),
              ),
            ],
          ),
          SizedBox(height: space.lg),
          Text(
            // Figma 문구. 줄바꿈 위치도 디자인이 정한 대로다.
            '안녕하세요,\n$childName 보호자님 👋🏻',
            style: context.typo.greeting.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.sm),
          Text(
            '오늘은 어떤 일과를 준비할까요?',
            style: context.typo.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// "새로운 일과 만들기" 카드 (344×94, 그라데이션 + 그림자).
///
/// Figma에서 하단 CTA를 대신하는 자리다.
class _NewRoutineCard extends StatelessWidget {
  const _NewRoutineCard({
    required this.childName,
    required this.onTap,
  });

  final String childName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        height: 94.h,
        padding: EdgeInsets.symmetric(horizontal: space.md),
        decoration: BoxDecoration(
          // Figma linear-gradient(134deg, #F9F4FF → #E9EEFF)
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.homeCardGradientStart,
              colors.homeCardGradientEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(space.cardRadius),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.homeCardShadow,
              blurRadius: 10.w,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Row(
          children: [
            // Figma 217:2668+217:2675 — 보호자가 고른 캐릭터(고양이/여우)와
            // 무관하게 AI 마스코트 "루미" 병아리로 고정된다. (이슈 #110)
            SizedBox(
              width: 56.w,
              height: 56.w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.homeCardIconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    AppAssets.homeNewRoutineChick,
                    width: 47.w,
                    height: 51.w,
                  ),
                ),
              ),
            ),
            SizedBox(width: space.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        AppAssets.iconSparkles,
                        width: 15.w,
                        height: 18.h,
                      ),
                      SizedBox(width: space.xs),
                      Text(
                        '새로운 일과 만들기',
                        style: context.typo.cardTitle.copyWith(
                          color: colors.homeCardTitle,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: space.xs),
                  Text(
                    'AI 루미가 $childName에게 맞는 일과와\n행동 카드를 만들어드려요',
                    style: context.typo.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 섹션 제목 — 아이콘 + 문구 (Figma 14/w800).
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH),
      child: Row(
        children: [
          // 정사각형 아이콘 — 가로세로 모두 .w
          SvgPicture.asset(iconAsset, width: 18.w, height: 18.w),
          SizedBox(width: space.xs),
          Text(
            label,
            style: context.typo.sectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

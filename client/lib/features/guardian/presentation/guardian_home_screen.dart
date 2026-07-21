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
import '../application/routine_notifier.dart';
import '../../child/presentation/mode_switch_screen.dart';
import '../../../shared/models/action_card.dart';
import '../../../core/theme/app_motion.dart';
import '../../child/application/child_routine_notifier.dart';
import '../domain/card_palette.dart';
import '../data/routine_repository.dart';
import 'widgets/recommended_routine_strip.dart';

/// Figma `보호자_홈`(217:2655) — 온보딩을 마치면 도착하는 기본 화면.
///
/// **하단 고정 CTA가 없다.** Figma에서 "일과 만들기" 버튼이 본문의
/// `새로운 일과 만들기` 카드로 올라왔다. (이슈 #19)
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

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(childName: childName),
              SizedBox(height: space.lg),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: space.screenH),
                child: _NewRoutineCard(
                  childName: childName,
                  onTap: () => _startRoutine(context, ref),
                ),
              ),
              SizedBox(height: space.xl),
              _SectionTitle(
                iconAsset: AppAssets.iconSparkles,
                label: '추천 일과',
              ),
              SizedBox(height: space.md),
              RecommendedRoutineStrip(
                // 타일 라벨("비 오는 날 등교")이 아니라 자연어 문장을 채운다.
                // 라벨은 명사구라 보호자가 직접 쓴 문장으로 보이지 않는다. (이슈 #39)
                onTap: (suggestion) =>
                    _startRoutine(context, ref, prefill: suggestion.inputText),
              ),
              SizedBox(height: space.xl),
              _SectionTitle(
                iconAsset: AppAssets.iconClock,
                label: '오늘 일과',
              ),
              SizedBox(height: space.md),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: space.screenH),
                child: const _RecentRoutines(),
              ),
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
  const _Header({required this.childName});

  final String childName;

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
              // 아이 화면으로 넘어가는 입구. 암호를 물어본다.
              AppPressable(
                onTap: () => context.push(
                  '${Routes.modeSwitch}?to=${ModeSwitchTarget.child.name}',
                ),
                scaleDown: AppPressable.scaleIcon,
                child: SvgPicture.asset(
                  AppAssets.homeCharacterBadge,
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
  const _NewRoutineCard({required this.childName, required this.onTap});

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
            SvgPicture.asset(
              AppAssets.homeNewRoutineIllust,
              // 정사각형 일러스트 — 가로세로 모두 .w
              width: 56.w,
              height: 56.w,
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

/// 오늘 일과 — 방금 만든 일과의 카드 목록 또는 빈 상태.
///
/// Figma `보호자_홈_최근일과`(309:3739)는 **일과 목록이 아니라 그 안의 카드**를
/// 펼쳐 보여준다. 보호자가 아이에게 무엇을 시켰는지 한눈에 확인하는 자리다.
class _RecentRoutines extends ConsumerWidget {
  const _RecentRoutines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 방금 만든 일과가 있으면 그것을 먼저 보여준다. 서버 목록을 기다리지 않는다.
    final current = ref.watch(routineFlowProvider).routine;
    if (current != null && current.steps.isNotEmpty) {
      return _CardList(cards: current.steps);
    }

    final routines = ref.watch(myRoutinesProvider);

    return routines.when(
      // 로딩과 빈 상태를 시각적으로 구분한다 — 무한 로딩처럼 보이면 안 된다
      loading: () => _RoutineCardShell(
        child: Center(
          child: SizedBox(
            width: 20.w,
            height: 20.w,
            child: CircularProgressIndicator(strokeWidth: 2.w),
          ),
        ),
      ),
      // 조회 실패도 빈 상태로 흡수한다. repository가 이미 빈 목록을 주지만
      // provider 단계의 예외까지 막아 화면이 붉게 덮이지 않게 한다.
      error: (_, _) => const _EmptyRoutines(),
      data: (list) {
        final cards = list.isEmpty ? const <ActionCard>[] : list.first.steps;
        return cards.isEmpty
            ? const _EmptyRoutines()
            : _CardList(cards: cards);
      },
    );
  }
}

/// 카드 한 줄씩 (Figma 344×68).
///
/// 번호 배지 색이 카드마다 다르다 — 카드확인·아이 홈과 같은 팔레트를 쓴다.
class _CardList extends ConsumerWidget {
  const _CardList({required this.cards});

  final List<ActionCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final progress = ref.watch(childRoutineProvider);

    return Column(
      children: [
        for (final (index, card) in cards.indexed) ...[
          if (index > 0) SizedBox(height: space.xs),
          _CardRow(
            card: card,
            index: index,
            isDone: progress.isCompleted(card.id),
          ),
        ],
      ],
    );
  }
}

/// 카드 한 줄 — 번호 + 제목 + 설명 + 완료 표시.
class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.index,
    required this.isDone,
  });

  final ActionCard card;
  final int index;

  /// 아이가 완료했는가. 완료하면 우측에 체크가 채워진다.
  final bool isDone;

  /// Figma 실측 — 번호 배지 40×40 r12
  static const _badgeSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final palette = CardPalette.at(index);

    return _RoutineCardShell(
      child: Row(
        children: [
          Container(
            // 정사각형 배지 — 가로세로 모두 .w
            width: _badgeSize.w,
            height: _badgeSize.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(12.w),
            ),
            child: Text(
              '${index + 1}',
              style: context.typo.cardHeadline.copyWith(color: colors.surface),
            ),
          ),
          SizedBox(width: space.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.cardBody.copyWith(color: colors.chipLabel),
                ),
                SizedBox(height: space.xs),
                Text(
                  card.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      context.typo.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          // 아이가 끝낸 카드만 채워진 체크가 된다
          _DoneMark(isDone: isDone),
        ],
      ),
    );
  }
}

/// 완료 표시 (40×40). 미완료는 흐린 원, 완료는 채워진 체크.
class _DoneMark extends StatelessWidget {
  const _DoneMark({required this.isDone});

  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      // 원형 표시 — 가로세로 모두 .w
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? colors.checkDone : Colors.transparent,
        border:
            isDone ? null : Border.all(color: colors.checkPending, width: 2.w),
      ),
      child: Icon(
        Icons.check_rounded,
        size: 22.w,
        color: isDone ? colors.surface : colors.checkPending,
      ),
    );
  }
}

/// Figma 빈 상태 (344×68) — `아직 만든 일과가 없어요 😢`
class _EmptyRoutines extends ConsumerWidget {
  const _EmptyRoutines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final childName = ref.watch(onboardingProvider).displayName;

    return _RoutineCardShell(
      child: Row(
        children: [
          // 정사각형 일러스트 — 가로세로 모두 .w
          SvgPicture.asset(AppAssets.homeEmptyIllust, width: 40.w, height: 40.w),
          SizedBox(width: space.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '아직 만든 일과가 없어요 😢',
                  style: context.typo.cardBody
                      .copyWith(color: context.colors.chipLabel),
                ),
                SizedBox(height: space.xs),
                Text(
                  '$childName의 첫 행동카드를 만들어보세요',
                  style: context.typo.caption
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 최근 일과 카드의 공통 껍데기 (344×68, r20, 흰 배경).
class _RoutineCardShell extends StatelessWidget {
  const _RoutineCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return Container(
      height: 68.h,
      padding: EdgeInsets.symmetric(horizontal: space.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

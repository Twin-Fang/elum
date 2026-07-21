import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../shared/models/routine.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../application/routine_notifier.dart';
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
                onTap: (routine) =>
                    _startRoutine(context, ref, prefill: routine.prefillText),
              ),
              SizedBox(height: space.xl),
              _SectionTitle(
                iconAsset: AppAssets.iconClock,
                label: '최근 일과',
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
              SvgPicture.asset(AppAssets.homeLogo, width: 80, height: 30),
              SvgPicture.asset(
                AppAssets.homeCharacterBadge,
                width: 56,
                height: 56,
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 94,
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
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              AppAssets.homeNewRoutineIllust,
              width: 56,
              height: 56,
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
                        width: 15,
                        height: 18,
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
          SvgPicture.asset(iconAsset, width: 18, height: 18),
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

/// 최근 일과 — 목록 또는 빈 상태.
class _RecentRoutines extends ConsumerWidget {
  const _RecentRoutines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(myRoutinesProvider);

    return routines.when(
      // 로딩과 빈 상태를 시각적으로 구분한다 — 무한 로딩처럼 보이면 안 된다
      loading: () => const _RoutineCardShell(
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      // 조회 실패도 빈 상태로 흡수한다. repository가 이미 빈 목록을 주지만
      // provider 단계의 예외까지 막아 화면이 붉게 덮이지 않게 한다.
      error: (_, _) => const _EmptyRoutines(),
      data: (list) =>
          list.isEmpty ? const _EmptyRoutines() : _RoutineList(routines: list),
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
          SvgPicture.asset(AppAssets.homeEmptyIllust, width: 40, height: 40),
          SizedBox(width: space.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '아직 만든 일과가 없어요 😢',
                  style: context.typo.cardBody.copyWith(
                    color: context.colors.chipLabel,
                  ),
                ),
                SizedBox(height: space.xs),
                Text(
                  '$childName의 첫 행동카드를 만들어보세요',
                  style: context.typo.caption.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 일과 목록. 승인 여부와 무관하게 보호자에게는 모두 보인다.
class _RoutineList extends StatelessWidget {
  const _RoutineList({required this.routines});

  final List<Routine> routines;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Column(
      children: [
        for (final (index, routine) in routines.indexed) ...[
          if (index > 0) SizedBox(height: space.sm),
          _RoutineCardShell(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // 제목이 비어 오는 경우가 있어 대체어를 둔다
                        routine.title.isEmpty ? '이름 없는 일과' : routine.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.cardBody.copyWith(
                          color: context.colors.chipLabel,
                        ),
                      ),
                      SizedBox(height: space.xs),
                      Text(
                        '카드 ${routine.steps.length}장',
                        style: context.typo.caption.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
      height: 68,
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

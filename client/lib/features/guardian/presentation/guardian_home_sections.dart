import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/home_notice_slot.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_reveal.dart';
import '../application/home_next_step.dart';
import '../domain/guide_tip.dart';
import 'widgets/guide_tip_card.dart';
import 'widgets/home_next_step_card.dart';
import 'widgets/home_streak_chip.dart';
import 'widgets/past_routine_section.dart';
import 'widgets/routine_summary_tile.dart';
import 'widgets/today_routine_section.dart';

/// 보호자 홈 본문 칸: 연속 기록 > 안내 한 장 (다음에 할 일 또는 가이드 팁) > 알림 한 장 > 오늘 일과 > 지난 일과
/// 안내 카드는 한 번에 하나 (다음에 할 일이 있으면 가이드 팁은 숨김). 칸마다 위에서부터 차례로 떠오름
class GuardianHomeSections extends ConsumerWidget {
  const GuardianHomeSections({super.key, required this.swipeKey, required this.onCreateRoutine, required this.horizontalInset});

  /// 코치마크가 가리킬 오늘 일과 첫 줄
  final GlobalKey swipeKey;

  /// 다음에 할 일 · 권유 카드의 `만들기` (홈 버튼과 같은 크레딧 확인)
  final Future<void> Function() onCreateRoutine;

  /// 화면 끝 > 카드 여백
  final double horizontalInset;

  /// 섹션 사이 32 · 제목 > 카드 8 (시안 실측)
  static const _betweenSections = 32.0;
  static const _titleToList = 8.0;

  /// 연속 기록 칩 아래 12 · 안내·알림 카드 아래 24 (카드 묶음과 오늘 일과 제목 사이 숨 쉴 자리)
  static const _streakToNext = 12.0;
  static const _cardToSection = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNextStep = ref.watch(homeNextStepProvider) != HomeNextStep.none;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: revealInOrder([
          // 이룸이 연속 기록 불꽃 (2일 이상일 때만)
          const HomeStreakChip(bottomGap: _streakToNext),
          // 첫날 흐름 「다음에 할 일」 한 장 (첫 완료 뒤 사라짐)
          HomeNextStepCard(onCreateRoutine: onCreateRoutine, bottomGap: _cardToSection),
          // 가이드 팁: 다음에 할 일이 끝난 뒤에만 그 자리 아래 하나
          GuideTipSlot(
            placement: GuideTipPlacement.guardianHome,
            isSuppressed: hasNextStep,
            padding: EdgeInsets.only(bottom: _cardToSection.h),
          ),
          // 알림 카드 한 번에 하나 (알림 꺼짐 > 크레딧 부족 > 권유 > 자동 보내기 안내, 권유는 하루 1개)
          HomeNoticeSlot(onCreateRoutine: onCreateRoutine, bottomGap: _cardToSection),
          RoutineSectionTitle(iconAsset: AppAssets.iconTodayRoutine, label: context.l10n.guardianHomeTodayRoutine),
          SizedBox(height: _titleToList.h),
          TodayRoutineSection(coachKey: swipeKey),
          SizedBox(height: _betweenSections.h),
          RoutineSectionTitle(iconAsset: AppAssets.iconTimePast, label: context.l10n.guardianHomePastRoutine),
          SizedBox(height: _titleToList.h),
          const PastRoutineSection(),
        ]),
      ),
    );
  }
}

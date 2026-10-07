import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_state_body.dart';

/// 카드확인 화면의 부품 (#444 · 시안 `1173:5541` 기본 / `1197:5798` 순서 변경).
///
/// 화면 파일이 300줄을 넘지 않게 나눴다. 좌표는 시안(393×852) 그대로다.

/// 머리 — 회색 반짝임 + `카드 N개를 만들었어요` (시안 1173:5592).
///
/// 시안은 `카드 5개를 만들었어요`로 이미 능동형이다(옛 시안은 `생성되었어요`였다).
class CardReviewHead extends StatelessWidget {
  const CardReviewHead({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(AppAssets.iconSparklesHead, width: 18.w, height: 22.w),
        SizedBox(width: 12.w),
        Text(
          context.l10n.cardReviewMade(count),
          style: context.typo.promptBody.copyWith(
            color: context.colors.promptMuted,
          ),
        ),
      ],
    );
  }
}

/// 보상 줄 — `완료 시 **젤리 4개 먹기** ✎` (시안 1173:5544, 333폭·라운드 8).
///
/// 정한 보상을 다시 확인하고 고친다(#239). **건너뛴 사람에게는 정하라고 권한다** —
/// 카드를 다 보고 나서야 "무엇을 주지"가 떠오르는 경우가 있다. 시안에는 정한 모습만
/// 있어, 안 정했을 때는 같은 상자에 `보상 정하기 +` 를 둔다.
class CardReviewRewardRow extends StatelessWidget {
  const CardReviewRewardRow({
    super.key,
    required this.reward,
    required this.onTap,
    this.rewardLanguage = 'ko',
  });

  /// 정해진 보상 (`🍪 젤리 먹기`). null 이면 아직 없다.
  final String? reward;
  final VoidCallback onTap;

  /// 보상 글의 언어(일과 언어). 앞 문구와 안내는 화면 문구라 따르지 않는다.
  final String rewardLanguage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typo.rewardLine;
    final has = reward != null;

    return AppPressable(
      onTap: onTap,
      child: Container(
        width: 333.w,
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: colors.editChipBg,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: has
                      ? [
                          TextSpan(
                            text: context.l10n.cardReviewRewardLead,
                            style: style.copyWith(color: colors.rewardLineLead),
                          ),
                          TextSpan(
                            text: reward,
                            style: style.copyWith(
                              color: colors.textPrimary,
                              locale: contentLocaleOf(rewardLanguage),
                            ),
                          ),
                        ]
                      : [
                          TextSpan(
                            text: context.l10n.cardReviewRewardSet,
                            style: style.copyWith(color: colors.textPrimary),
                          ),
                        ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 8.w),
            SvgPicture.asset(
              has ? AppAssets.iconPencilEdit : AppAssets.iconPlus,
              width: 12.w,
              height: 12.w,
              // 시안의 연필은 민트다 (point_color #55CFBA)
              colorFilter: ColorFilter.mode(colors.checkDone, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}

/// 순서 변경 모드의 안내 (시안 1197:5899). 보상 줄이 있던 자리를 채운다.
class CardReviewReorderHint extends StatelessWidget {
  const CardReviewReorderHint({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 333.w,
      // 보상 줄(46)과 같은 높이라 아래 버튼이 움직이지 않는다
      height: 46.h,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          // 시안 글자 윗변이 587 + 8
          padding: EdgeInsets.only(top: 8.h),
          // 글꼴을 키우면 두 줄로 꺾여 46 높이 밖으로 잘린다 — 한 줄로 줄인다
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              context.l10n.cardReviewReorderHint,
              maxLines: 1,
              softWrap: false,
              style: context.typo.promptBody.copyWith(
                color: context.colors.promptMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 도구 버튼 3개 — `카드 순서 변경` · `이 카드 수정` · `카드 추가` (시안 1173:5574).
///
/// 순서 변경 모드에서는 `카드 순서 변경` 만 눌린 색이고 나머지 둘은 흐려진 채
/// 눌리지 않는다 (시안 1197:5798, 투명도 0.4). 눌린 버튼을 다시 누르면 모드를 나온다.
class CardReviewToolRow extends StatelessWidget {
  const CardReviewToolRow({
    super.key,
    required this.reorderMode,
    required this.onReorder,
    required this.onFinishReorder,
    required this.onEdit,
    required this.onAdd,
  });

  final bool reorderMode;
  final VoidCallback onReorder;

  /// 모드 안에서 눌린 `카드 순서 변경` 을 다시 눌렀을 때 — `완료` 와 같다.
  final VoidCallback onFinishReorder;
  final VoidCallback onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 110 × 3 + 8 × 2
      width: 346.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ToolButton(
            icon: AppAssets.iconInterlining,
            label: context.l10n.cardReviewToolReorder,
            pressed: reorderMode,
            // 켜고 끄는 버튼이다 — 눌린 상태에서 다시 누르면 나온다(옮긴 순서는 둔다).
            // 전에는 여기가 막혀 `완료`·`✕` 로만 나올 수 있어 불편했다 (#451).
            onTap: reorderMode ? onFinishReorder : onReorder,
          ),
          _ToolButton(
            icon: AppAssets.iconPencilEdit,
            label: context.l10n.cardReviewToolEdit,
            dimmed: reorderMode,
            onTap: reorderMode ? null : onEdit,
          ),
          _ToolButton(
            icon: AppAssets.iconPlus,
            label: context.l10n.cardReviewToolAdd,
            dimmed: reorderMode,
            onTap: reorderMode ? null : onAdd,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.pressed = false,
    this.dimmed = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;

  /// 눌린 색 (#D7D3D1)
  final bool pressed;

  /// 흐리게 (투명도 0.4)
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: AppPressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          width: 110.w,
          height: 60.h,
          decoration: BoxDecoration(
            color: pressed ? colors.editChipPressedBg : colors.editChipBg,
            borderRadius: BorderRadius.circular(18.r),
          ),
          alignment: Alignment.center,
          // 글꼴을 키워도 버튼 밖으로 넘치지 않게 줄인다
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(icon, width: 16.w, height: 16.w),
                SizedBox(height: 8.h),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: context.typo.editChipLabel.copyWith(
                    color: colors.editChipLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 순서 변경 모드의 상단바 — `✕` + 가운데 `카드 순서 변경` (시안 1197:5798).
///
/// 높이는 기본 상단바(위 16 + 24 + 아래 12)와 같다 — 모드를 바꿀 때 화면이 출렁이지
/// 않게 한다. 뒤로·홈·임시저장은 없다: 이 모드에서 나가는 길은 `✕`·`완료`뿐이다.
class CardReviewReorderTopBar extends StatelessWidget {
  const CardReviewReorderTopBar({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 12.h),
      child: SizedBox(
        // 폭을 채워야 `✕` 의 left 가 화면 왼쪽에서 잰다 — 안 채우면 글자 폭에 오그라든다
        width: double.infinity,
        height: 24.w,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Text(
              context.l10n.cardReviewReorderTitle,
              style: context.typo.reorderTitle.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            // 그림이 40×40 안에 20×20 으로 그려져 있다 (x=16, y=67)
            Positioned(
              left: 16.w,
              child: AppPressable(
                onTap: onClose,
                scaleDown: AppPressable.scaleIcon,
                semanticLabel: context.l10n.cardReviewReorderCancel,
                child: SvgPicture.asset(
                  AppAssets.iconClose,
                  width: 40.w,
                  height: 40.w,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드가 없을 때. 로딩이 실패해도 여기까지 올 수 있다.
///
/// 막다른 길이 되지 않게 [onRetry] 로 만들기 첫 단계로 돌아갈 수 있다.
class CardReviewEmpty extends StatelessWidget {
  const CardReviewEmpty({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ElumStateBody(
      child: ElumErrorView(
        message: context.l10n.cardReviewEmptyTitle,
        description: context.l10n.cardReviewEmptyBody,
        // 에러 코드를 함께 보여줘야 제보를 추적할 수 있다
        errorCode: 'E-CARD',
        onRetry: onRetry,
        actionLabel: context.l10n.cardReviewEmptyAction,
      ),
    );
  }
}

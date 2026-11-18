import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/pro_badge.dart';

/// 도구 버튼 3~4개 — `순서 변경` · `이 카드 수정` · `카드 추가` (시안 1173:5574) · `예약` (#1439, 보일 때만)
///
/// 순서 변경 모드에서는 `순서 변경` 만 눌린 색이고 나머지는 흐려진 채
/// 눌리지 않는다 (시안 1197:5798, 투명도 0.4). 눌린 버튼을 다시 누르면 모드를 나온다.
class CardReviewToolRow extends StatelessWidget {
  const CardReviewToolRow({
    super.key,
    required this.reorderMode,
    required this.onReorder,
    required this.onFinishReorder,
    required this.onEdit,
    required this.onAdd,
    this.reorderKey,
    this.editKey,
    this.schedule,
  });

  /// 도구 버튼 모서리 반지름 (코치마크 구멍도 같은 값)
  static const buttonRadius = 18.0;

  /// 줄 폭 (시안 110 × 3 + 8 × 2) · 버튼 사이
  static const rowWidth = 346.0;
  static const _buttonGap = 8.0;

  /// 코치마크가 가리킬 `순서 변경` · `이 카드 수정` 버튼
  final GlobalKey? reorderKey;
  final GlobalKey? editKey;

  final bool reorderMode;
  final VoidCallback onReorder;

  /// 모드 안에서 눌린 `순서 변경` 을 다시 눌렀을 때 — `완료` 와 같다.
  final VoidCallback onFinishReorder;
  final VoidCallback onEdit;
  final VoidCallback onAdd;

  /// 넷째 `예약` 도구. null 이면 버튼 3개
  final CardReviewScheduleTool? schedule;

  @override
  Widget build(BuildContext context) {
    final schedule = this.schedule;
    final buttonCount = schedule == null ? 3 : 4;
    final buttonWidth =
        (rowWidth - _buttonGap * (buttonCount - 1)) / buttonCount;
    return SizedBox(
      width: rowWidth.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ToolButton(
            key: reorderKey,
            width: buttonWidth,
            face: CardReviewToolFace(
              icon: AppAssets.iconInterlining,
              label: context.l10n.cardReviewToolReorder,
              isPressed: reorderMode,
            ),
            // 켜고 끄는 버튼이다 — 눌린 상태에서 다시 누르면 나온다(옮긴 순서는 둔다).
            // 막아 두면 `완료`·`✕` 로만 나올 수 있어 불편하다.
            onTap: reorderMode ? onFinishReorder : onReorder,
          ),
          _ToolButton(
            key: editKey,
            width: buttonWidth,
            face: CardReviewToolFace(
              icon: AppAssets.iconPencilEdit,
              label: context.l10n.cardReviewToolEdit,
            ),
            isDimmed: reorderMode,
            onTap: reorderMode ? null : onEdit,
          ),
          _ToolButton(
            width: buttonWidth,
            face: CardReviewToolFace(
              icon: AppAssets.iconPlus,
              label: context.l10n.cardReviewToolAdd,
            ),
            isDimmed: reorderMode,
            onTap: reorderMode ? null : onAdd,
          ),
          if (schedule != null)
            _ToolButton(
              key: schedule.coachKey,
              width: buttonWidth,
              face: CardReviewToolFace(
                icon: AppAssets.iconCalendar,
                label: context.l10n.cardReviewToolSchedule,
                isActive: schedule.isActive,
              ),
              isDimmed: reorderMode,
              shouldShowProBadge: schedule.shouldShowProBadge,
              onTap: reorderMode ? null : schedule.onTap,
            ),
        ],
      ),
    );
  }
}

/// 넷째 `예약` 도구: 켜짐(반복을 골라 둠) · Free 표지 · 누름 · 코치마크 대상
typedef CardReviewScheduleTool = ({
  bool isActive,
  bool shouldShowProBadge,
  VoidCallback? onTap,
  GlobalKey? coachKey,
});

/// 도구 버튼 겉면: 그림 16 > 8 > 이름 한 줄 (코치마크 예약 시범도 같은 겉면을 그림)
class CardReviewToolFace extends StatelessWidget {
  const CardReviewToolFace({
    super.key,
    required this.icon,
    required this.label,
    this.isPressed = false,
    this.isActive = false,
  });

  final String icon;
  final String label;

  /// 눌린 색 (#D7D3D1)
  final bool isPressed;

  /// 켜진 도구 (예약을 골라 둠): 민트 바탕·테두리 + 오른쪽 위 체크 (칸 크기·이름은 그대로)
  final bool isActive;

  /// 켜짐 테두리 두께 · 체크 점 크기 · 체크 그림
  static const _activeBorderWidth = 2.0;
  static const _activeDotSize = 16.0;
  static const _activeCheckSize = 10.0;
  static const _activeDotInset = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconColor = isActive
        ? colors.infoHighlightMintAccent
        : colors.textPrimary;
    final labelColor = isActive
        ? colors.infoHighlightMintAccent
        : colors.editChipLabel;
    final face = Container(
      decoration: BoxDecoration(
        color: isActive
            ? colors.infoHighlightMintFill
            : isPressed
            ? colors.editChipPressedBg
            : colors.editChipBg,
        borderRadius: BorderRadius.circular(CardReviewToolRow.buttonRadius.r),
        border: isActive
            ? Border.all(
                color: colors.infoHighlightMintAccent,
                width: _activeBorderWidth,
              )
            : null,
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: _labelSidePadding.w),
      // 글꼴을 키워도 버튼 밖으로 넘치지 않게 줄인다
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 도구 아이콘은 같은 색 (그림 원본 색이 달라도 네 칸이 한 벌로 보이게)
            SvgPicture.asset(
              icon,
              width: 16.w,
              height: 16.w,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: context.typo.editChipLabel.copyWith(color: labelColor),
            ),
          ],
        ),
      ),
    );
    if (!isActive) return face;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        face,
        Positioned(
          top: _activeDotInset.h,
          right: _activeDotInset.w,
          child: Container(
            width: _activeDotSize.w,
            height: _activeDotSize.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.infoHighlightMintAccent,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              AppAssets.iconCheck,
              width: _activeCheckSize.w,
              height: _activeCheckSize.w,
              colorFilter: ColorFilter.mode(colors.surface, BlendMode.srcIn),
            ),
          ),
        ),
      ],
    );
  }

  /// 이름 좌우 최소 여백 (4칸일 때 글자가 모서리에 붙지 않게)
  static const _labelSidePadding = 4.0;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.width,
    required this.face,
    required this.onTap,
    this.isDimmed = false,
    this.shouldShowProBadge = false,
  });

  /// 버튼 폭 (시안 좌표, 줄 폭을 버튼 수로 나눈 값)
  final double width;
  final CardReviewToolFace face;
  final VoidCallback? onTap;

  /// 흐리게 (투명도 0.4)
  final bool isDimmed;

  /// Free 에게 오른쪽 위 PRO 배지
  final bool shouldShowProBadge;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(width: width.w, height: 60.h, child: face);
    return Opacity(
      opacity: isDimmed ? 0.4 : 1,
      child: AppPressable(
        onTap: onTap,
        semanticLabel: face.label,
        child: shouldShowProBadge
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  button,
                  // 버튼 위로 걸쳐 그림·이름을 덮지 않게 둠
                  Positioned(
                    top: -context.space.sm.h,
                    right: 0,
                    child: const ProBadge(),
                  ),
                ],
              )
            : button,
      ),
    );
  }
}

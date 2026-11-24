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
    this.size = CardReviewToolSize.regular,
  });

  /// 버튼 크기 · 배치 (폰 한 줄 / 태블릿 큰 한 줄 / 가로 태블릿 큰 2×2)
  final CardReviewToolSize size;

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
    final tools = _tools(context);
    // 예약 PRO 배지가 아래로 튀어나오는 만큼 줄 아래를 비움 (아래 저장 버튼을 덮지 않게)
    if (schedule?.shouldShowProBadge ?? false) {
      return Padding(padding: EdgeInsets.only(bottom: ProBadgeHang.defaultHang.w), child: tools);
    }
    return tools;
  }

  /// 크기별 배치: 폰 한 줄 · 태블릿 큰 한 줄 · 가로 태블릿 2×2
  Widget _tools(BuildContext context) {
    final buttons = _buttons(context);
    if (size == CardReviewToolSize.largeGrid) return _grid(buttons);
    if (size == CardReviewToolSize.largeRow) return _wideRow(buttons);
    final gapCount = buttons.length - 1;
    final buttonWidth = (rowWidth - _buttonGap * gapCount) / buttons.length;
    return SizedBox(
      width: rowWidth.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final build in buttons) build(buttonWidth.w)],
      ),
    );
  }

  /// 세로 태블릿 큰 한 줄: 칸 폭을 버튼 수로 나눔
  Widget _wideRow(List<Widget Function(double width)> buttons) => LayoutBuilder(
    builder: (context, constraints) {
      final cellWidth = (constraints.maxWidth - _buttonGap.w * (buttons.length - 1)) / buttons.length;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final build in buttons) build(cellWidth)],
      );
    },
  );

  /// 가로 태블릿 2×2: 칸 폭을 반씩, 큰 칸
  Widget _grid(List<Widget Function(double width)> buttons) => LayoutBuilder(
    builder: (context, constraints) {
      final cellWidth = (constraints.maxWidth - _buttonGap.w) / 2;
      return Wrap(
        spacing: _buttonGap.w,
        runSpacing: _buttonGap.w,
        children: [for (final build in buttons) build(cellWidth)],
      );
    },
  );

  /// 도구 버튼들 (폭을 받아 그림): 순서 변경 · 이 카드 수정 · 카드 추가 · (예약)
  List<Widget Function(double width)> _buttons(BuildContext context) {
    final schedule = this.schedule;
    final isLarge = size != CardReviewToolSize.regular;
    final height = size.buttonHeight;
    return [
      (width) => _ToolButton(
        key: reorderKey,
        width: width,
        height: height,
        face: CardReviewToolFace(
          icon: AppAssets.iconInterlining,
          label: context.l10n.cardReviewToolReorder,
          isPressed: reorderMode,
          isLarge: isLarge,
        ),
        // 켜고 끄는 버튼이다 — 눌린 상태에서 다시 누르면 나온다(옮긴 순서는 둔다).
        onTap: reorderMode ? onFinishReorder : onReorder,
      ),
      (width) => _ToolButton(
        key: editKey,
        width: width,
        height: height,
        face: CardReviewToolFace(
          icon: AppAssets.iconPencilEdit,
          label: context.l10n.cardReviewToolEdit,
          isLarge: isLarge,
        ),
        isDimmed: reorderMode,
        onTap: reorderMode ? null : onEdit,
      ),
      (width) => _ToolButton(
        width: width,
        height: height,
        face: CardReviewToolFace(
          icon: AppAssets.iconPlus,
          label: context.l10n.cardReviewToolAdd,
          isLarge: isLarge,
        ),
        isDimmed: reorderMode,
        onTap: reorderMode ? null : onAdd,
      ),
      if (schedule != null)
        (width) => _ToolButton(
          key: schedule.coachKey,
          width: width,
          height: height,
          face: CardReviewToolFace(
            icon: AppAssets.iconCalendar,
            label: context.l10n.cardReviewToolSchedule,
            isActive: schedule.isActive,
            isLarge: isLarge,
            shouldShowProBadge: schedule.shouldShowProBadge,
          ),
          isDimmed: reorderMode,
          onTap: reorderMode ? null : schedule.onTap,
        ),
    ];
  }
}

/// 도구 버튼 크기 3가지: 폰 한 줄 60 · 태블릿 세로 큰 한 줄 76 · 태블릿 가로 큰 2×2 92 (#1457)
enum CardReviewToolSize {
  regular(60),
  largeRow(76),
  largeGrid(92);

  const CardReviewToolSize(this.buttonHeight);

  final double buttonHeight;
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
    this.isLarge = false,
    this.shouldShowProBadge = false,
  });

  /// Free 에게 권하는 도구: 아래 가장자리에 PRO 배지가 걸침 ([ProBadgeHang], 그림·이름 크기는 다른 도구와 같게 둠)
  final bool shouldShowProBadge;

  /// 태블릿 큰 칸: 그림 24 · 글 한 단계 큼
  final bool isLarge;

  final String icon;
  final String label;

  /// 눌린 색 (#D7D3D1)
  final bool isPressed;

  /// 켜진 도구 (예약을 골라 둠): 바탕은 그대로, 이름 진하게 + 오른쪽 위 진한 체크 점 (칸 크기·이름 그대로)
  final bool isActive;

  /// 그림 크기 (폰 16 · 태블릿 큰 칸 24)
  static const _iconSize = 16.0;
  static const _iconToLabel = 8.0;
  static const _largeIconToLabel = 10.0;
  static const _largeIconSize = 24.0;

  /// 체크 점 크기 · 체크 그림 · 위·오른쪽 여백
  static const _activeDotSize = 16.0;
  static const _activeCheckSize = 10.0;
  static const _activeDotInset = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelColor = isActive ? colors.textPrimary : colors.editChipLabel;
    final face = Container(
      decoration: BoxDecoration(
        color: isPressed ? colors.editChipPressedBg : colors.editChipBg,
        borderRadius: BorderRadius.circular(CardReviewToolRow.buttonRadius.r),
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
              width: (isLarge ? _largeIconSize : _iconSize).w,
              height: (isLarge ? _largeIconSize : _iconSize).w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            SizedBox(height: (isLarge ? _largeIconToLabel : _iconToLabel).h),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: (isLarge ? context.typo.body : context.typo.editChipLabel).copyWith(
                color: labelColor,
                fontWeight: isActive ? FontWeight.w800 : null,
              ),
            ),
          ],
        ),
      ),
    );
    if (shouldShowProBadge) return ProBadgeHang(isShown: true, child: face);
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
              color: colors.textPrimary,
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
    required this.height,
    required this.face,
    required this.onTap,
    this.isDimmed = false,
  });

  /// 버튼 폭 (화면 픽셀, 줄 폭을 버튼 수로 나눈 값) · 높이 (393 기준)
  final double width;
  final double height;
  final CardReviewToolFace face;
  final VoidCallback? onTap;

  /// 흐리게 (투명도 0.4)
  final bool isDimmed;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(width: width, height: height.h, child: face);
    return Opacity(
      opacity: isDimmed ? 0.4 : 1,
      child: AppPressable(
        onTap: onTap,
        semanticLabel: face.label,
        child: button,
      ),
    );
  }
}

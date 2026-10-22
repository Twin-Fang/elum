import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 빠른 메뉴 한 줄: 돌려줄 값 · 아이콘(`fi-br` SVG 경로) · 글자 · 붉게(되돌리기 어려운 동작)
typedef QuickMenuRow<T> = ({T value, String icon, String label, bool isDanger});

/// 길게 누른 칸 옆에 뜨는 메뉴 (#837, 시안 「이룸 일과관리 시안」)
///
/// 배경을 흐리게 하고, 누른 칸을 살짝 키워 그 자리에 두고, 아래(모자라면 위)에 작은 메뉴를 띄운다.
/// 고른 줄의 값을 돌려주고, 바깥을 누르면 null.
/// 페이드 없이 뜸: 누르는 동안 격자가 그린 미리보기([AnchoredQuickMenuView]) 자리를 이어받는다
/// (누르는 중에 route 를 띄우면 Navigator 가 손가락을 취소해 끌기가 끊김)
Future<T?> showAnchoredQuickMenu<T>(
  BuildContext context, {
  required Rect anchor,
  required Widget highlight,
  required List<QuickMenuRow<T>> rows,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: context.l10n.commonClose,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => AnchoredQuickMenuView<T>(
      anchor: anchor,
      highlight: highlight,
      rows: rows,
      onSelected: (value) => Navigator.of(context).pop(value),
      onDismissed: () => Navigator.of(context).pop(),
    ),
  );
}

/// 칸 옆 메뉴 모양 (흐린 배경 · 키운 칸 · 메뉴). [onSelected] 가 null 이면 누를 수 없는 미리보기
class AnchoredQuickMenuView<T> extends StatelessWidget {
  const AnchoredQuickMenuView({
    super.key,
    required this.anchor,
    required this.highlight,
    required this.rows,
    this.onSelected,
    this.onDismissed,
  });

  final Rect anchor;
  final Widget highlight;
  final List<QuickMenuRow<T>> rows;
  final ValueChanged<T>? onSelected;
  final VoidCallback? onDismissed;

  /// 메뉴 폭 · 줄 높이 · 칸과의 간격 · 화면 가장자리 여백 · 칸 왼쪽보다 앞으로 나오는 폭
  static const menuWidth = 230.0;
  static const rowHeight = 46.0;
  static const _gap = 8.0;
  static const _edge = 8.0;
  static const _anchorOutdent = 10.0;

  /// 누른 칸을 키우는 비율 · 배경 흐림 정도
  static const _highlightScale = 1.12;
  static const _blurSigma = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final scaledMenuWidth = menuWidth.w;
    final menuHeight = rowHeight.h * rows.length;

    // 아래에 자리가 모자라면 칸 위에 놓는다
    final below = anchor.bottom + _gap.h;
    final fitsBelow =
        below + menuHeight <=
        media.size.height - media.padding.bottom - _edge.h;
    final top = fitsBelow ? below : anchor.top - _gap.h - menuHeight;
    final left = (anchor.left - _anchorOutdent.w).clamp(
      _edge.w,
      media.size.width - scaledMenuWidth - _edge.w,
    );

    final onSelected = this.onSelected;
    return Stack(
      children: [
        // 흐린 배경 (누르면 닫힘)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismissed,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
              child: ColoredBox(
                color: colors.background.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        // 누른 칸: 같은 자리에서 살짝 커진다
        Positioned.fromRect(
          rect: anchor,
          // 대화창 위라 글 스타일을 주는 Material 이 없다 — 투명 Material 로 감싼다
          child: Material(
            type: MaterialType.transparency,
            child: IgnorePointer(
              child: Transform.scale(scale: _highlightScale, child: highlight),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: scaledMenuWidth,
          child: AnchoredQuickMenuPanel<T>(rows: rows, onSelected: onSelected),
        ),
      ],
    );
  }
}

/// 메뉴 판 (흰 판 r20 + 떠 있는 것 그림자): 줄 46 씩. 코치마크 시범도 같은 판을 쓴다
class AnchoredQuickMenuPanel<T> extends StatelessWidget {
  const AnchoredQuickMenuPanel({
    super.key,
    required this.rows,
    this.onSelected,
  });

  final List<QuickMenuRow<T>> rows;

  /// null 이면 누를 수 없는 미리보기
  final ValueChanged<T>? onSelected;

  /// 떠 있는 것 그림자 (시안 `0 4 20` 남색 25%, 떠 있는 알약 버튼과 같다)
  static const _shadowAlpha = 0.25;
  static const _shadowBlur = 20.0;
  static const _shadowOffsetY = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onSelected = this.onSelected;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        boxShadow: [
          BoxShadow(
            color: colors.buttonEnabled.withValues(alpha: _shadowAlpha),
            blurRadius: _shadowBlur,
            offset: Offset(0, _shadowOffsetY.h),
          ),
        ],
      ),
      // 대화창 위라 글 스타일을 주는 Material 이 없다 — 투명 Material 로 감싼다
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              _AnchoredMenuRow(
                row: row,
                height: AnchoredQuickMenuView.rowHeight.h,
                onTap: onSelected == null ? null : () => onSelected(row.value),
              ),
          ],
        ),
      ),
    );
  }
}

/// 메뉴 한 줄: 글 왼쪽 · 아이콘 20 오른쪽, 되돌리기 어려운 동작은 붉게
class _AnchoredMenuRow<T> extends StatelessWidget {
  const _AnchoredMenuRow({
    required this.row,
    required this.height,
    required this.onTap,
  });

  final QuickMenuRow<T> row;
  final double height;

  /// null 이면 미리보기라 누를 수 없다
  final VoidCallback? onTap;

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = row.isDanger
        ? colors.settingsDestructive
        : colors.settingsCardLabel;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.space.md.w),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: context.typo.settingsTileLabel.copyWith(color: color),
                ),
              ),
              SvgPicture.asset(
                row.icon,
                width: _iconSize.w,
                height: _iconSize.w,
                excludeFromSemantics: true,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

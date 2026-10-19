import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 빠른 메뉴 한 줄: 돌려줄 값 · 아이콘 · 글자 · 붉게(되돌리기 어려운 동작)
typedef QuickMenuRow<T> = ({
  T value,
  IconData icon,
  String label,
  bool isDanger,
});

/// 길게 누른 칸 옆에 뜨는 메뉴 (#837, 시안 「이룸 일과관리 시안」)
///
/// 배경을 흐리게 하고, 누른 칸을 살짝 키워 그 자리에 두고, 아래(모자라면 위)에 작은 메뉴를 띄운다.
/// 고른 줄의 값을 돌려주고, 바깥을 누르면 null.
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
    transitionDuration: AppMotion.fast,
    pageBuilder: (_, _, _) =>
        _AnchoredQuickMenu<T>(anchor: anchor, highlight: highlight, rows: rows),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _AnchoredQuickMenu<T> extends StatelessWidget {
  const _AnchoredQuickMenu({
    required this.anchor,
    required this.highlight,
    required this.rows,
  });

  final Rect anchor;
  final Widget highlight;
  final List<QuickMenuRow<T>> rows;

  /// 메뉴 폭 · 줄 높이 · 칸과의 간격 · 화면 가장자리 여백
  static const _menuWidth = 230.0;
  static const _rowHeight = 46.0;
  static const _gap = 8.0;
  static const _edge = 8.0;

  /// 누른 칸을 키우는 비율 · 배경 흐림 정도
  static const _highlightScale = 1.12;
  static const _blurSigma = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final menuWidth = _menuWidth.w;
    final menuHeight = _rowHeight.h * rows.length;

    // 아래에 자리가 모자라면 칸 위에 놓는다
    final below = anchor.bottom + _gap.h;
    final fitsBelow =
        below + menuHeight <=
        media.size.height - media.padding.bottom - _edge.h;
    final top = fitsBelow ? below : anchor.top - _gap.h - menuHeight;
    final left = (anchor.left - 10.w).clamp(
      _edge.w,
      media.size.width - menuWidth - _edge.w,
    );

    return Stack(
      children: [
        // 흐린 배경 (누르면 닫힘)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
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
          width: menuWidth,
          child: Material(
            color: colors.surface.withValues(alpha: 0.97),
            elevation: 12,
            borderRadius: BorderRadius.circular(16.r),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in rows)
                  _AnchoredMenuRow(
                    row: row,
                    height: _rowHeight.h,
                    onTap: () => Navigator.of(context).pop(row.value),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 메뉴 한 줄: 글 왼쪽 · 아이콘 오른쪽, 되돌리기 어려운 동작은 붉게
class _AnchoredMenuRow<T> extends StatelessWidget {
  const _AnchoredMenuRow({
    required this.row,
    required this.height,
    required this.onTap,
  });

  final QuickMenuRow<T> row;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = row.isDanger ? colors.danger : colors.textPrimary;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15.w),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: context.typo.tileLabel.copyWith(color: color),
                ),
              ),
              Icon(row.icon, size: 20.w, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

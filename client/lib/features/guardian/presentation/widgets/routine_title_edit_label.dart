import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 일과 제목 + 오른쪽 연필 (시안 1274:8186 제목 · 1931:7372 연필 16, 사이 8)
/// [onEditTap] 이 null 이면 연필 없이 제목만 (지난 일과 · 다 끝낸 일과 · 남이 만든 일과)
class RoutineTitleEditLabel extends StatelessWidget {
  const RoutineTitleEditLabel({
    super.key,
    required this.title,
    required this.language,
    required this.style,
    this.onEditTap,
  });

  final String title;

  /// 제목(일과 글)의 언어
  final String language;
  final TextStyle style;
  final VoidCallback? onEditTap;

  /// 연필 한 변 · 제목 > 연필 (시안 16 · 8)
  static const _pencilSize = 16.0;
  static const _titleToPencil = 8.0;

  @override
  Widget build(BuildContext context) {
    final titleText = ContentLocale(
      language: language,
      child: Text(title, style: style),
    );
    final onEditTap = this.onEditTap;
    if (onEditTap == null) return titleText;

    // 제목까지 함께 누르는 자리 (연필 16 만으로는 누르기 어렵다)
    return AppPressable(
      onTap: onEditTap,
      scaleDown: AppPressable.scaleNone,
      semanticLabel: context.l10n.routineTitleEdit,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: titleText),
          SizedBox(width: _titleToPencil.w),
          SvgPicture.asset(
            AppAssets.iconPencilEdit,
            width: _pencilSize.w,
            height: _pencilSize.w,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(
              context.colors.routineTitleEditIcon,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

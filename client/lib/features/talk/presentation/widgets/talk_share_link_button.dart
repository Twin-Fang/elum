import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 상세 공유하기 칩: 글 링크를 앱 밖으로 보낸다 (시안 없음 — 옆 도움돼요 칩 꺼짐 모양을 따름)
/// 누르면 칩 영역을 넘긴다 — 아이패드 공유 시트가 이 자리에서 팝오버로 뜬다
class TalkShareLinkButton extends StatelessWidget {
  const TalkShareLinkButton({super.key, required this.onPressed});

  final ValueChanged<Rect?> onPressed;

  /// 도움돼요 칩과 같은 값: 아이콘 20, 좌우 16 · 위아래 10, 모서리 20, 아이콘 > 글자 4
  static const _iconSize = 20.0;
  static const _paddingH = 16.0;
  static const _paddingV = 10.0;
  static const _radius = 20.0;
  static const _iconToLabel = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: AppPressable(
        onTap: () => onPressed(_globalRectOf(context)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _paddingH.w,
            vertical: _paddingV.h,
          ),
          decoration: BoxDecoration(
            color: colors.editChipBg,
            borderRadius: BorderRadius.circular(_radius.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppAssets.iconShare,
                width: _iconSize.w,
                height: _iconSize.w,
                colorFilter: ColorFilter.mode(
                  colors.talkMetaIcon,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: _iconToLabel.w),
              Text(
                context.l10n.talkShareLinkButton,
                style: context.typo.talkDetailStatLabel.copyWith(
                  color: colors.talkMetaText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 화면 기준 칩 영역 (아직 그려지기 전이면 null)
  static Rect? _globalRectOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

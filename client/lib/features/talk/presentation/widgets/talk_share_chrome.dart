import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_centered_title_row.dart';

/// 올리기 화면 머리 줄: 뒤로 | 이야기에 올리기
class TalkShareHeader extends StatelessWidget {
  const TalkShareHeader({super.key, required this.onBackPressed});

  final VoidCallback onBackPressed;

  static const _tapSize = 44.0;
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: space.xs.w,
        vertical: space.xs.h,
      ),
      child: ElumCenteredTitleRow(
        sideSlotWidth: _tapSize.w,
        leading: Semantics(
          button: true,
          label: l10n.commonBack,
          child: AppPressable(
            onTap: onBackPressed,
            scaleDown: AppPressable.scaleIcon,
            child: SizedBox(
              width: _tapSize.w,
              height: _tapSize.w,
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.iconBack,
                  width: _iconSize.w,
                  height: _iconSize.w,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          l10n.talkShareTitle,
          textAlign: TextAlign.center,
          style: context.typo.navTitle.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// 올리기 화면 하단 고정 버튼 (null 이면 꺼진다)
class TalkShareBottomButton extends StatelessWidget {
  const TalkShareBottomButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.screenH.w,
        space.xs.h,
        space.screenH.w,
        space.md.h,
      ),
      child: ElumButton(label: label, loading: isLoading, onPressed: onPressed),
    );
  }
}

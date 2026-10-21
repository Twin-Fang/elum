import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/l10n/content_locale.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_centered_title_row.dart';
import '../../../core/haptics/child_haptics.dart';

/// 뒤로가기 + 일과 제목 (Figma 1197:6775 상단).
///
/// 뒤로가기는 다른 화면과 같은 40×40 상자(x16 · y67)고, 제목 18/800 은 그 상자와
/// 세로 가운데(y78~96)에 놓인다. 캐릭터 배지는 없다.
class ChildRoutineDetailTopBar extends StatelessWidget {
  const ChildRoutineDetailTopBar({
    super.key,
    required this.onBack,
    required this.title,
    this.language = 'ko',
  });

  final VoidCallback onBack;

  /// 일과 제목 (`Routine.displayTitle`). 비어도 대체어가 온다.
  final String title;

  /// 제목(일과 글)의 언어. 뒤로가기 이름은 화면 문구라 따르지 않는다.
  final String language;

  /// 뒤로가기 상자 한 변 — 누를 자리와 그림 자리가 한 값이다 (ElumScaffold 와 같다).
  static const _box = 40.0;
  static const _left = 16.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 좌우 16 씩 같은 폭을 비워 제목이 정확히 가운데 온다
      padding: EdgeInsets.symmetric(horizontal: _left.w),
      child: ElumCenteredTitleRow(
        sideSlotWidth: _box.w,
        leading: AppPressable(
          onTap: () {
            playChildHaptic(context, ChildHapticKind.tap);
            onBack();
          },
          scaleDown: AppPressable.scaleIcon,
          semanticLabel: context.l10n.commonBack,
          child: SizedBox(
            width: _box.w,
            height: _box.w,
            child: Center(
              child: SvgPicture.asset(
                AppAssets.iconBack,
                width: 24.w,
                height: 24.w,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        title: ContentLocale(
          language: language,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typo.childDetailTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

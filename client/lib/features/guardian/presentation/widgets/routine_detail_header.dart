import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';

/// 스크롤해도 남는 머리 부분.
class RoutineDetailHeader extends StatelessWidget {
  const RoutineDetailHeader({
    super.key,
    required this.title,
    required this.language,
    this.caption,
  });

  final String title;

  /// 제목(일과 글)의 언어. 아래 caption 은 화면 문구라 따르지 않는다.
  final String language;

  /// 제목 아래 한 줄 (`엄마가 만든 일과예요`). 없으면 자리도 없다 — 내 일과의 시트는 그대로다.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      // 배경이 없으면 스크롤되는 목록이 제목 뒤로 비친다 (덤프의 `스크롤 시 fix 영역`에도
      // background 사각형이 따로 있다).
      color: colors.background,
      // 시안(980:5146) 헤더는 68 높이다 — 손잡이 16 · 제목 40~60 · 아래 8.
      // 아래를 16 으로 두면 헤더가 76 이 되어 목록 전체가 8 씩 밀린다.
      //
      // 위는 **12**다. 16 으로 두어 손잡이가 시안보다 4 내려가 있었다.
      // 아래 제목까지의 간격에서 그 4 를 되돌려 주므로 목록은 제자리다.
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: ElumSheetHandle()),
          // 위 여백에서 줄인 4 를 여기서 되돌린다 — 손잡이만 올라가고 제목·목록은 시안 자리에 그대로 있다
          SizedBox(height: 24.h),
          ContentLocale(
            language: language,
            child: Text(
              title,
              style: context.typo.sheetTitle.copyWith(
                color: colors.sheetTitleText,
              ),
            ),
          ),
          if (caption != null) ...[
            SizedBox(height: 4.h),
            Text(
              caption!,
              style: context.typo.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

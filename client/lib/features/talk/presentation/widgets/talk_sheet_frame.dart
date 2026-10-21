import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';

/// 이야기 시트 공통 틀: 제목 > 본문, 키보드가 올라와도 남은 높이 안에서 스크롤
class TalkSheetFrame extends StatelessWidget {
  const TalkSheetFrame({super.key, this.title, required this.child});

  /// null 이면 제목 줄 없음 (메뉴 시트)
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final media = MediaQuery.of(context);
    final title = this.title;
    // 바닥 시트 라우트가 padding.top 을 0 으로 지우므로 viewPadding 으로 상태 표시줄 높이를 읽는다
    final availableHeight =
        media.size.height - media.viewInsets.bottom - media.viewPadding.top;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ElumSheetSurface(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(0, availableHeight - space.md.h),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              space.md.w,
              space.lg.h,
              space.md.w,
              space.md.h + media.padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Text(
                    title,
                    style: context.typo.sectionTitle.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: space.sm.h),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

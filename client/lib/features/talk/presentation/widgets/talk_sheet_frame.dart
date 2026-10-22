import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';

/// 이야기 시트 공통 틀 (시안 시트 1759:9649 결): 제목 > 설명 > 본문, 키보드가 올라와도 남은 높이 안에서 스크롤
/// 제목 · 설명은 본문보다 8 안쪽(x=24)에서 시작하고, 본문은 시트 좌우 16 을 쓴다 (입력칸 · 버튼 361 폭)
class TalkSheetFrame extends StatelessWidget {
  const TalkSheetFrame({
    super.key,
    this.title,
    this.description,
    required this.child,
  });

  /// null 이면 제목 줄 없음 (메뉴 시트)
  final String? title;

  /// 제목 아래 한 줄 안내. null 이면 자리도 없다
  final String? description;
  final Widget child;

  /// 시안 실측 (시트 윗변 기준): 제목 40 · 제목 > 설명 8 · 머리 > 본문 24 · 바닥 22
  static const _titleTop = 40.0;
  static const _menuTop = 32.0;
  static const _titleToDescription = 8.0;
  static const _headerToBody = 24.0;
  static const _bottomGap = 22.0;

  /// 제목 · 설명이 본문보다 더 들어가는 폭 (24 - 16)
  static const _textInset = 8.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    final typo = context.typo;
    final media = MediaQuery.of(context);
    final title = this.title;
    final description = this.description;
    // 바닥 시트 라우트가 안쪽 MediaQuery 의 top 을 padding·viewPadding 모두 지우므로 창 기준으로 읽는다
    final statusBarHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewPadding.top;
    final availableHeight =
        media.size.height - media.viewInsets.bottom - statusBarHeight;

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
              (title == null ? _menuTop : _titleTop).h,
              space.md.w,
              _bottomGap.h + media.padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  // 머리: 제목 > 설명 (시트가 올라오는 동안 살짝 늦게 떠오른다)
                  AppFadeSlideIn(
                    offset: 8,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: _textInset.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: typo.sheetTitle.copyWith(
                              color: colors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (description != null) ...[
                            SizedBox(height: _titleToDescription.h),
                            Text(
                              // 어절 중간에서 꺾이지 않게
                              keepWords(description, locale: context.appLocale),
                              semanticsLabel: description,
                              style: typo.talkEmptyBody.copyWith(
                                color: colors.talkMetaText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: _headerToBody.h),
                ],
                AppFadeSlideIn(
                  delay: const Duration(
                    milliseconds: AppMotion.staggerDelayMs * 2,
                  ),
                  offset: 12,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

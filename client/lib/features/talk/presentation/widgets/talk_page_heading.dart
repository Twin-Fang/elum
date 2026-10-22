import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';

/// 올리기 단계 머리: 큰 제목(700/20, 상세 글 제목 결) > 안내 한 줄
/// 본문이 좌우 16 을 쓰므로 글은 8 더 들어가 x=24 에서 시작한다 (시트 머리와 같은 줄)
class TalkPageHeading extends StatelessWidget {
  const TalkPageHeading({super.key, required this.title, this.description});

  final String title;
  final String? description;

  static const _textInset = 8.0;
  static const _titleToDescription = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final description = this.description;
    return AppFadeSlideIn(
      offset: 8,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _textInset.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: typo.talkDetailTitle.copyWith(color: colors.talkTitleText),
            ),
            if (description != null) ...[
              SizedBox(height: _titleToDescription.h),
              Text(
                // 어절 중간에서 꺾이지 않게
                keepWords(description, locale: context.appLocale),
                semanticsLabel: description,
                style: typo.talkEmptyBody.copyWith(color: colors.talkMetaText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

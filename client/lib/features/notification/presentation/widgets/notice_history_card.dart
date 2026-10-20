import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/utils/open_notice_link.dart';
import '../../../notice/domain/app_notice.dart';

/// 공지 탭의 공지 한 건: (그림) · 제목(**강조** 민트) · 본문 · (버튼) · 올라온 날짜
class NoticeHistoryCard extends StatefulWidget {
  const NoticeHistoryCard({super.key, required this.notice});

  final NoticeHistoryItem notice;

  @override
  State<NoticeHistoryCard> createState() => _NoticeHistoryCardState();
}

class _NoticeHistoryCardState extends State<NoticeHistoryCard> {
  static const _padding = 16.0;
  static const _imageRatio = 16 / 10; // 팝업과 같은 그림 비율
  static const _imageToTitle = 12.0;
  static const _titleToBody = 8.0;
  static const _bodyToButton = 14.0;
  static const _buttonHeight = 44.0;
  static const _buttonRadius = 8.0;
  static const _dateTopGap = 12.0;

  bool _isImageFailed = false;
  bool _isOpeningLink = false;

  Future<void> _onButtonPressed(Uri url) async {
    // 빨리 두 번 눌러도 브라우저는 한 번만 연다
    if (_isOpeningLink) return;
    _isOpeningLink = true;
    await openNoticeLink(url);
    _isOpeningLink = false;
  }

  void _onImageError() {
    if (_isImageFailed) return;
    // errorBuilder 는 그리는 중에 불린다 — 다음 프레임에 자리째 없앤다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isImageFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final notice = widget.notice;
    final titleParts = parseNoticeTitle(notice.title);
    final keptTitleParts = keepWordsParts(
      [for (final part in titleParts) part.text],
      locale: context.appLocale,
    );
    final imageUrl = notice.imageUrl;
    final button = notice.button;
    final dateLabel =
        context.l10n.yearMonthDay(notice.visibleSince.toLocal());

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.creditCardBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null && !_isImageFailed) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(_buttonRadius.r),
                child: AspectRatio(
                  aspectRatio: _imageRatio,
                  child: Image(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    frameBuilder: (context, child, frame, isSync) =>
                        frame == null && !isSync
                            ? ColoredBox(color: colors.noticeImagePlaceholder)
                            : child,
                    errorBuilder: (context, error, stack) {
                      _onImageError();
                      return ColoredBox(color: colors.noticeImagePlaceholder);
                    },
                  ),
                ),
              ),
              SizedBox(height: _imageToTitle.h),
            ],
            Text.rich(
              TextSpan(
                children: [
                  for (final (index, part) in titleParts.indexed)
                    TextSpan(
                      text: keptTitleParts[index],
                      style: part.emphasized
                          ? TextStyle(color: colors.checkDone)
                          : null,
                    ),
                ],
              ),
              semanticsLabel: titleParts.map((part) => part.text).join(),
              style: typo.noticeTitle.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: _titleToBody.h),
            Text(
              keepWords(notice.body, locale: context.appLocale),
              semanticsLabel: notice.body,
              style: typo.noticeBody.copyWith(color: colors.textPrimary),
            ),
            if (button != null) ...[
              SizedBox(height: _bodyToButton.h),
              AppPressable(
                onTap: () => _onButtonPressed(button.url),
                child: Container(
                  height: _buttonHeight.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.buttonEnabled,
                    borderRadius: BorderRadius.circular(_buttonRadius.r),
                  ),
                  child: Text(
                    button.label,
                    style: typo.button.copyWith(color: colors.buttonEnabledText),
                  ),
                ),
              ),
            ],
            SizedBox(height: _dateTopGap.h),
            Text(
              dateLabel,
              style: typo.creditHistoryRowDetail.copyWith(
                color: colors.creditHistoryMutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

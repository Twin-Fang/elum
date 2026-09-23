import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/app_notice.dart';
import 'notice_controls.dart';

/// 그림 주소를 그릴 수 있는 이미지로 바꾼다. 테스트는 네트워크 대신 메모리 그림을 넣는다.
typedef NoticeImageResolver = ImageProvider Function(String url);

/// 공지 슬라이드 한 장 — 위 그림, 아래 제목·본문·버튼 (명세 2-1).
class NoticeSlide extends StatelessWidget {
  const NoticeSlide({
    super.key,
    required this.notice,
    required this.showImageArea,
    required this.imageFailed,
    required this.textMaxHeight,
    required this.imageFor,
    required this.onImageError,
    required this.onOpenLink,
    required this.linkFailed,
    this.measuring = false,
  });

  final AppNotice notice;

  /// 그림 자리를 둘지. **카드 단위로 정한다** — 한 장이라도 그림이 있으면 모든 장에
  /// 두어 넘길 때마다 카드 높이가 튀지 않게 한다(N28).
  final bool showImageArea;

  /// 이 장의 그림을 못 불러왔다(N3). 자리는 [showImageArea] 가 정한다.
  final bool imageFailed;

  /// 글 자리 최대 높이 — 화면의 45% (N4).
  final double textMaxHeight;
  final NoticeImageResolver imageFor;
  final void Function(String noticeId, Object error) onImageError;
  final VoidCallback onOpenLink;
  final bool linkFailed;

  /// 카드 높이를 재려고 보이지 않게 그리는 사본인가. 사본은 그림을 불러오지 않는다.
  final bool measuring;

  /// 에러 코드 — 제보를 받았을 때 링크 열기에서 터졌다는 것을 가린다.
  static const linkFailureCode = 'E-NOTICE-LINK';

  static const _imageRatio = 16 / 10;
  static const _pad = 20.0;
  static const _titleToBody = 8.0;
  static const _textToButton = 16.0;
  static const _bottom = 16.0;

  /// 링크 버튼 — 공통 팝업 주 버튼과 같은 색·모서리, 높이 44 (명세 3-2).
  static const _buttonMinWidth = 120.0;
  static const _buttonRadius = 8.0;
  static const _buttonPadH = 20.0;
  static const _buttonPadV = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final button = notice.button;

    // 카드 높이는 가장 긴 장에 맞춘다. 짧은 장에 남는 자리는 글과 버튼 **사이**로
    // 보낸다 — 버튼이 장마다 같은 자리(점 바로 위)에 있어야 넘기면서 찾지 않는다.
    // 여유가 없을 때(높이를 재는 사본)는 spaceBetween 이 아무것도 벌리지 않는다.
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: _imageAndText(context)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (button != null) ...[
                const SizedBox(height: _textToButton),
                _linkButton(context, button),
              ],
              if (linkFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(_pad, 8, _pad, 0),
                  child: Text(
                    '링크를 열지 못했어요 ($linkFailureCode)',
                    textAlign: TextAlign.center,
                    style: typo.noticeBody.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: _bottom),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageAndText(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final id = notice.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showImageArea)
          AspectRatio(aspectRatio: _imageRatio, child: _image(context)),
        // 제목까지 글 자리에 넣는다. 글꼴 2.0 에서 40자 제목이 여섯 줄이 되면 제목을
        // 고정한 채로는 버튼이 카드 밖으로 밀린다. 짧을 때는 스크롤이 생기지 않아
        // 본문만 스크롤되는 것과 똑같이 보인다.
        Flexible(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_pad, _pad, _pad, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: textMaxHeight),
              child: SingleChildScrollView(
                key: ValueKey('notice-scroll-$id'),
                child: Column(
                  children: [
                    Text.rich(
                      key: ValueKey('notice-title-$id'),
                      TextSpan(
                        children: [
                          for (final part in parseNoticeTitle(notice.title))
                            TextSpan(
                              text: part.text,
                              style: part.emphasized
                                  ? TextStyle(color: colors.checkDone)
                                  : null,
                            ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      // 공통 팝업 제목과 같은 순검정 (#318)
                      style: typo.noticeTitle.copyWith(
                        color: colors.dialogTitleText,
                      ),
                    ),
                    const SizedBox(height: _titleToBody),
                    Text(
                      notice.body,
                      key: ValueKey('notice-body-$id'),
                      textAlign: TextAlign.center,
                      style: typo.noticeBody.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _image(BuildContext context) {
    final placeholder = context.colors.noticeImagePlaceholder;
    final url = notice.imageUrl;

    // 그림이 없거나 못 불러온 장 — 다른 장에 그림이 있을 때만 여기 온다(N28·N3)
    if (url == null || imageFailed) {
      return ColoredBox(
        key: ValueKey('notice-image-empty-${notice.id}'),
        color: placeholder,
      );
    }
    if (measuring) return const SizedBox.expand();

    return Image(
      key: ValueKey('notice-image-${notice.id}'),
      image: imageFor(url),
      fit: BoxFit.cover,
      // 제목·본문이 내용을 다 말한다. 그림은 꾸밈이라 낭독기가 읽지 않는다.
      excludeFromSemantics: true,
      // 받는 동안 흰 빈칸 대신 연한 배경을 둔다
      frameBuilder: (context, child, frame, sync) =>
          frame == null && !sync ? ColoredBox(color: placeholder) : child,
      errorBuilder: (context, error, stack) {
        onImageError(notice.id, error);
        return ColoredBox(color: placeholder);
      },
    );
  }

  Widget _linkButton(BuildContext context, NoticeButton button) {
    final colors = context.colors;
    return AppPressable(
      onTap: measuring ? null : onOpenLink,
      // Container(alignment:) 를 쓰지 않는다 — 느슨한 폭을 받으면 끝까지 늘어나
      // 참고 화면의 가운데 작은 버튼이 아니라 폭을 꽉 채운 버튼이 된다.
      child: ConstrainedBox(
        key: ValueKey('notice-link-${notice.id}'),
        // 높이를 못 박지 않는다 — 글꼴을 키운 보호자에게 글자가 잘린다 (docs/08 §7-2)
        constraints: const BoxConstraints(
          minHeight: noticeTapTarget,
          minWidth: _buttonMinWidth,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.checkDone,
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _buttonPadH,
              vertical: _buttonPadV,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                button.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.typo.noticeAction.copyWith(
                  color: colors.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

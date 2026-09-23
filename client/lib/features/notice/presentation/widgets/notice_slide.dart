// 파일 이름은 #371 의 "슬라이드 한 장"에서 왔다. #390 에서 슬라이드를 없애고 공지 한 건의
// 내용(그림·제목·본문)만 남았다. 이름을 바꾸려면 옛 파일을 지워야 해서 그대로 둔다.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../domain/app_notice.dart';

/// 그림 주소를 그릴 수 있는 이미지로 바꾼다. 테스트는 네트워크 대신 메모리 그림을 넣는다.
typedef NoticeImageResolver = ImageProvider Function(String url);

/// 공지 한 건의 글 자리 — (그림) · 제목 · 본문 (시안 1090:4922 `내용`).
///
/// 줄바꿈은 **어절 단위다** ([keepWords]). 관리자 미리보기와 같은 줄에서 끊기게 한다(#385 A).
/// 낭독기에는 표시 없는 원문을 준다.
class NoticeContent extends StatelessWidget {
  const NoticeContent({
    super.key,
    required this.notice,
    required this.showImage,
    required this.imageFor,
    required this.onImageError,
  });

  final AppNotice notice;

  /// 그림을 그릴지. 주소가 있고 아직 실패하지 않았을 때만 true — 실패하면 자리째 없앤다(N3).
  final bool showImage;
  final NoticeImageResolver imageFor;
  final void Function(Object error) onImageError;

  /// 시안 — 제목↔본문 20.
  static const titleToBody = 20.0;

  /// 그림↔제목. 공통 팝업의 아이콘↔제목(20)과 같다 — 그림이 아이콘 자리를 차지한다.
  static const imageToTitle = 20.0;

  /// 그림 16:10 — 관리자 화면이 권하는 비율(1280×800)과 같다.
  static const imageRatio = 16 / 10;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final id = notice.id;
    final title = parseNoticeTitle(notice.title);
    final kept = keepWordsParts([for (final part in title) part.text]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 주소가 있을 때만 그린다. `!` 로 풀지 않는다 — null 이면 화면이 통째로 죽는다.
        if (showImage && notice.imageUrl != null) ...[
          _image(context, notice.imageUrl as String),
          SizedBox(height: imageToTitle.h),
        ],
        // 제목·본문을 제 노드로 세운다. 안 세우면 아래 버튼의 누름 동작이 이 글들과
        // 한 노드로 합쳐져 버튼 영역이 글까지 덮는다 (#385 C).
        Semantics(
          container: true,
          child: Text.rich(
            key: ValueKey('notice-title-$id'),
            TextSpan(
              children: [
                for (final (i, part) in title.indexed)
                  TextSpan(
                    text: kept[i],
                    style: part.emphasized
                        ? TextStyle(color: colors.checkDone)
                        : null,
                  ),
              ],
            ),
            semanticsLabel: title.map((p) => p.text).join(),
            textAlign: TextAlign.center,
            // 공통 팝업 제목과 같은 순검정 (#318)
            style: typo.noticeTitle.copyWith(color: colors.dialogTitleText),
          ),
        ),
        SizedBox(height: titleToBody.h),
        Semantics(
          container: true,
          child: Text(
            keepWords(notice.body),
            key: ValueKey('notice-body-$id'),
            semanticsLabel: notice.body,
            textAlign: TextAlign.center,
            // 시안 본문도 제목과 같은 순검정이다(1090:4903 #000000)
            style: typo.noticeBody.copyWith(color: colors.dialogTitleText),
          ),
        ),
      ],
    );
  }

  /// **시안 밖이다** (#390). 그림 있는 공지 변형은 디자이너 시안 전이라, 공통 팝업
  /// 규칙 안에서 임시로 둔다 — 아이콘 자리(제목 위)에 카드 안쪽 폭 그대로, 모서리는
  /// 같은 카드 안의 버튼과 같은 8. 시안이 오면 이 자리만 바꾼다.
  Widget _image(BuildContext context, String url) {
    final placeholder = context.colors.noticeImagePlaceholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ElumDialogButton.radius.r),
      child: AspectRatio(
        aspectRatio: imageRatio,
        child: Image(
          key: ValueKey('notice-image-${notice.id}'),
          image: imageFor(url),
          fit: BoxFit.cover,
          // 제목·본문이 내용을 다 말한다. 그림은 꾸밈이라 낭독기가 읽지 않는다.
          excludeFromSemantics: true,
          // 받는 동안 흰 빈칸 대신 연한 배경을 둔다
          frameBuilder: (context, child, frame, sync) =>
              frame == null && !sync ? ColoredBox(color: placeholder) : child,
          errorBuilder: (context, error, stack) {
            onImageError(error);
            return ColoredBox(color: placeholder);
          },
        ),
      ),
    );
  }
}

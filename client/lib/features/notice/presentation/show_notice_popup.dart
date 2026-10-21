import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../domain/app_notice.dart';
import 'notice_popup.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../shared/utils/open_notice_link.dart';

/// 링크를 연다. 열었으면 true. 테스트는 브라우저 대신 가짜를 넣는다.
typedef NoticeLinkOpener = Future<bool> Function(Uri url);

ImageProvider _networkImage(String url) => NetworkImage(url);

/// 공지 팝업이 어떻게 닫혔나 — 로그에 남긴다.
enum NoticeCloseHow {
  /// `닫기` 버튼
  close,

  /// 링크 버튼 — 브라우저를 열고 닫힌다
  link,

  /// 바깥(어두운 배경) 또는 안드로이드 뒤로가기. 둘은 같은 길로 닫혀 가릴 수 없다.
  outside,
}

/// 공지 팝업이 닫힌 뒤 돌려받는 것.
@immutable
class NoticePopupResult {
  const NoticePopupResult({required this.how, required this.hide});

  final NoticeCloseHow how;

  /// `보지 않기` 를 체크한 채 닫았나. **어떻게 닫았든** 체크돼 있으면 숨긴다.
  final bool hide;
}

/// 공지 한 건을 띄우고, **닫히는 모습이 끝난 뒤에** 결과를 돌려준다.
///
/// 끝날 때까지 기다리는 이유 — 다음 공지가 바로 이어서 뜬다. 앞 팝업이 사라지는
/// 중에 다음 팝업을 올리면 어두운 막이 두 겹으로 겹쳐 한순간 더 어두워진다.
Future<NoticePopupResult> showNoticePopup(
  BuildContext context,
  AppNotice notice, {
  required int hideDays,
  NoticeLinkOpener openLink = openNoticeLink,
  NoticeImageResolver imageFor = _networkImage,
}) async {
  // dispose 하지 않는다. 닫히는 애니메이션 동안에도 카드가 이 값을 읽는다 —
  // 결과가 먼저 돌아오므로 여기서 버리면 사라지는 카드가 버려진 값을 만진다.
  final hide = ValueNotifier(false);
  final navigator = Navigator.of(context);
  final route = DialogRoute<NoticeCloseHow>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.noticeCloseBarrier,
    // 공통 팝업과 같은 dim — 검정 50%
    barrierColor: context.colors.dialogScrim,
    // 공통 팝업처럼 화면 전체 가운데에 둔다. 안전영역은 카드가 스스로 피한다.
    useSafeArea: false,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (dialogContext) => NoticePopupCard(
      notice: notice,
      hideDays: hideDays,
      hideChecked: hide,
      onClose: () => Navigator.of(dialogContext).pop(NoticeCloseHow.close),
      onLinkOpened: () => Navigator.of(dialogContext).pop(NoticeCloseHow.link),
      openLink: openLink,
      imageFor: imageFor,
    ),
  );
  final how = await navigator.push(route);
  await route.completed;
  return NoticePopupResult(
    how: how ?? NoticeCloseHow.outside,
    hide: hide.value,
  );
}

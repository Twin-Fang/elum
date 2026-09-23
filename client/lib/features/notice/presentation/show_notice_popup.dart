import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logger/app_logger.dart';
import '../domain/app_notice.dart';
import 'notice_popup.dart';

/// 링크를 연다. 열었으면 true. 테스트는 브라우저 대신 가짜를 넣는다.
typedef NoticeLinkOpener = Future<bool> Function(Uri url);

/// 링크를 **외부 브라우저로** 연다 (명세 3-2).
///
/// 앱 안 웹뷰로 열지 않는다 — 보호자가 앱으로 돌아오는 길을 잃지 않게, 그리고
/// 외부 페이지가 앱의 모양을 흉내 내지 못하게.
///
/// 서버가 `https://` 만 저장하게 막지만 **여기서 한 번 더 거른다(N12).**
Future<bool> openNoticeLink(Uri url) async {
  if (url.scheme != 'https' || url.host.isEmpty) return false;
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (e, st) {
    // 주소 전체를 남기지 않는다 — 공지 로그에는 원문을 두지 않는다 (#385 D)
    AppLogger.error('notice', e, st, {'step': 'openLink', 'host': url.host});
    return false;
  }
}

ImageProvider _networkImage(String url) => NetworkImage(url);

/// 공지 팝업이 어떻게 닫혔나 — 로그에 남긴다 (#385 D).
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

/// 배경 막을 읽어 줄 이름 (#385 C). 앱에 한국어 지역화가 없어 기본값이 영어 `Dismiss`
/// 로 읽혔다. 이번에는 공지 팝업에서만 이름을 준다 — 앱 전체 지역화는 따로 다룬다.
const noticeBarrierLabel = '공지 닫기';

/// 공지 한 건을 띄우고, **닫히는 모습이 끝난 뒤에** 결과를 돌려준다.
///
/// 끝날 때까지 기다리는 이유 — 다음 공지가 바로 이어서 뜬다(#390). 앞 팝업이 사라지는
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
    barrierLabel: noticeBarrierLabel,
    // 공통 팝업과 같은 dim — 검정 50%
    barrierColor: Colors.black.withValues(alpha: 0.5),
    // 공통 팝업처럼 화면 전체 가운데에 둔다 (#297). 안전영역은 카드가 스스로 피한다.
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

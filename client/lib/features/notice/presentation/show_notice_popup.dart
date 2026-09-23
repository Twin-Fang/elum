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
    AppLogger.error('notice', e, st, {'step': 'openLink', 'url': '$url'});
    return false;
  }
}

ImageProvider _networkImage(String url) => NetworkImage(url);

/// 공지 팝업을 띄우고, 닫힌 뒤 **"보지 않기"를 체크했는지** 돌려준다.
///
/// ✕·바깥(어두운 배경)·안드로이드 뒤로가기 — 어떻게 닫든 같다(명세 2장 "닫기").
/// 체크 상태를 팝업 밖에 두는 이유가 이것이다. 바깥을 눌러 닫히면 팝업은 값을
/// 돌려주지 못하고 사라진다.
Future<bool> showNoticePopup(
  BuildContext context,
  NoticeFeed feed, {
  NoticeLinkOpener openLink = openNoticeLink,
  NoticeImageResolver imageFor = _networkImage,
}) async {
  // dispose 하지 않는다. 닫히는 애니메이션 동안에도 카드가 이 값을 읽는다 —
  // 결과가 먼저 돌아오므로 여기서 버리면 사라지는 카드가 버려진 값을 만진다.
  final hide = ValueNotifier(false);
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    // 공통 팝업과 같은 dim — 검정 50%
    barrierColor: Colors.black.withValues(alpha: 0.5),
    // 카드가 안전영역 안에 머무는 것은 카드가 스스로 계산한다
    useSafeArea: false,
    builder: (dialogContext) => NoticePopupCard(
      feed: feed,
      hideChecked: hide,
      onClose: () => Navigator.of(dialogContext).pop(),
      openLink: openLink,
      imageFor: imageFor,
    ),
  );
  return hide.value;
}

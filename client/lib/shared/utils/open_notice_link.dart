import 'package:url_launcher/url_launcher.dart';

import '../../core/logger/app_logger.dart';

/// 공지 링크를 **외부 브라우저로** 연다 (앱 안 웹뷰 금지). 열었으면 true
///
/// 서버가 `https://` 만 저장하게 막지만 여기서 한 번 더 거른다 (N12).
/// 공지 팝업·알림 화면 공지 탭이 함께 씀
Future<bool> openNoticeLink(Uri url) async {
  if (url.scheme != 'https' || url.host.isEmpty) return false;
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (e, st) {
    // 주소 전체를 남기지 않는다 — 공지 로그에는 원문을 두지 않는다
    AppLogger.error('notice', e, st, {'step': 'openLink', 'host': url.host});
    return false;
  }
}

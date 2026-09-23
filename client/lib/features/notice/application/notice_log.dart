import '../../../core/logger/app_logger.dart';
import '../domain/app_notice.dart';

/// 공지가 **떴는지·왜 안 떴는지** 남긴다 (이슈 #385 D).
///
/// 운영 실측에서 성공 경로의 공지 로그가 0줄이었다. "공지가 안 떠요" 제보를 받으면
/// 서버가 안 준 것인지, 이 휴대폰에서 숨긴 것인지, 이룸이 휴대폰이라 건너뛴 것인지,
/// 이번 실행에 이미 띄운 것인지 가릴 수 없었다.
///
/// **원문을 남기지 않는다** (루트 원칙 5). 제목·본문·링크는 관리자가 쓴 글이지만
/// 로그에 글을 흘리는 습관을 만들지 않는다. id 앞 8자리 · 판 · 동작만 남긴다.
abstract final class NoticeLog {
  static const _screen = 'notice';

  /// 로그에 적는 공지 표시 — `c056722d@2`. 앞 8자리면 운영 공지끼리 겹치지 않는다.
  static String ref(AppNotice notice) {
    final id = notice.id.length > 8 ? notice.id.substring(0, 8) : notice.id;
    return '$id@${notice.revision}';
  }

  /// 여러 공지를 한 줄로. 목록 그대로 넘기면 개발자 도구가 꺼진 빌드에서
  /// `[3 items]` 로 줄어 무엇을 받았는지 사라진다.
  static String refs(Iterable<AppNotice> notices) => notices.map(ref).join(',');

  static void event(String name, [Map<String, dynamic>? data]) =>
      AppLogger.uiEvent(_screen, name, data);
}

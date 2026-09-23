import 'package:flutter/foundation.dart';

/// 공지 한 건 (이슈 #371 · #390 · 서버 #370 `AppNoticeResponse`). 팝업 하나에 하나씩 뜬다.
@immutable
class AppNotice {
  const AppNotice({
    required this.id,
    required this.revision,
    required this.title,
    required this.body,
    this.imageUrl,
    this.button,
  });

  /// 숨김 기록의 열쇠.
  final String id;

  /// 판. 관리자가 "다시 보이게"로 저장하면 오른다 — 숨길 때 적어 둔 값과 다르면 다시 뜬다.
  final int revision;

  /// `**…**` 표기가 그대로 들어 있다. 그릴 때 [parseNoticeTitle] 로 나눈다.
  final String title;
  final String body;

  /// 바로 불러올 수 있는 절대 주소. 없거나 읽지 못하면 null.
  final String? imageUrl;
  final NoticeButton? button;
}

/// 공지 버튼. `https://` 만 받는다 (N12).
@immutable
class NoticeButton {
  const NoticeButton({required this.label, required this.url});

  final String label;
  final Uri url;
}

/// 이번 실행에 차례로 띄울 공지 묶음.
@immutable
class NoticeFeed {
  const NoticeFeed({required this.hideDays, required this.notices});

  /// "보지 않기"로 숨길 일수. 서버 설정 `NOTICE_HIDE_DAYS`(1~30).
  final int hideDays;

  /// 띄울 순서대로. 서버가 우선순위 순으로 준다.
  final List<AppNotice> notices;

  static const defaultHideDays = 7;

  /// 서버가 최대 5개를 주지만 앱도 한 번 더 자른다 — 홈에 들어오자마자 팝업이
  /// 끝없이 이어지면 홈을 쓸 수 없다.
  static const maxNotices = 5;

  static const empty = NoticeFeed(hideDays: defaultHideDays, notices: []);

  /// **어떤 형식이 와도 예외를 던지지 않는다** (N2).
  ///
  /// 공지는 부가 기능이다. 응답이 깨졌다고 보호자 홈이 죽으면 안 되고,
  /// 항목 하나가 깨졌다고 나머지 공지까지 버리면 관리자가 올린 다른 안내가 사라진다.
  /// 그래서 **그 항목만** 버린다.
  ///
  /// [baseUrl] 은 서버 주소다. #370 은 이미지를 `/api/app/notices/{id}/image?v=…`
  /// 처럼 경로로만 보내므로 여기서 붙여 둔다.
  factory NoticeFeed.fromJson(Object? json, {required String baseUrl}) {
    if (json is! Map) return empty;

    final raw = json['notices'];
    final notices = <AppNotice>[];
    final seen = <String>{};
    if (raw is List) {
      for (final entry in raw) {
        final notice = _readNotice(entry, baseUrl);
        // 같은 id 가 두 번 오면 숨김 열쇠가 겹친다. 앞의 것(우선순위 높은 쪽)만 쓴다.
        if (notice == null || !seen.add(notice.id)) continue;
        notices.add(notice);
        if (notices.length == maxNotices) break;
      }
    }
    return NoticeFeed(
      hideDays: _readHideDays(json['hideDays']),
      notices: List.unmodifiable(notices),
    );
  }

  /// 없거나 숫자가 아니면 기본 7, 범위 밖이면 서버 규칙(1~30)으로 자른다.
  static int _readHideDays(Object? raw) {
    if (raw is! num) return defaultHideDays;
    return raw.toInt().clamp(1, 30);
  }

  static AppNotice? _readNotice(Object? entry, String baseUrl) {
    if (entry is! Map) return null;

    final id = entry['id'];
    if (id is! String || id.trim().isEmpty) return null;

    // 숨김 판단의 열쇠라 없으면 쓸 수 없다. 2.0 처럼 정수로 떨어지는 값은 받아 준다.
    final revision = entry['revision'];
    if (revision is! num || revision != revision.roundToDouble()) return null;

    final title = entry['title'];
    final body = entry['body'];
    if (title is! String || _visible(title).trim().isEmpty) return null;
    if (body is! String || body.trim().isEmpty) return null;

    return AppNotice(
      id: id,
      revision: revision.toInt(),
      title: title,
      body: body,
      imageUrl: _resolveImage(entry['imageUrl'], baseUrl),
      button: _readButton(entry['button']),
    );
  }

  /// 절대 주소면 그대로, `/` 로 시작하는 경로면 서버 주소에 붙인다. 나머지는 버린다.
  static String? _resolveImage(Object? raw, String baseUrl) {
    if (raw is! String) return null;
    final value = raw.trim();
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    if (value.startsWith('/')) {
      final base = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      return '$base$value';
    }
    return null;
  }

  /// 서버가 저장 때 막지만 **앱도 한 번 더 거른다** (N12).
  /// `intent://`·`javascript:` 가 새어 들어오면 누르는 순간 다른 앱이 열린다.
  static NoticeButton? _readButton(Object? raw) {
    if (raw is! Map) return null;
    final label = raw['label'];
    final url = raw['url'];
    if (label is! String || label.trim().isEmpty || url is! String) {
      return null;
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return NoticeButton(label: label.trim(), url: uri);
  }
}

const _marker = '**';

String _visible(String title) => title.replaceAll(_marker, '');

/// 제목의 한 조각. 강조면 브랜드 색으로 그린다.
@immutable
class NoticeTitlePart {
  const NoticeTitlePart(this.text, {required this.emphasized});

  final String text;
  final bool emphasized;

  @override
  bool operator ==(Object other) =>
      other is NoticeTitlePart &&
      other.text == text &&
      other.emphasized == emphasized;

  @override
  int get hashCode => Object.hash(text, emphasized);

  @override
  String toString() => emphasized ? '**$text**' : text;
}

/// 제목을 강조 조각으로 나눈다 (N25).
///
/// 규칙은 서버 `NoticeEmphasis` 와 **같아야 한다** — `**` 로 나눈 조각 중 홀수 번째가
/// 강조다. 어긋나면 관리자 미리보기와 앱에서 강조되는 곳이 달라진다.
///
/// 짝이 안 맞으면 서버가 저장을 막지만, 그래도 오면 **강조 없이 표기만 지운다.**
/// 어느 쪽을 강조하려던 것인지 알 수 없으니 추측해서 칠하지 않는다.
List<NoticeTitlePart> parseNoticeTitle(String title) {
  final pieces = title.split(_marker);
  // 표기가 짝수 번이면 조각은 홀수 개다
  if (pieces.length.isEven) {
    return [NoticeTitlePart(_visible(title), emphasized: false)];
  }
  return [
    for (final (i, piece) in pieces.indexed)
      if (piece.isNotEmpty) NoticeTitlePart(piece, emphasized: i.isOdd),
  ];
}

/// `보지 않기` 문구. 일수는 관리자 설정 하나(`NOTICE_HIDE_DAYS`)라 모든 공지가 같다.
String noticeHideLabel(int days) =>
    days == NoticeFeed.defaultHideDays ? '일주일간 보지 않기' : '$days일간 보지 않기';

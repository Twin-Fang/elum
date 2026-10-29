/// 이야기 글 공유 링크: 웹 링크·앱 주소 해석, 보낼 링크 만들기
///
/// | 종류 | 모양 | 쓰임 |
/// | --- | --- | --- |
/// | 웹 링크 | `{API 주소}/s/{글id}` | 공유 시트로 보냄. 서버가 미리보기 페이지를 그림 |
/// | 앱 주소 | `elum://talk?post={글id}` | 웹 페이지의 `이룸 앱에서 보기` (서버 TalkSharePageController 와 같은 모양) |
///
/// 웹 링크 호스트는 [webHosts] 로 정확히 맞는 것만 받는다 — `…chuseok22.com.evil.com` 같은 주소를 거른다.
class TalkPostLink {
  const TalkPostLink({required this.postId});

  /// UUID 모양까지 확인한 글 id
  final String postId;

  static const _appScheme = 'elum';
  static const _appHost = 'talk';
  static const _postQueryName = 'post';

  /// 웹 링크 경로 첫 조각: `/s/{글id}`
  static const _webPathSegment = 's';

  // 서버 글 id 모양 (UUID)
  static final _postIdShape = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// [raw](문자열 또는 [Uri]) > 이야기 글 링크. 아니거나 id 모양이 틀리면 null. 어떤 입력에도 던지지 않는다
  ///
  /// [webHosts] 는 받을 웹 링크 호스트 (보통 API 주소 호스트 하나)
  static TalkPostLink? parse(Object? raw, {required Set<String> webHosts}) {
    final uri = _toUri(raw);
    if (uri == null) return null;
    final postId = switch (uri.scheme.toLowerCase()) {
      _appScheme when uri.host.toLowerCase() == _appHost => _queryPostId(uri),
      'https' when webHosts.contains(uri.host.toLowerCase()) => _webPostId(uri),
      // 플랫폼이 호스트를 떼고 경로만 넘기는 경우 (안드로이드 초기 라우트 등)
      '' when uri.host.isEmpty => _webPostId(uri),
      _ => null,
    };
    if (postId == null || !_postIdShape.hasMatch(postId)) return null;
    return TalkPostLink(postId: postId.toLowerCase());
  }

  /// 공유 시트로 보낼 웹 링크: `{baseUrl}/s/{글id}`
  static String shareUrl(String baseUrl, String postId) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base/$_webPathSegment/${Uri.encodeComponent(postId)}';
  }

  /// API 주소 > 받을 웹 링크 호스트 (주소가 깨졌으면 빈 집합)
  static Set<String> webHostsOf(String baseUrl) {
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
    return host.isEmpty ? const {} : {host};
  }

  // `/s/{글id}` 만 (썸네일 `/s/{글id}/thumbnail` 등은 글 링크가 아님)
  static String? _webPostId(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 2 || segments.first != _webPathSegment) return null;
    return segments[1];
  }

  // 깨진 퍼센트 인코딩이면 queryParameters 가 던짐 > null
  static String? _queryPostId(Uri uri) {
    try {
      return uri.queryParameters[_postQueryName];
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static Uri? _toUri(Object? raw) {
    if (raw is Uri) return raw;
    if (raw is! String) return null;
    try {
      return Uri.parse(raw.trim());
    } on FormatException {
      return null;
    }
  }
}

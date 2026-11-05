/// 고쳐서 다시 그리기 칩 4개 — 서버 `ImageRedrawHint` (영어 지시문은 서버가 붙임)
enum ImageRedrawHint {
  simpler('SIMPLER'),
  noBackground('NO_BACKGROUND'),
  noPeople('NO_PEOPLE'),
  brighter('BRIGHTER');

  const ImageRedrawHint(this.apiValue);

  final String apiValue;

  /// 요청 글 최대 길이 (서버 `GuardianImageRequest.MAX_REQUEST_TEXT_LENGTH`)
  static const maxRequestTextLength = 60;
}

/// 보호자가 고른 요청: 고치고 싶은 점(짧은 글) + 칩. 둘 다 비면 같은 조건으로 다시 그림
typedef CardRedrawRequest = ({String requestText, Set<ImageRedrawHint> hints});

/// 이야기 글자 수 상한 (서버 TalkTextRules 와 같은 값, 넘기면 400)
class TalkTextLimits {
  const TalkTextLimits._();

  /// 한마디 최대 글자 수
  static const maxNoteLength = 300;

  /// 댓글 최대 글자 수
  static const maxCommentLength = 300;
}

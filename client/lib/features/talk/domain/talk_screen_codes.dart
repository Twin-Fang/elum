/// 이야기 화면별 추적 코드: 서버 코드가 없는 실패에 붙는다 (E-TALK-nnn)
/// 피드 001, 상세 002, 올리기 010, 가져오기 020, 댓글 030, 신고 040, 숨기기 050, 글 고치기·내리기 060, 링크 공유 070
class TalkScreenCodes {
  const TalkScreenCodes._();

  static const feed = 'E-TALK-001';
  static const detail = 'E-TALK-002';
  static const share = 'E-TALK-010';
  static const importToLibrary = 'E-TALK-020';
  static const comment = 'E-TALK-030';
  static const report = 'E-TALK-040';
  static const block = 'E-TALK-050';
  static const managePost = 'E-TALK-060';
  static const shareLink = 'E-TALK-070';
  static const myPosts = 'E-TALK-080';
}

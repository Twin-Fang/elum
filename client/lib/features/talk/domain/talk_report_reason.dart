/// 신고 사유 4개 (서버 TalkReportReason 과 같은 이름)
enum TalkReportReason {
  personalInfo('PERSONAL_INFO'),
  offensive('OFFENSIVE'),
  advertising('ADVERTISING'),
  other('OTHER');

  const TalkReportReason(this.serverValue);

  final String serverValue;
}

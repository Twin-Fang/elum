/// 홈 안내 카드 기록에 쓰는 날짜 표지: 기기 시각 > `yyyy-MM-dd`
String homeNoticeDayKeyOf(DateTime now) {
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

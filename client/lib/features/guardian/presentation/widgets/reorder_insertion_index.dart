/// 끌던 카드가 들어갈 자리 — 손가락이 가리키는 **사이**를 센다.
///
/// [contentX] 는 스크롤 내용 안의 가로 좌표(줌아웃 전 크기 기준)다. 끌고 있는 카드를 뺀
/// 나머지 [count]장이 [leading] 에서 시작해 [extent] 간격으로 서 있고, 지금 [gap] 번째
/// 앞에 카드 한 장 폭의 틈이 벌어져 있다고 본다. 중심이 [contentX] 보다 왼쪽에 있는
/// 카드 수가 곧 들어갈 자리(0~count)다.
///
/// **눈에 보이는 배치(벌어진 틈 포함)로 잰다.** 그래야 손가락이 틈 안에 있는 동안은 자리가
/// 바뀌지 않는다 — 이웃의 중심을 지나야 틈이 옮겨 가므로 깜빡이지 않는다.
int reorderInsertionIndex({
  required double contentX,
  required int count,
  required double leading,
  required double extent,
  required int gap,
}) {
  var k = 0;
  for (var j = 0; j < count; j++) {
    final center = leading + j * extent + (j >= gap ? extent : 0) + extent / 2;
    if (center < contentX) k = j + 1;
  }
  return k;
}

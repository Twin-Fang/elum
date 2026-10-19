/// 화면이 태블릿에서 자기 자리를 잡는 방식 (라우트에서 한 번 선언)
///
/// 선언이 없으면 [phoneColumn]. 새 화면도 별도 작업 없이 태블릿에서 깨지지 않는다.
enum ScreenLayoutKind {
  /// 폰 비율(393x852 x 배율) 열을 가운데 두고 양옆은 배경색. 절대 좌표 뼈대 화면의 기본값
  phoneColumn,

  /// 폼·설정·약관: 폭 상한까지 늘린 가운데 열
  contentColumn,

  /// 화면이 등급(compact/medium/expanded)별 구성을 직접 가진다. 프레임은 손대지 않는다
  adaptive,
}
